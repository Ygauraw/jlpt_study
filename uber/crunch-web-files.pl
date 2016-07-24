#!/usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(LoadFile DumpFile);

use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

## Utility functions from parse_jlpt_web_data.pl
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

my $rtk_index;
$rtk_index = LoadFile("rtk_kanji.yaml") or die "failed to load RTK";

print "Loaded RTK. Last kanji is " . $rtk_index->{by_frame}->[2200]->{kanji} . "\n";

## Create a jouyou kanji table from RTK data
my $rtk_by_kanji = $rtk_index->{by_kanji};
my %jouyou = map { $_ => undef } keys %$rtk_by_kanji;
print "RTK->Jouyou index has " . (0 + (keys %jouyou)) . " entries\n";
for my $c ('私', '一', '巳') {
    print "Checking $c: " . (exists $jouyou{$c} ? "ok" : "not ok") . "\n";
}

## Read in other kanji files

# use two-level indexes to get at sources
my @sources = qw(tanos jlpt tagaini);
my %distinct_jlpt_by_level    = map { $_ => { map { $_ => undef } @sources }} (1..5);
my %distinct_jlpt_by_source   = map { $_ => { map { $_ => undef } (1..5) }} @sources;
my %cumulative_jlpt_by_level  = map { $_ => { map { $_ => undef } @sources }} (1..5);
my %cumulative_jlpt_by_source = map { $_ => { map { $_ => undef } (1..5) }} @sources;
my $non_joyou = 0;

my %jouyou_levels = map 
{ $_ => 
  {
      notional_level => 0,	# 0 means non-JLPT
      found_in => {
	  tanos   => [],	# list of levels it was found at
	  jlpt    => [],
	  tagaini => [],
	  jmdict  => [],
      }
  }
} keys %jouyou;

sub register_level {
    my ($kanji, $source, $level) = @_;
    return unless exists $jouyou{$kanji}; # only store info for Jouyou kanji
    #    warn "[$kanji,$source,$level]\n";

    push @{$jouyou_levels{$kanji}->{found_in}->{$source}}, $level;
    # The following stores the easiest level that the kanji was found
    # at among all lists
    if ($level > $jouyou_levels{$kanji}->{notional_level}) {
	#warn "got here new level $level\n";
	$jouyou_levels{$kanji}->{notional_level} = $level;
    }

}

for my $level (1..5) {	# I get 204 non-Jouyou kanji if I include N1
    for my $src (@sources) {
	my $file = "${src}_n${level}_kanji.yaml";
	next unless -f $file;
	my $data = LoadFile($file);
	die "Problem loading '$file': $!\n" unless defined($data);

	# Validate data. I use the same record format for all kanji sources
	die "Wrong level info in restored data" unless $data->{level} eq $level;
	die "No kanji key in restored data" unless exists $data->{kanji};

	# Can discard the outermost hash (only contains level info)
	my $int_level = $data->{level} or die;
	die if $level != $int_level;
	$data = $data->{kanji};

	# validate keys (ie, kanji chars)
	for my $testkey (keys %$data) {
	    register_level($testkey, $src, $level);
	    next if exists $jouyou{$testkey};
	    warn "[$src,$level]: Found non-Joyou kanji '$testkey' (suppressing further notices)\n" 
		unless $non_joyou++;
	}
	
	# Index the data
	$distinct_jlpt_by_source{$src}->{$level} =
	    $distinct_jlpt_by_level{$level}->{$src} = $data;

	
	print "[$src,$level]: " . (0 + keys %$data) . " distinct entries\n";
	
    }
}

print "Found $non_joyou non-Jouyou kanji in tested levels\n";

# Based on above output, tagaini seems to use the same list as on the jlpt site
print "Conjecture: tagaini and jlpt kanji lists for N5, N4 and N2 are the same\n";

for my $level (5, 4, 2) {

    my $tagai = join "", sort { $a cmp $b } (
	keys %{$distinct_jlpt_by_level{$level}->{tagaini}});
    my $jlpt = join "", sort { $a cmp $b } (
	keys %{$distinct_jlpt_by_level{$level}->{jlpt}});

    die if $distinct_jlpt_by_level{$level}->{jlpt} == $distinct_jlpt_by_level{$level}->{tagaini};
    
    #print "$tagai\n$jlpt\n";   # just checking they're not null!
    print "Testing N$level: " . ($tagai eq $jlpt ? "same list\n" : "different list\n");
}
    
## OK, conjecture proven. How about trying to merge the data from each source?
## Too tricky to do quickly...

# I also notice that jlpt's N2 data could be a cumulative list
# (including N3 kanji). Testing this...

if (1) {
    my $jlpt_n5 = $distinct_jlpt_by_level{5}->{jlpt};
    my $jlpt_n4 = $distinct_jlpt_by_level{4}->{jlpt};
    my $jlpt_n3 = $distinct_jlpt_by_level{3}->{jlpt};
    my $jlpt_n2 = $distinct_jlpt_by_level{2}->{jlpt};

    print "Conjecture: JLPT N2 list is a cumulative list (includes all N3 kanji)\n";
    my $jlpt_n3_kanji = 0 + keys %$jlpt_n3;
    my $jlpt_n2_kanji = 0 + keys %$jlpt_n2;

    my $exception = 0;
    foreach (keys  %$jlpt_n3) {
	unless (exists  $jlpt_n2->{$_}) {
	    print "Exception found: '$_' is in JLPT N3, but not in N2\n" unless $exception;
	    ++$exception;
	    if (exists  $jlpt_n4->{$_} or exists  $jlpt_n5->{$_}) {
		print "An exception ('$_') actually exists in N4/N5 JLPT lists!\n";
	    }
	}
    }
    print "Found $exception exceptions to the conjecture\n";
}

print "Notional levels based on all sources:\n\n";
print 0 + (keys %jouyou_levels) . "\n";

my @n5 = grep { $jouyou_levels{$_}->{notional_level} == 5 } keys %jouyou_levels;
my @n4 = grep { $jouyou_levels{$_}->{notional_level} == 4 } keys %jouyou_levels;
my @n3 = grep { $jouyou_levels{$_}->{notional_level} == 3 } keys %jouyou_levels;
my @n2 = grep { $jouyou_levels{$_}->{notional_level} == 2 } keys %jouyou_levels;
my @n1 = grep { $jouyou_levels{$_}->{notional_level} == 1 } keys %jouyou_levels;
my @n0 = grep { $jouyou_levels{$_}->{notional_level} == 0 } keys %jouyou_levels;

print "N5: " . (0 + @n5) . "\n";
print "N4: " . (0 + @n4) . "\n";
print "N3: " . (0 + @n3) . "\n";
print "N2: " . (0 + @n2) . "\n";
print "N1: " . (0 + @n1) . "\n";
print "N0: " . (0 + @n0) . "\n";

# dump the jouyou_levels structure; very useful
DumpFile("jouyou_levels.yaml", \%jouyou_levels) or die;
