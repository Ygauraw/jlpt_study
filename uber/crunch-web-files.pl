#!/usr/bin/perl

# Crunch YAML files, do some checks and output to an sqlite database
#
# The main things I want to do here:
#
# * grade each kanji according to JLPT level
# * grade each vocab item likewise
# * store IDs to point back to respective websites for more info
#
# Where there is conflicting information regarding levels, I'll choose
# the easiest JLPT level that the kanji/vocab item appears in. I will
# therefore store per-site JLPT levels alongside the notional JLPT
# level.
#
# One thing that I won't be doing (though it would be useful) is to
# figure out level-appropriate readings for vocab.

use strict;
use warnings;

use YAML::XS qw(LoadFile DumpFile);

use utf8;

use DBI;

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

# use two-level indexes to get at kanji/vocab/grammar/expressions
# (just a convenience)
my @sources = qw(tanos jlpt tagaini);
my %distinct_kanji_by_level    = map { $_ => { map { $_ => undef } @sources }} (1..5);
my %distinct_kanji_by_source   = map { $_ => { map { $_ => undef } (1..5) }} @sources;
#y %cumulative_kanji_by_level  = map { $_ => { map { $_ => undef } @sources }} (1..5);
#y %cumulative_kanji_by_source = map { $_ => { map { $_ => undef } (1..5) }} @sources;
my $non_joyou = 0;
my %distinct_vocab_by_level    = map { $_ => { map { $_ => undef } @sources }} (1..5);
my %distinct_vocab_by_source   = map { $_ => { map { $_ => undef } (1..5) }} @sources;

# read in kanji data
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



sub register_kanji_level {
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
	    register_kanji_level($testkey, $src, $level);
	    next if exists $jouyou{$testkey};
	    warn "[$src,$level]: Found non-Joyou kanji '$testkey' (suppressing further notices)\n" 
		unless $non_joyou++;
	}
	
	# Index the data
	$distinct_kanji_by_source{$src}->{$level} =
	    $distinct_kanji_by_level{$level}->{$src} = $data;

	
	print "[$src,$level]: " . (0 + keys %$data) . " distinct entries\n";
	
    }
}

# 


print "Found $non_joyou non-Jouyou kanji in tested levels\n";

# Based on above kanji output, tagaini seems to use the same list as
# on the jlpt site
print "Conjecture: tagaini and jlpt kanji lists for N5, N4 and N2 are the same\n";

for my $level (5, 4, 2) {

    my $tagai = join "", sort { $a cmp $b } (
	keys %{$distinct_kanji_by_level{$level}->{tagaini}});
    my $jlpt = join "", sort { $a cmp $b } (
	keys %{$distinct_kanji_by_level{$level}->{jlpt}});

    die if $distinct_kanji_by_level{$level}->{jlpt} == $distinct_kanji_by_level{$level}->{tagaini};
    
    #print "$tagai\n$jlpt\n";   # just checking they're not null!
    print "Testing N$level: " . ($tagai eq $jlpt ? "same list\n" : "different list\n");
}
    
## OK, conjecture proven. How about trying to merge the data from each source?
## Too tricky to do quickly...

# I also notice that jlpt's N2 data could be a cumulative list
# (including N3 kanji). Testing this...

