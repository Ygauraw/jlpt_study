#!/usr/bin/perl

# Based on similar code for JMdict XML/YAML file

use strict;
use warnings;

use utf8;
use YAML::XS qw(Load DumpFile LoadFile);

use Encode;			# for setting UTF-8 flag

use DBI;
#use DBD::SQLite;

my $do_dump = 0;

use Data::Dump qw(dump dumpf);

# Data::Dump is great, but it converts strings to Unicode escapes and
# is overly-verbose.
sub filter_dumped {
    my ($ctx, $object_ref) = @_;
    if ($ctx->is_scalar) {
	return { dump => "'" . $$object_ref . "'" }; # needs $$!
    } elsif($ctx->is_hash) {
	return { hide_keys => ['xml:lang'] };
    } else {
	return undef;
    }
    return undef;
}

sub has_hiragana {
    local ($_) = shift;
    /[\x{3041}-\x{3095}]/;
}

sub has_katakana {
    local ($_) = shift;
    /[\x{30a1}-\x{30f9}]/;
}

sub has_kanji {
    local ($_) = shift;
    /[\x{4e00}-\x{9faf}]/;
}

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=kanjidic2.sqlite", "", "",
    {
	RaiseError     => 1,
	sqlite_unicode => 1,
	AutoCommit     => 0,
    }
    );

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if (1) {
    print "WARNING: THIS WILL NUKE THE DATABASE\n";
    print "Hit enter to continue or ^c to exit\n";
    my $line = <STDIN>;
    print "Continuing ...\n";
}

# Make good on that promise ...
my ($sth, $rc);
# I have RaiseError set by default, but I want these to be non-fatal
print "Ignore any \"no such table\" errors below\n";
# do these drop dependent indices, too?
eval { $dbh->do("drop table entries_by_literal") };
eval { $dbh->do("drop table english_meanings") };
eval { $dbh->do("drop table on_kun_readings") };
$dbh->commit;
print "(end of ignorable errors)\n\n";

# Include basic info in the main table
$dbh->do(<<"_END");
create table entries_by_literal (
    literal             text    PRIMARY KEY,
    heisig6             integer NOT NULL,
    frequency           integer NOT NULL,
    jlpt                integer NOT NULL,
    jouyou              integer NOT NULL,
    yaml_entry		text    NOT NULL
)
_END
$dbh->commit;

$dbh->do(<<"_END");
create table english_meanings (
    literal             text NOT NULL,
    english             text NOT NULL
)
_END
$dbh->do("create index eng_mean_literal on english_meanings(literal)");
$dbh->do("create index eng_mean_english on english_meanings(english)");
$dbh->commit;

$dbh->do(<<"_END");
create table on_kun_readings (
    literal             text NOT_NULL,
    type                text NOT NULL,
    text                text NOT NULL,
    kun_dict_form       text
)
_END
$dbh->do("create index on_kun_literal on on_kun_readings(literal)");
$dbh->commit;

# Read in RTK YAML file
my $rtk_dict = LoadFile("../../koohii/rtk_dict.yaml") or die;
my $max_rtk_frame = $rtk_dict->{meta}->{entries} or die;

# print $rtk_dict->{frame_index}->[1950]->{kanji} ."\n";

# Read in kanjidic2 YAML file and skip prologue
open YAMLDICT, "<:encoding(UTF-8)", "kanjidic2.yaml"
    or die "Failed to open kanjidic2.yaml for reading in UTF8 mode: $!";

<YAMLDICT>, <YAMLDICT>;

my $ent = undef;		# store complete entry
my $ent_string = "";		# accumulate lines

# A few variables for testing and controlling how often we commit on
# the database.
my $max_ents = 6e7;
my $count_ents = 0;
my $commit_every = 5000;
my $commit_count = 0;

