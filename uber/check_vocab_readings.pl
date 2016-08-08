#!/usr/bin/perl                       --  -*- Perl -*-

# Take a kanji and use JA_Script to count up occurrences of each
# reading of vocab stored in database.

use strict;
use warnings;
use utf8;

use DBI;

# Script-related utils
use Util::JA_Script qw(hira_to_kata has_hira has_kata has_kanji);

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# apparently ARGV doesn't automatically have UTF8 flag...
use Encode qw(decode_utf8);
@ARGV = map { decode_utf8($_, 1) } @ARGV;

use Data::Dump qw(dump dumpf);
sub filter_dumped {
    my ($ctx, $object_ref) = @_;
    if ($ctx->reftype eq "SCALAR") {
        return { dump => "'" . $$object_ref . "'" }; # needs $$!
    } elsif($ctx->is_hash) {
        return { hide_keys => ['xml:lang'] };
    } else {
        return undef;
    }
    return undef;
}

# Look for external modules in program directory
#BEGIN {
#    local($_) = $0;
#    s|^(.*)/.*$|$1|;
#    push @INC, $_;
#}


my $ja = Util::JA_Script->new;
$ja->load_db;

die "Please supply a kanji arg to test\n" unless (@ARGV);

my $kanji = shift @ARGV;

die "Arg $kanji doesn't have kanji!\n" unless has_kanji($kanji);

# Database
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=web_data.sqlite", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );

my $sth = $dbh->prepare(
    "select ja_regular, ja_kana, jlpt_level 
     from vocab_by_jlpt_grade 
     where ja_regular like ?");
die unless defined $sth;

# Since I have two databases with vocabulary, it makes sense to search
# both of them. I'll slurp both into a common structure.
my %vocab_dict = ();
sub new_dict {
    {
	vocab => shift,
	grade => shift,
	readings => [],
	stoplist => {},		# prevent adding duplicate readings
    }
}
my ($vocab, $kana, $grade, $reading);
my $rc = $sth->execute("\%$kanji\%") or die;

sub update_dict {		# wrap up to reuse for both queries
    my $sth = shift;
    while (($vocab, $kana, $grade) = $sth->fetchrow_array) {
	next unless has_kanji($vocab);
	# Found some odd entries with kana [kanji]. They cause an
	# infinite loop somewhere: skip them
	next if $vocab =~ tr|[]|[]|;
	$vocab =~ s/(.)々/$1$1/;
	$vocab_dict{$vocab} = new_dict($vocab,$grade)
	    unless exists $vocab_dict{$vocab};
	foreach $reading (split /\s*[,\/]\s*/, $kana) {
	    next if exists $vocab_dict{$vocab}->{stoplist}->{$reading};
	    $vocab_dict{$vocab}->{stoplist}->{$reading} = undef;
	    push @{$vocab_dict{$vocab}->{readings}}, $reading;
	}
    }
}

update_dict($sth);

warn "Read in tanos/jlptstudy/tagaini data\n";

# Core 2k/6k dictionary
my $dbh2 = DBI->connect(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/core_6000/core_2k_6k.sqlite", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );
die unless defined $dbh2;

$sth = $dbh2->prepare(
    "select ja_vocab, ja_vocab_kana, 0
     from core_6k 
     where ja_vocab like ?");
die unless defined $sth;
$rc = $sth->execute("\%$kanji\%") or die;
update_dict($sth);
warn "Read in Core data\n";

# Structures for doing summary analysis of reading frequency and
# failed parses
my @failed = ();
my %reading_counts = ();
my $matched_count = 0;

my $unstripped = $kanji;
$kanji = $ja->strip_non_kanji($kanji);

foreach my $vocab (sort {$a cmp $b} keys %vocab_dict) {

    $grade = $vocab_dict{$vocab}->{grade};
    my $readlist = $vocab_dict{$vocab}->{readings};

    foreach $reading (@$readlist) {
	#warn "Reading: $reading\n";

	# check vocab reading
	my $listref = $ja->kanji_reading($vocab,$reading);
	unless(defined $listref) {
	    #warn "No match for $vocab => $reading\n";
	    push @failed, "N$grade $vocab => $reading";
	    
	} else {
	    print "Matched N$grade $vocab => $reading\n";
	    #dumpf($listref, \&filter_dumped);

	    ++$matched_count;

	    # Scan through the list to find just the kanji we're
	    # interested in.
	    my $pos = 0;
	    while ($pos < @$listref) {
		next unless $listref->[$pos] eq $kanji;
		my $hira  = $listref->[$pos+1];
		my $dlist = $listref->[$pos+2];
		# Just take the first matching reading? Scan them all
		my $rtype = undef;
		foreach (@$dlist) {
		    die unless /^(.*):(.*):(.*)$/;
		    # apparently we can have kanji like 訓 that has
		    # both on-yomi and kun-yomi that map to the same
		    # sound... I had a die in here but I'll just
		    # change it to just pick the first match.
		    $rtype = "$1:$2";
		    last;
		    # don't die below
		    die "$rtype ne $1:$2" if defined($rtype) and $rtype ne "$1:$2";
		    $rtype = "$1:$2";
		}

		$reading_counts{$rtype} = 0 unless defined $reading_counts{$rtype};
		$reading_counts{$rtype}++;
		last;
	    } continue {
		$pos += 3;
	    }
	    
	}
	
    }
}

# Summarise readings
print "Summary of readings for kanji $kanji:\n";
print "Total vocab readings: " . ($matched_count + @failed) . ", of which " .
    (0 + @failed) . " had no match\n";
print "Summary of readings:\n";
for (sort {$a cmp $b} keys %reading_counts) { 
    printf("  %02d time(s)  %-16s \n", $reading_counts{$_}, $_)  
};
print "Non-matching:\n  " . (join "\n  ", @failed) . "\n";


$dbh->disconnect;
$dbh2->disconnect;
