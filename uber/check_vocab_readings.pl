#!/usr/bin/perl                       --  -*- Perl -*-

# Take a kanji and use JA_Script to count up occurrences of each
# reading of vocab stored in database.

use strict;
use warnings;
use utf8;

use DBI;

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
BEGIN {
    local($_) = $0;
    s|^(.*)/.*$|$1|;
    push @INC, $_;
}

# Script-related utils
use JA_Script qw(hira_to_kata has_hira has_kata has_kanji);

my $ja = JA_Script->new;
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

# Structures for doing summary analysis of reading frequency and
# failed parses
my @failed = ();
my %reading_counts = ();
my $matched_count = 0;

my $unstripped = $kanji;
$kanji = $ja->strip_non_kanji($kanji);

my $rc = $sth->execute("\%$kanji\%") or die;
my ($vocab, $kana, $grade, $reading);
while (($vocab, $kana, $grade) = $sth->fetchrow_array) {

    #warn "N$grade $vocab => $kana\n";

    # Readings field can include multiple options
    foreach $reading (split /\s*[,\/]\s*/, $kana) {
	#warn "  $reading\n";

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
		    die if defined($rtype) and $rtype ne "$1:$2";
		    $rtype = "$1:$2";
		}
		# OK, scan didn't die, so returned readings only differ in dict form
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