sub process_entity_string {
    my $str = "---\n" . shift;
    my $literal; 		# retrieved from $ent later

    # Apparently, we need the utf8 flag off (even though Load expects
    # utf8-encoded data); It's turned on again later since I think the
    # database needs/expects it.
    Encode::_utf8_off($str);
    $ent = Load($str) or die;
    Encode::_utf8_on($str);

    # Now we can use $ent to look up the contents of the entity (for
    # creating index tables) and $str to put into the main database.
    $literal = $ent->{literal} or die;
    
    # check frame numbers against RTK file
    my $heisig6 = 0;
    if (exists($ent->{dic_number}->{dic_ref})) {
	my $dic_ref_list = $ent->{dic_number}->{dic_ref};
	$dic_ref_list = [ $dic_ref_list ] unless ref($dic_ref_list) eq "ARRAY";
	foreach my $dic_ref (@$dic_ref_list) {
	    die unless exists $dic_ref->{dr_type};
	    next unless $dic_ref->{dr_type} eq "heisig6";
	    die unless exists $dic_ref->{content};
	    $heisig6 = $dic_ref->{content};
	    next if $heisig6 > $max_rtk_frame;
	    unless ($heisig6 == $rtk_dict->{frame_index}->[$heisig6]->{frame_num}) {
		die "!$heisig6, $literal" . $rtk_dict->{frame_index}->[$heisig6]->{frame_num} ;
	    }
	    die "$heisig6, !$literal" unless $literal eq
		$rtk_dict->{frame_index}->[$heisig6]->{kanji};
	}
    }

    # pull out other basic info from {misc}
    die unless exists $ent->{misc};
    my $misc = $ent->{misc};
    my $freq = 0;
    $freq = $misc->{freq} if exists $misc->{freq};
    my $jlpt = 0;
    $jlpt = $misc->{jlpt} if exists $misc->{jlpt};
    my $jouyou = 0;
    $jouyou = $misc->{grade} if exists $misc->{grade};

    # My copy of the dictionary has out-of-date JLPT info
    $jlpt++ if $jlpt >2;

    # populate basic info table
    $dbh->do("insert into entries_by_literal ". 
	     "(literal,heisig6,frequency,jlpt,jouyou,yaml_entry) values ( " .
	     $dbh->quote($literal) . " , " .
	     "$heisig6, $freq, $jlpt, $jouyou, " .
	     $dbh->quote($str) . ")" );

    # I count more than 2,200 kanji that have a Jouyou "grade" field...

    # English meanings is easy enough.
    if (exists ($ent->{reading_meaning}->{rmgroup}->{meaning})) {
	my $meanings = $ent->{reading_meaning}->{rmgroup}->{meaning} or die $literal;
	$meanings = [ $meanings ] if ref($meanings) ne "ARRAY";
	foreach my $meaning (@$meanings) {
	    my $eng = "";
	    if (ref($meaning) eq "HASH") {
		die unless exists $meaning->{"m_lang"};
		next unless ($eng = $meaning->{"m_lang"}) eq "en";
	    } else {
		$eng = $meaning;
	    }
	    #warn "Adding literal $literal -> $eng\n";
	    $dbh->do("insert into english_meanings (literal,english) values (" .
		     $dbh->quote($literal) . "," . $dbh->quote($eng) . ")");
	}
    }
    
    # Readings are complicated by kun-yomi sometimes having a suffix,
    # for example つ.ぐ
    #
    # I'd like to be able to search on つ.ぐ, つぐ and just つ. I
    # suppose that I can add an extra field.
    if (exists $ent->{reading_meaning}->{rmgroup}->{reading}) {
	my $readings = $ent->{reading_meaning}->{rmgroup}->{reading};
	$readings = [ $readings ] if ref($readings) ne "ARRAY";
	foreach my $reading (@$readings) {
	    my $content = $reading->{content} or die;
	    my $r_type  = $reading->{"r_type"} or die;
	    if ($r_type eq "ja_kun") {
		my $kun_dict_form = $content;
		if ($content =~ /^(.*)\.(.*)$/) {
		    my ($pre, $suf) = ($1,$2);
		    $dbh->do("insert into on_kun_readings (literal,type,text,kun_dict_form) " .
			     "values (" . $dbh->quote($literal) . ", 'kun', " .
			     $dbh->quote("$pre") .
			     "," . $dbh->quote($kun_dict_form) . ")");
		    $dbh->do("insert into on_kun_readings (literal,type,text,kun_dict_form) " .
			     "values (" . $dbh->quote($literal) . ", 'kun', " .
			     $dbh->quote("$pre$suf") .
			     "," . $dbh->quote($kun_dict_form) . ")");
		}
		$dbh->do("insert into on_kun_readings (literal,type,text,kun_dict_form) " .
			 "values (" . $dbh->quote($literal) . ", 'kun', " .
			 $dbh->quote("$content") .
			 "," . $dbh->quote($kun_dict_form) . ")");
	    } elsif ($r_type eq "ja_on") {
		$dbh->do("insert into on_kun_readings (literal,type,text,kun_dict_form) " .
			 "values (" . $dbh->quote($literal) . ", 'on', " .
			 $dbh->quote("$content") .
			 ",NULL)");
	    }
	}
    }

    
    if (++$commit_count > $commit_every) {
	print "$commit_every\n";
	$dbh->commit;
	$commit_count = 0;
    }
    
    if ($do_dump) {
	print dumpf($ent, \&filter_dumped) . "\n";
    }

    # Add code to add stuff to database
}

while ($_ = <YAMLDICT>) {
    s/^..//;			# outer container is gone
    if (/^codepoint:$/) {
	if ($ent_string ne "") {
	    process_entity_string($ent_string);
	    $ent_string = "";
	    ++$count_ents;
	    last if $count_ents >= $max_ents;
	}
	$ent_string = $_;
    } else {
	# do any other line processing here
	$ent_string .= $_;
    }
}
process_entity_string($ent_string) if ($count_ents < $max_ents);

$dbh->commit;



$dbh->disconnect;