if (1) {
    my $jlpt_n5 = $distinct_kanji_by_level{5}->{jlpt};
    my $jlpt_n4 = $distinct_kanji_by_level{4}->{jlpt};
    my $jlpt_n3 = $distinct_kanji_by_level{3}->{jlpt};
    my $jlpt_n2 = $distinct_kanji_by_level{2}->{jlpt};

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
print "Found " . (0 + (keys %jouyou_levels)) . " kanji in all\n";

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
print "N0: " . (0 + @n0) . " (not listed at any JLPT level)\n";

# dump the jouyou_levels structure; very useful
DumpFile("jouyou_levels.yaml", \%jouyou_levels) or die;

##
## Vocab files
##
#
# These are just plain lists of words. I still have to compare levels
# across sources in a similar way to what I did with kanji.
#
my %vocab = ();
sub new_vocab {		       # just an empty entry, needs populating
    {
	ja_regular => '',
	ja_kana    => '',
	en_jlpt    => '',
	en_tanos   => '',
	en_tagaini => '',
	pos        => '',
	jlpt_level => 0,	# 0 means non-JLPT
	jlpt_level_jlpt => 0,	# 0 means non-JLPT
	jlpt_level_tanos => 0,	# 0 means non-JLPT
	jlpt_level_tagaini => 0,	# 0 means non-JLPT
	tanos_site_id => 0,
	
	# for storing up kana options
	kana_hash => {},
	
    };
};
sub register_vocab {
    my ($src,$lev,$hashref, @junk) = @_;
    die if @junk;
    die unless ref $hashref eq "HASH";

    my $eng  = $hashref->{english} || "";
    my $k    = $hashref->{regular} || "";
    my $kana = $hashref->{kana}    || "";
    if ($k eq '' or $kana eq '') {
	if ($k eq $kana) {
	    # warning and returning is the best we can do in this case
	    warn "[$src $lev] no kanji or kana (eng:$eng)\n";
	    return;
	}
	if ($kana eq '') { $kana = $k; } else { $k = $kana}
    }
    # There are quite a few N2 entries lacking English! Hopefully the
    # vocab will appear elsewhere to make up for the lack or I can
    # search the database and add things manually later.
    warn "[$src $lev] $k has no english\n" unless $eng;
    my $pos  = ""; $pos = $hashref->{type} if exists $hashref->{type};

    chomp $eng; chomp $eng; chomp $eng; chomp $eng;
    
    my $rec = exists $vocab{$k} ? $vocab{$k} : new_vocab();
    $rec->{jlpt_level} = $lev if $rec->{jlpt_level} < $lev;

    # fill in fields more or less as they will appear in
    # vocab_by_jlpt_grade table
    $rec->{ja_regular} = $k;

    # for ja_kana, I will store all possible kana renderings as keys
    # in a hash. Before outputting to the database this will have to
    # be converted back into a string
    my @kana_list = ($kana);
    if ($kana =~ m|\s*,\s*|) {
	@kana_list = split /\s*,\s*/, $kana;
    }
    foreach my $kana_item (@kana_list) {
	$rec->{kana_hash}->{$kana_item} = undef;
    }
    
    $rec->{tanos_site_id} = $hashref->{id} if exists $hashref->{id} ;

    $rec->{en_best} = "";
    $rec->{"en_$src"} = $eng;
    if (exists($rec->{"jlpt_level_$src"})) {
	# override our current level ($lev) if saved one is higher
	# There are a lot of the warnings below!
	#	warn "vocab $k appears in different $src levels\n";
	my $el = $rec->{"jlpt_level_$src"};
	$lev = $el if $el > $lev;
    }
    $rec->{"jlpt_level_$src"} = $lev;

    # save this record
    $vocab{$k} = $rec;

}

# read in vocab files
print "\nReading in vocab files:\n";
my $raw_vocab_count = 0;
for my $level (2..5) {		# ignore N1
    for my $src (@sources) {

	my $file = "${src}_n${level}_vocab.yaml";
	next unless -f $file;
	my $data = LoadFile($file);
	die "Problem loading '$file': $!\n" unless defined($data);

	# Validate data. 
	die "Wrong level info" unless $data->[0]->{level} eq $level;
	shift @$data;		# dump now-useless first record

	# Maybe register them all here and now?
	for (@$data) { register_vocab($src,$level,$_); }
	
	# Index the data
	$distinct_vocab_by_source{$src}->{$level} =
	    $distinct_vocab_by_level{$level}->{$src} = $data;

	$raw_vocab_count += @$data;
	print "  [$src,$level]: " . (0 + @$data) . " distinct entries\n";
    }
}
print "Total: $raw_vocab_count (including duplicates)\n";
print "Total: " . (0 + keys %vocab) . " (distinct entries)\n\n";
# Not including N1:
# Total: 16213 (including duplicates)
# Total: 5863 (distinct entries)
#
# That's fewer vocab than I expected

# Go through all entries and create the ja_kana field
map { $vocab{$_}->{ja_kana} = 
	  join ", ", keys %{$vocab{$_}->{kana_hash}}
} keys %vocab;

##
## Database creation
##
#
# It helps that I've got kanji and vocab already in a standard form
# during parsing:
#
# kanji_info is a hashref:
# {
#   id    => "ID, when used on source website",
#   on_yomi => [ on_reading, ...], 
#   kun_yomi => [ kun_reading, ... ],
#   other_readings => [ unrecognised_readings ], # always empty
#   stroke_count => number,
#   english => "english meaning of kanji",
#   vocab => [ vocab_info, ... ],
# }
# vocab_info is another hashref:
# {
#    id    => "ID, when used on source website",
#    vocab => "kanji/kana string",
#    kana  => "kana-only string",
#    english => "English translation",
#    type  => "type of vocab, eg (n) noun",
# }
# also grammar structure for tanos and jlpt sites (none in tagaini)

warn "About to nuke SQL database. Press <enter> to continue or quit now!\n";
<STDIN>;

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=web_data.sqlite", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );

map { eval { $dbh->do("drop table $_") }} qw(
  kanji_by_jlpt_grade
  kanji_readings 
  vocab_by_jlpt_grade
);

$dbh->commit;

$dbh->do("create table kanji_by_jlpt_grade (
   kanji               PRIMARY KEY,

   -- Readings present a problem because there are several 
   -- and sources might not all agree
   -- Move them into a separate table   

   -- I could put in stroke count, but it's not really useful

   en_best             text,     -- let user fill this in
   en_jlpt             text,
   en_tanos            text,
   en_tagaini          text,     -- very long (dictionary entry)
   
   tanos_site_id       integer,  -- look up more info on www.tanos.co.uk

   jlpt_level          integer,  -- 0 means non-JLPT
   -- the following are the per-website/source levels
   jlpt_level_jlpt     integer,
   jlpt_level_tanos    integer,
   jlpt_level_tagaini  integer   -- Jim Breen's kanadic2 as reported in tagaini


)");

# Sources differ in the number and presentation of on-yomi and
# kun-yomi so I will count up the number of times that they appear
# across sources. Then I can order searches by "popularity"

$dbh->do("create table kanji_readings (

   kanji               text  NOT NULL,
   type                text  NOT NULL,  -- 'on','kun'
   popularity          integer NOT NULL,-- how frequently it appears x10
   sightings           integer NOT NULL,-- popularity based on sightings

   kana                text NOT NULL    -- hiragana or katakana

)");

# There are actually two sets of vocab included on the tanos site. One
# is attached to the kanji and it seems to bear no relationship to
# JLPT levels. The other comprises separate lists that are graded.
# I'll keep both kinds in the one table and use a jlpt_level of -1 to
# indicate that they're ungraded. I might search the database later
# and update entries if I discover that they are in some JLPT level or
# other.
#
# I haven't included that second lot of vocab yet...

$dbh->do("create table vocab_by_jlpt_grade (
   ja_regular          text  NOT NULL, -- regular rendering
   ja_kana             text  NOT NULL, -- kana rendering
   en_best             text, -- best English meaning (user will fill this in)
   en_jlpt             text,
   en_tanos            text,
   en_tagaini          text, -- very long (dictionary entry)
   
   pos                 text, -- part of speech, only from jlpt study

   -- overall notional JLPT level;  0 means non-JLPT, -1 means unknown
   jlpt_level          integer,  
   -- the following are the per-website/source levels
   jlpt_level_jlpt     integer,
   jlpt_level_tanos    integer,
   jlpt_level_tagaini  integer,  -- Jim Breen's kanadic2 as reported in tagaini

   tanos_site_id       integer   -- look up more info on www.tanos.co.uk
   
)");

$dbh->commit;

foreach my $k (keys %vocab) {

    $dbh->do("insert into vocab_by_jlpt_grade (
      ja_regular,
      ja_kana,
   -- en_best,
      en_jlpt,
      en_tanos,
      en_tagaini,
      pos,
      jlpt_level,  
      jlpt_level_jlpt,
      jlpt_level_tanos,
      jlpt_level_tagaini,
      tanos_site_id
) values (" .
	     $dbh->quote($vocab{$k}->{ja_regular}) . "," .
	     $dbh->quote($vocab{$k}->{ja_kana}) . "," .
	     $dbh->quote($vocab{$k}->{en_jlpt}) . "," .
	     $dbh->quote($vocab{$k}->{en_tanos}) . "," .
	     $dbh->quote($vocab{$k}->{en_tagaini}) . "," .
	     $dbh->quote($vocab{$k}->{pos}) . "," .
	     $dbh->quote($vocab{$k}->{jlpt_level}) . "," .
	     $dbh->quote($vocab{$k}->{jlpt_level_jlpt}) . "," .
	     $dbh->quote($vocab{$k}->{jlpt_level_tanos}) . "," .
	     $dbh->quote($vocab{$k}->{jlpt_level_tagaini}) . "," .
             $vocab{$k}->{tanos_site_id} . ")" );
}

$dbh->commit;
$dbh->disconnect;
