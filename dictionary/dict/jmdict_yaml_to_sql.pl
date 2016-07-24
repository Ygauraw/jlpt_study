#!/usr/bin/perl

# Taking a slightly different approach to that used in schema.pl.
# Instead of reading the YAML file into a large internal Perl
# structure, I'll scan it as a text file instead. That way I'll be
# able to build up individual entries as pure text and avoid needing
# to call YAML twice (once to load the structure, once to dump each
# entry). It should also make it easier to handle any UTF-8 issues.
#

use strict;
use warnings;

use utf8;
use YAML::XS qw(Load DumpFile LoadFile);

use Encode;			# for setting UTF-8 flag

use DBI;
#use DBD::SQLite;

use Data::Dump qw(dump dumpf);



# Data::Dump is great, but it converts strings to Unicode escapes and
# is overly-verbose. This version of the filter hides xml:lang entries
# and any non-English glosses.

my $do_dump = 0;

sub filter_dumped {
    my ($ctx, $object_ref) = @_;
    if ($ctx->is_scalar) {
	return { dump => "'" . $$object_ref . "'" }; # needs $$!
    } elsif($ctx->is_hash) {
	if (exists ($object_ref->{"xml:lang"}) 
	    and    $object_ref->{"xml:lang"} ne "eng") {
	    #die "got here";
	    return { dump => "" };
	} else {
	    return { hide_keys => ['xml:lang' ] };
	}
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
    "dbi:SQLite:dbname=jmdict.sqlite", "", "",
    {
	RaiseError     => 1,
	sqlite_unicode => 1,
	AutoCommit     => 0,
    }
    );

# First, read in entity definitions from XML file
open XMLDICT, "<:encoding(UTF-8)", "JMdict.xml"
    or die "Failed to open JMdict for reading in UTF8 mode: $!";

my (%abbr_to_full, %full_to_abbr, @abbr_full);
my $n_abbr = 0;
while ($_=<XMLDICT>) { last if m|^<!ENTITY | }
while (m|^<!ENTITY (\S+)\s\"(.*)\">|) {
    my ($short, $long) = ($1, $2);

    die "Duplicate abbreviated entity $short\n" if exists $abbr_to_full{$short};
    die "Duplicate expanded entity $long\n"     if exists $full_to_abbr{$long};
    $abbr_to_full{$short} = $long;
    $full_to_abbr{$long}  = $short;
    push @abbr_full, [$short, $long]; # useful when populating db table
    ++$n_abbr;
    
    $_=<XMLDICT>;
}

print "Read in $n_abbr abbreviation entity definitions\n";
for (0, $n_abbr - 1) {
    print "$_: $abbr_full[$_]->[0] -> $abbr_full[$_]->[1]\n";
}

close XMLDICT;

# I want to undo the entity expansion, so I think I'll do it by
# modifying the source file. OK. Now that's done. I changed it to:
# abbr:<abbrev> <expansion>
#
# Hopefully that should be unique. Now to rebuild the file... done

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
eval { $dbh->do("drop table entries_by_sequence") };
eval { $dbh->do("drop table eng_search") };
eval { $dbh->do("drop table jpn_search") };
$dbh->commit;
print "(end of ignorable errors)\n\n";

$dbh->do(<<"_END");
create table entries_by_sequence (
    ent_seq		integer PRIMARY KEY,
    yaml_entry		text    NOT NULL
)
_END
$dbh->commit;

$dbh->do(<<"_END");
create table eng_search (
    english             text    NOT NULL,
    ent_seq             integer NOT NULL,
    sense_num           integer NOT NULL, -- start counting from 1
    sense_cnt           integer NOT NULL
)
_END
$dbh->commit;
$dbh->do("create index english on eng_search(english)");
$dbh->commit;

$dbh->do(<<"_END");
create table jpn_search (
    japanese            text    NOT NULL,
    ent_seq             integer NOT NULL,
    rebkeb              text    NOT NULL, -- 'reb' or 'keb'
    rebkeb_num          integer NOT NULL, -- which reb/keb this is in sequence
    rebkeb_cnt          integer NOT NULL
)
_END
$dbh->commit;
$dbh->do("create index japanese on jpn_search(japanese)");
$dbh->commit;

# Read in YAML file and skip prologue
open YAMLDICT, "<:encoding(UTF-8)", "JMdict.yaml"
    or die "Failed to open JMdict.yaml for reading in UTF8 mode: $!";

<YAMLDICT>, <YAMLDICT>;

my $ent = undef;		# store complete entry
my $ent_string = "";		# accumulate lines

# A few variables for testing and controlling how often we commit on
# the database.
my $max_ents = 6e6;
my $count_ents = 0;
my $commit_every = 5000;
my $commit_count = 0;

sub process_entity_string {
    my $str = "---\n" . shift;
    my $seq_id; 		# retrieved from $ent later

    # 
    # print "YAML::Load ... $str\n";

    # Apparently, we need the utf8 flag off (even though Load expects
    # utf8-encoded data); It's turned on again later since I think the
    # database needs/expects it.
    Encode::_utf8_off($str);
    $ent = Load($str) or die;
    Encode::_utf8_on($str);

    # Now we can use $ent to look up the contents of the entity (for
    # creating index tables) and $str to put into the main database.
    $seq_id = $ent->{ent_seq} or die;
    
    $dbh->do("insert into entries_by_sequence values ($seq_id," .
	     $dbh->quote($str) . ")" );

    # Extract information for English senses/glosses
    my ($sense_cnt, $sense_num) = (0,1);
    die unless exists($ent->{sense});
    my $sense_list = $ent->{sense};
    $sense_list = [ $sense_list ] if ref($sense_list) eq "HASH";
    $sense_cnt = scalar(@$sense_list);
    foreach my $sense (@$sense_list) {
	die unless exists($sense->{gloss});
	my $gloss_list = $sense->{gloss};
	$gloss_list = [ $gloss_list ] if ref($gloss_list) eq "HASH";
	foreach my $gloss (@$gloss_list) {
	    next if exists($gloss->{"xml:lang"}) and $gloss->{"xml:lang"} ne "eng";
	    my $content = $gloss->{"content"} or die;

	    # We have enough to create a new eng_search record now
	    $dbh->do("insert into eng_search values (" . $dbh->quote($content) .
		     ", $seq_id, $sense_num, $sense_cnt)");
	}
	++$sense_num;
    }
    
    # Do something similar for JPN entries
    my %container = ( reb => "r_ele", keb => "k_ele" );
    my %counts    = ( reb => 0, keb => 0 );
    for my $which (qw(reb keb)) {
	my $rebkeb_num  = 1;
	#warn "$which => $container{$which}\n";
	my $rebkeb_list;
	next unless exists $ent->{$container{$which}};
	$rebkeb_list = $ent->{$container{$which}};
	$rebkeb_list = [ $rebkeb_list ] if ref($rebkeb_list) eq "HASH";
	my $rebkeb_cnt = scalar (@$rebkeb_list);
	foreach my $rebkeb (@$rebkeb_list) {
	    my $content = $rebkeb->{$which} or die;
	    $dbh->do("insert into jpn_search values (" . $dbh->quote($content) .
		     ", $seq_id, " . $dbh->quote($which) . 
		     ", $rebkeb_num, $rebkeb_cnt)");
	    ++$rebkeb_num;
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
    if (/^ent_seq: '\d+'/) {
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



 
