#!/usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(LoadFile);

use utf8;

use File::Slurp;
use Cwd;
my $thisdir=cwd();

# For easier reporting
use Data::Dump qw(dump dumpf);

# Data::Dump is great, but it converts strings to Unicode escapes and
# is overly-verbose.
sub filter_dumped {
    my ($ctx, $object_ref) = @_;
    if ($ctx->is_scalar) {
	return { dump => "'" . $$object_ref . "'" }; # needs $$!
    } elsif($ctx->is_hash) {
	return { hide_keys => ['ruby','id','text_alt','ja_alt'] };
    } else {
	return undef;
    }
    return undef;
}

sub pp_core2k_entry {
    my $ent = shift or die;
    dumpf($ent,\&filter_dumped) . "\n";
}

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';


# Do some checking on two sets of Core vocabulary, mainly to see what
# sort of overlap there is

# First, examine the structure of the Core 6,000 file
my $sample_6k = LoadFile("615865.yaml");

print ref($sample_6k);		# hash
print keys %$sample_6k;		# {"items"}
print ref($sample_6k->{items}); # array
print ref($sample_6k->{items}->[0]); # hash
print join ",", keys %{$sample_6k->{items}->[0]}; # response, id, cue, uri
print "\n---\n";

# Just looking at YAML file directly now

# read in order file

my @file_order=read_file('order.txt');
print shift @file_order;
foreach (@file_order) {chomp}

# counters get post-incremented
my ($seq_file, $seq_within, $seq_total) = (1, 1, 1);

my %keys_6k = ();
my @keys_6k_seq = ();
my @entries_6k_seq = ();
my $clashes_6k_distinct = 0; # number of 6k entries with the same Japanese index
my $clashes_6k_total    = 0; #
my %clashing_6k = ();

sub register_key_6k {
    my ($key, $entry) = @_;
    if (exists $keys_6k{$key}) {
	unless (exists $clashing_6k{$key}) {
	    ++ $clashes_6k_distinct;
	}
	++ $clashes_6k_total;
	$clashing_6k{$key} = undef;
    } else {
	$keys_6k{$key} = [];
    }
    push @{$keys_6k{$key}}, $entry;
    push @keys_6k_seq, $key;
    push @entries_6k_seq, $entry;
    $entry->{abs_sequence} = 0 +  @entries_6k_seq;
}

foreach my $fn (@file_order) {

    $seq_within = 1;
    my $chapter = LoadFile("${fn}.yaml");

    for my $entry (@{$chapter->{items}}) {
	my $key = $entry->{cue}->{content}->{text};
	die unless defined $key;
	my $pos_in_file = $entry->{cue}->{related}->{position};

	# It appears that position number within the file is not always correct
	# warn "$fn: $pos_in_file != $seq_within\n" unless $seq_within == $pos_in_file;

	# save extra data
	$entry->{meta} = {
	    chapter => $seq_file,
	    chapter_sequence => $seq_within,
	    file => $fn,
	    overall_sequence => $seq_within + 100 * $seq_file - 100,
	    ja_text => $key,
	    en_text => $entry->{response}->{content}->{text},
	};

	++$seq_within;

	register_key_6k($key, $entry);

    }    
    ++ $seq_file;
} 

# OK, there are clashes. I wonder how to handle this in Anki...
print "There were $clashes_6k_total total key clashes representing ". 
    "$clashes_6k_distinct distinct terms\n";
print join "\t", keys %clashing_6k;
print "\n";

# I guess that the thing to do is just include (1), (2), ... after
# each term within Anki. As for here, it appears that I already
# anticipated such clashes and made the code use an array :)

# Next, read in the Core 2,000 file

my $core_2k = LoadFile('core-2000.yaml') or die;

# After analysing core2k and core6k for differences, I came up with a
# list of changes to make to the core2k file to bring it in line with
# the core6k list. I wrapped up the changes in a sub that I'll use
# now.

override_core2k_entries($core_2k);

my $matching_count = 0;
my $no_match_count = 0;
my @no_matches = ();
my @no_match_index = ();
my $seq_2k = 1;
my $pos_delta = 0; 		# estimate how "out of order" things are

sub find_min_delta {
    my ($key,$seq_2k,$penalty) = @_;
    $penalty = 6000 unless defined($penalty);
    my ($abs_diff, $abs_min) = (0,0);
    my $seq_6k;

    unless (exists $keys_6k{$key}) {
	return $penalty;
    }
    for my $entry (@{$keys_6k{$key}}) {
	if (exists($entry->{meta}->{overall_sequence})) {
	    $seq_6k = $entry->{meta}->{overall_sequence};
	    $abs_diff = abs($seq_2k - $seq_6k);
	    $abs_min = $abs_diff if $abs_min < $abs_diff;
	    #warn $abs_min;
	} else {
	    die;
	}
    }
    return $abs_min;
}

my %keys_2k = ();
my %clashes_2k = ();
for my $entry (@$core_2k) {

    die unless exists $entry->{ja_regular};
    
    my $key = $entry->{ja_regular};

    if ($key eq "") {
	print join "|\n|", keys %$entry;
    }
    
    if (exists($keys_6k{$key})) {
	++$matching_count;
    } else {
	++$no_match_count;
	push @no_matches, $key;
	push @no_match_index, $seq_2k;
	# $pos_delta += 6_000.0;
    }
    $pos_delta += find_min_delta($key, $seq_2k);

    if (exists $keys_2k{$key}) {
	$clashes_2k{$key} = undef;
    } else {
	$keys_2k{$key} = $entry;
    }
    ++$seq_2k;
}

my $total_core_2k = $matching_count + $no_match_count;
print "Core 2k set had $no_match_count / $total_core_2k non-matching entries:\n";
print join "|\n|", @no_matches;
print "\n";

# OK, fixed all of those

print "Number of Core 2k clashes (internally): " . (0 + keys(%clashes_2k));
print "\n";
print join "\t", keys(%clashes_2k);
print "\n";

if (0) {
    print "Elements are out of order by an average of ". ($pos_delta / 2000) .
	" positions\n";

    print "Excluding the non-matching elements, that's " . 
	(($pos_delta - 6000 * $no_match_count) / (2000 - $no_match_count)) . "\n";

    print "Without averaging: " . 
	(($pos_delta - 6000 * $no_match_count)) . "\n";

    # That was initially telling me that the 2,000 core match up
    # exactly with the first of the 6,000. Test that by showing
    # side-by-side of keys:
    printf("Seq. %-20s %s\n", "Core 2,000", "Core 6,000");
    
    for (0 .. $no_match_count -1) {
	my $core_2k_key = $no_matches[$_];
	my $key_index   = $no_match_index[$_];
	my $core_6k_key = $keys_6k_seq[$key_index];
	
	printf("%04d %-20s %s\n", $_, $core_2k_key, $core_6k_key);
    }
    # Sanity check:
    for (0..5) {
	print $core_2k->[$_]->{ja_regular} . "\t";
	print $keys_6k_seq[$_] . "\n";
    }
}



if (0) {
    ## Looks like either (a) the 6k list has a completely different
    ## order, or (b) the order file has some mistakes. Looking at the
    ## first few items, I think that the latter may be correct.

    # I can use the find_min_delta routine to detect how out-of-place each
    # chapter is. Yay.
    my $abs_index = 0;

    for my $chapter_2k (0..19) {
	my $disorder = 0;

	print "Chapter: " . ($chapter_2k + 1) . "\n";
	
	for my $sample (0..4) {
	    die unless exists($core_2k->[$abs_index]->{ja_regular});
	    my $key = $core_2k->[$abs_index]->{ja_regular};

	    print "$key\t" . $keys_6k_seq[$abs_index] . "\n";
	    
	    $disorder += find_min_delta($key, $abs_index, 6000);
	    ++$abs_index;
	}
	$disorder/=5.0;
	print "Chap. " . ($chapter_2k+1) . "\t$disorder\n";
	$abs_index += 95;
    }

    # OK, that didn't really help to re-order things.

    # return a 6k chapter that best matches
    my @index_6k_by_chapter = ();
    sub index_6k_by_chapter {
	for my $ch (0 .. 59) {
	    my %hash;
	    for ($ch * 100 .. $ch * 100 + 99) {
		$hash{$keys_6k_seq[$_]} = undef;
	    }
	    push @index_6k_by_chapter, \%hash;
	}
    }
    my @index_2k_by_chapter = ();
    sub index_2k_by_chapter {
	for my $ch (0 .. 19) {
	    my (%hash, $key);
	    for ($ch * 100 .. $ch * 100 + 99) {
		die unless exists $core_2k->[$_]->{ja_regular};
		$key = $core_2k->[$_]->{ja_regular};
		$hash{$key} = undef;
	    }
	    push @index_2k_by_chapter, \%hash;
	}
    }
    sub calculate_affinity_6k_from_2k {

	my ($index_2k_low, $index_2k_high) = @_;

	my $matches;
	my $best_chapter = undef;
	my $best_matches = -1;
	my $key;
	for my $chapter (0 .. 59) {
	    $matches = 0;
	    for my $index_2k ($index_2k_low .. $index_2k_high) {
		$key = $core_2k->[$index_2k]->{ja_regular};
		if (exists $index_6k_by_chapter[$chapter]->{$key}) {
		    ++$matches;
		}
	    }
	    if ($matches > $best_matches) {
		#	    warn $matches;
		$best_matches = $matches;
		$best_chapter = $chapter;
	    }
	}
	return $best_chapter;
    }

    sub calculate_affinity_2k_from_6k {

	my ($index_6k_low, $index_6k_high) = @_;

	my $matches;
	my $best_chapter = undef;
	my $best_matches = -1;
	my $key;
	for my $chapter (0 .. 19) {
	    $matches = 0;
	    for my $index_6k ($index_6k_low .. $index_6k_high) {
		$key = $keys_6k_seq[$index_6k];
		if (exists $index_2k_by_chapter[$chapter]->{$key}) {
		    ++$matches;
		}
	    }
	    if ($matches > $best_matches) {
		#	    warn $matches;
		$best_matches = $matches;
		$best_chapter = $chapter;
	    }
	}
	return $best_chapter;
    }

    index_6k_by_chapter();
    print "2k ch\t\tbest 6k match\n";
    for my $ch (0..19) {
	print "Chapter " . ($ch + 1) . "\t" .
	    (1 + calculate_affinity_6k_from_2k($ch * 100, $ch * 100 + 99)) . "\n";
    }

    index_2k_by_chapter;
    print "6k ch\t\tbest 2k match\n";
    for my $ch (0..59) {
	print "Chapter " . ($ch + 1) . "\t" .
	    (1 + calculate_affinity_2k_from_6k($ch * 100, $ch * 100 + 99)) . "\n";
    }

    # OK, that seems to minimise the distance that things are off by. With
    # that, I can probably concentrate on the 6k list. I might fix up a
    # few entries from the 2k list, though:
    #
    # 苺: いちご usually kana
    # 未だ: まだ usually kana
    # 段々: だんだん usually kana
    # 朝御飯: 朝ご飯 usually kana for ご
    # 幾つ: いくつ usually kana
    # 茄子: なす usually kana
    # 居る: いる usually kana
    # おなか: お腹 usually KANJI
}


# I might as well populate database tables in this program
#
# Comparing on ja_regular isn't completely straightforward due to
# mistakes with uk/uK. Nor is comparing on ja_sentence due to
# differences in quoting style. In fact, even comparing on index
# number isn't great due to my reordering of the core6k items...

# I'm inclined to sort out those 25 non-matching entries first. I
# think that I'll add another field ja_alt to store any alternative
# writing form, eg ja_alt: 出来る, ja_regular: できる
# Likewise, I'll include alt_text in the core6k file.
#
# OK, done. Now... did I check whether there are duplicated keys in
# the 2k file? I don't think so...
#
# Did that and found 35 vocab that have two or more entries.
#

# Try to join up entries. With 2,000 entries, it's infeasible to do
# this by hand.

my ($count_problem_keys, $count_possible_options) = (0,0);
my $count_solutions = 0;

# editing after I've sorted out conflicts: save some data needed to
# populate core_2k database table. The rest is populated while filling
# in the core6k tables.

my %core_2k_db_table = ();

sub match_2k_6k {
    my $key_2k = shift or die;
    my $ent_2k = shift or die;
    my $seq_6k = shift or die;
    my $sen_6k = shift;

    # make sure that there's a match
    die unless $key_2k;

    my $val = {
	"6k_vocab" => $seq_6k,
	"sentence_index" => $sen_6k,
    };
    
    $core_2k_db_table{$key_2k} = $val;
    
    dumpf ({$key_2k => $val}, \&filter_dumped);
}

my %map_2k_indices_to_6k = ();
my $id = 1;
foreach my $core_2k_ent (@$core_2k) {
    my $key = $core_2k_ent->{ja_regular} or die;
    die unless $core_2k_ent->{id} == $id;

    # find out how many matching core6k entries there are; these are
    # the ones that we will have to resolve somehow (probably by
    # comparing English sentences)
    
    my $matching_6k = $keys_6k{$key};
    die unless defined $matching_6k;

    if (scalar(@$matching_6k) < 1) {
	die
    } elsif (scalar(@$matching_6k) == 1) {

	my $core_6k_entry = $matching_6k->[0];
	my $seq_6k = $core_6k_entry->{abs_sequence} or die;
#	my $seq_6k = $core_6k_entry->{meta}->{overall_sequence};
	die if $seq_6k == 0;
	die if $seq_6k != $core_6k_entry->{abs_sequence};
	# match_2k_6k($key, $core_2k_ent, $seq_6k, 0);
	$map_2k_indices_to_6k{$id} = "$seq_6k:0";

    } elsif (scalar(@$matching_6k) > 1) {
	++$count_problem_keys;
	$count_possible_options += scalar(@$matching_6k);

	my $fixed = 0;
	my $debug_string;

	$debug_string = "Core2k entry $id:\n" . pp_core2k_entry($core_2k_ent);

	# try to pick the best option
	my $best_6k_entry = undef;
	my $best_6k_sen   = undef;
	my $best_6k_index = undef;
	my $en_sen_2k = $core_2k_ent->{en_sentence} or die;
      find_best:
	foreach my $core_6k_entry (@$matching_6k) {

	    # save main info from matching 6k entries
	    $debug_string .= 
		"  Matches 6k # " .
		$core_6k_entry->{meta}->{overall_sequence} . " :\n" ;

	    $best_6k_index = 0;
	    my $this_id = $core_6k_entry->{abs_sequence} or die;
	    
	    my $sen_6k = $core_6k_entry->{cue}->{related}->{sentences} or die;
	    for my $sen (@$sen_6k) {
		my $ja_sen_6k = $sen->{text};
		my $en_sen_6k = $sen->{translations}->[0]->{text};
		$ja_sen_6k =~ s/<.*?>//g;
		$debug_string.= "   en_sentence=> '$en_sen_6k'\n";
		$debug_string.= "   ja_sentence=> '$ja_sen_6k'\n";
		if ($en_sen_6k eq $en_sen_2k) {
		    ++$count_solutions;
		    ++$fixed;
		    $map_2k_indices_to_6k{$id} =
			#			$matching_6k->[$best_6k_index]->{meta}->{overall_sequence} .
			$this_id .
			":$best_6k_index";
#		    warn "yes (6k key $key=$ja_sen_6k)" if $map_2k_indices_to_6k{$id} eq "322:1";
		    # $best_6k_entry = $core_6k_entry;
		    # $best_6k_sen   = $sen_6k;
		    last find_best;
		}
		++$best_6k_index;
	    }
	    # didn't find a match ...
	}
	if ($fixed) {
	    #my $sen_6k = $best_6k_sen or die;
	    #warn "best option is $best_6k_index\n";
	    #warn "out of " . (0+@$sen_6k) . "\n";
	    #my $tmp_hash = $sen_6k->[$best_6k_index] or die;
	    #my $entry_seq_6k = $best_6k_entry->{meta}->{overall_sequence} or die;
	    #match_2k_6k($key, $core_2k_ent, $entry_seq_6k, $best_6k_index);
	} else {
	    print $debug_string;
	}
    }
    ++$id;			# OK, sequence IDs in file are good
}

# reverse the map_2k_indices_to_6k array (not needed, just shows many->one map)
print "map_2k_indices_to_6k has " . (0 + keys %map_2k_indices_to_6k) . " entries\n";
my %map_6k_indices_to_2k = ();
for my $k (sort { $a <=> $b } keys %map_2k_indices_to_6k) {
    my $v = $map_2k_indices_to_6k{$k};
    #warn "$k, $v\n" if exists $map_6k_indices_to_2k{$v};
    warn "found 322:1 in key\n" if $k eq "322:1";
    warn "found 322:1 in val\n" if $v eq "322:1";
    $map_6k_indices_to_2k{"$v"} = $k
}

# First run through found 91 keys
print "Found $count_problem_keys core2k keys that have multiple core6k options\n";
print "Those keys represent $count_possible_options possible mappings\n";

# Checking for matching sentences under that key fixed 61/91
print "Scanning English sentences fixes $count_solutions of those keys\n";

# for the remaining 31, I can try searching for sentences under
# any/all keys. Or I can do it manually. Most things seem to be either
# minor edits of the English sentence or a wrong kanji reading (eg 円
# instead of 丸)

# Since I want to keep the audio in sync with sentences, these
# overrides will take the 6k element the same and change the 2k
# element to match.

# Not bad. Only 4 entries weren't easily fixed by looking at the
# report. I'll go back and apply these right at the start of the
# program, before any indexes are created.

sub override_core2k_entries {

    my $c2k = shift or die;
    my %core_2k_overrides = (
	5    => 4,		# 家, Please come over to my home.
	8    => "7.0",		# 私, I'll go.
	162  => 97,		# 今日, I don't have work today.
	222  => 218,		# 起きる, A burglary occured in my neighborhood.
	263  => 254,		# 空く, There weren't many people at the restaurant.
	266  => 257,		# 日, We got married on the 11th last month.
	342  => 300,		# 金, This cost quite a lot of money.
	344  => 332,		# 昨日, I met my friend yesterday.
	353  => 340,		# 四, I entered college in April.
	368  => 358,		# 何, What would you like to eat for dinner?
	536  => 444, 		# ただ, This hot spring bathhouse is free.
	751  => 724,		# 自然, Let us all work together to protect nature.
	893  => 467,		# クラス, This school has 30 people in each class.
	900  => 801,		# うまい, I found a good sushi restaurant.
	1386 => 1350,		# 日, Days are longer in summer.
	1615 => 1610,		# のり,  stuck two sheets of paper together with glue.
	1691 => 0,			# 明日、会社を休みます。
	1699 => 0,			# 財布は引き出しの中 にあります。
	1721 => 761,		# まあまあ, His grades are not bad.
	1768 => 1921,		# 一昨日, I got a phone call from him the day before yesterday.
	1774 => 773,		# 九, I'm planning to go there in September.
	1796 => 777,		# 七, In total, there are seven members in the group.
	1828 => 1911,		# おばさん, My aunt and her family came to visit me.
	1830 => 1803,		# 表, There's someone at the front door.
	1835 => 1990,		# 方, Next please.
	1882 => 0,			# 空 が真っ青です。
	1909 => 1906,		# 何, What's your question?
	1958 => 1844,		# In Japan, there's a bean throwing festival in February.
	1975 => 1987,		# I saw a shooting star last night.
	1995 => 0,
	);

    # add more manual overrides for the 4 other entries

    # Actually, it seems that those four didn't have any matching
    # entries in the 6k file so I just replaced the 2k sentences with
    # appropriate ones from 6k.
    
    # do the overrides
    foreach my $obiwan_key (keys %core_2k_overrides) {
	my $key = $obiwan_key -1; # my list is off by one
	
	my $r_6k_key = $core_2k_overrides{$obiwan_key};
	my $r_6k_ind = 0;	# optional index
	$r_6k_ind = $2 if $r_6k_key =~ s/^(\d+)\.(\d+)/$1/;
	--$r_6k_key;

	my $ent_2k = $c2k->[$key];
	#	warn "\nKey '$obiwan_key': ent_2k: $ent_2k->{ja_regular}, " .
	#	    "id=$ent_2k->{id}\n";

	die unless $ent_2k->{id} == $obiwan_key;

	
	my $ent_6k = $entries_6k_seq[$r_6k_key] or die;
	# warn "\nKey '$obiwan_key': $ent_6k\n";

	my $sen_6k = $ent_6k->{cue}->{related}->{sentences}
	                    ->[$r_6k_ind] or die;
	# warn "sen_6k is of type " . ref($sen_6k);

	# until I have all the gaps filled in
	if ($r_6k_key <= 0) {
	    warn "Skipping override of core 2k entry $obiwan_key\n";
	    next
	}
	
	# fields to update
	my ($en_sentence, $ja_kana, $ja_regular);

	#dumpf($sen_6k, \&filter_dumped);
	
	$en_sentence = $sen_6k->{translations}->[0]->{text}   or die;
	$ja_regular  = $ent_6k->{cue}->{content}->{text} or die;
	#	$ja_kana     = # don't change
	
	$ent_2k->{en_sentence} = $en_sentence;
	$ent_2k->{ja_regular}  = $ja_regular;
    }
    
}


# I was thinking of creating a YAML file but it's probably better if I
# use a database. That way I can put sounds (and other assets?) into
# it. This has advantages of (a) not needing to mess around with
# directory and file names, and (b) being easy to serve to webkit.

# 

warn "About to nuke database. Use ^C to quit or else hit enter\n";
<STDIN>;

use DBI;

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=core_2k_6k.sqlite", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );
my ($sth, $rc);

print "Ignore any 'no such table' messages below\n";
map { eval { $dbh->do("drop table $_") } }
      qw/sounds images vocabulary sentences core_2k 
         core_6k core_6k_sentences/;
print "End of ignorable messages\n";

# create the database tables

$dbh->do("create table sounds (
   id              INTEGER PRIMARY KEY,
   url             TEXT,
   type            TEXT, -- 'vocab' or 'sentence'
   content_type    TEXT, -- eg, 'audio/mpeg' or whatever HTML5 needs
   local_filename  TEXT,
   audio           BLOB
)
");
$dbh->commit;
$dbh->do("create table images (
   id              INTEGER PRIMARY KEY,
   url             TEXT,
   type            TEXT, -- 'word' or 'sentence'
   content_type    TEXT, -- eg, 'image/jpeg' or whatever HTML5 needs
   local_filename  TEXT, -- might be better (400Mb of asset data)
   audio           BLOB
)");
$dbh->commit;


# middle level 
$dbh->do("create table vocabulary (
   id               INTEGER PRIMARY KEY,
   ja_text          TEXT,   -- regular reading
   ja_kana          TEXT,
   ja_hira          TEXT,   -- converts even katakana
   ja_romaji        TEXT,
   ja_alt           TEXT,   -- alternative (non-usual) reading(s)
   en_text          TEXT,
   en_text_2k       TEXT,   -- in case the text differs
   en_text_6k       TEXT,   -- in case the text differs
   pos              TEXT,   -- part of speech
		   
   core_2k_seq      INTEGER,
		   
   sound_id         INTEGER -- just sound for the vocab entry
)");
$dbh->commit;

# Bottom level. Sentences are very similar to vocab entries.
$dbh->do("create table sentences (
   id              INTEGER PRIMARY KEY,
   ja_text         TEXT,  -- regular reading
   ja_kana         TEXT,
   ja_hira         TEXT,  -- converts even katakana
   ja_romaji       TEXT,
   ja_ruby         TEXT,  -- only for sentences
   
   en_text         TEXT,
   en_text_2k      TEXT,  -- in case the text differs
   en_text_6k      TEXT,  -- in case the text differs
   
   sound_id        INTEGER,
   image_id        INTEGER

)");
$dbh->commit;

# Duplicate some data below so that some searches become easier

$dbh->do("create table core_2k (
   id                INTEGER PRIMARY KEY,
   ja_vocab          TEXT NOT NULL, -- regular reading
   ja_vocab_kana     TEXT NOT NULL, -- ja_kana reading
   en_vocab          TEXT NOT NULL,

   vocab_id          INTEGER NOT NULL,

   -- Later on I may have a separate table to add more sentences, but
   -- for now I'll just store a single sentence

   main_sentence_id  INTEGER NOT NULL
)");
$dbh->commit;


$dbh->do("create table core_6k (

   id              INTEGER PRIMARY KEY,
   ja_vocab        TEXT NOT NULL, -- regular reading
   ja_vocab_kana   TEXT NOT NULL, -- ja_kana reading
   en_vocab        TEXT NOT NULL
     
   -- can have many sentences, stored in next table

)");
$dbh->commit;

$dbh->do("create table core_6k_sentences (
   core_6k_id      INTEGER,
   sentence_id     INTEGER
)");
$dbh->commit;

# Start by going through the core 6k YAML file and associated index
my $id_6k = 1;			# auto-increment for core_6k ...
my $id_vocab = 1;
my $id_images = 1;
my $id_sounds = 1;
my $id_sentences = 1;
my $id_2k = 1;			# ... and other tables

sub ja_text_from_ent { shift->{cue}->{content}->{text} or die }
sub transliterations {		# works with vocab or sentence
    my $listref = shift or die;
    my $ret = {};
    foreach my $text_type (@$listref) {
	my $text = $text_type->{text} or die;	
	if ($text_type->{type} eq "Hira") {
	    $ret->{"ja_hira"} = $text;
	} elsif ($text_type->{type} eq "Hrkt") {
	    $ret->{"ja_kana"} = $text;
	} elsif ($text_type->{type} eq "Latn") {
	    $ret->{"ja_romaji"} = $text;
	} else { die dumpf($text_type, \&filter_dumped) }
    }
    $ret;
}    
sub create_sound_entry {
    my ($dbh,$type,$id, $url,@junk) = @_;
    die if @junk;

    # convert url into local filename
    my $fn=$url;
    $fn =~ s|^http://|| or die;
    $fn =~ s|^(assets\d).*?/|$thisdir/$1/| or die;
    die unless -f $fn;
    
    $dbh->do("insert into sounds values (" . 
	     (join ",", (
		  $id,
		  $dbh->quote($url),
		  $dbh->quote($type),
		  $dbh->quote("audio/mpeg"),
		  $dbh->quote($fn),
		  $dbh->quote(""),
	      )) . ")");
}

sub create_image_entry {
    my ($dbh,$type,$id, $url,@junk) = @_;
    die if @junk;

    # convert url into local filename
    my $fn=$url;
    $fn =~ s|^http://|| or die;
    if ($fn =~ s|^(assets\d).*?/|$thisdir/$1/|) {
	die unless -f $fn;
    } else {
	# some links point to flickr; just say we don't have local file
	$fn = ''
    }
    
    $dbh->do("insert into images values (" . 
	     (join ",", (
		  $id,
		  $dbh->quote($url),
		  $dbh->quote($type),
		  $dbh->quote("image/jpeg"),
		  $dbh->quote($fn),
		  $dbh->quote(""),
	      )) . ")");
}


my %map_6k_sen_offset_to_sid =();
for my $ent (@entries_6k_seq) {

    die if $id_vocab != $ent->{abs_sequence};
    #dumpf($ent, \&filter_dumped) if $id_vocab == 322;
    
    # create vocab table entry first
    my $vocab_ja_text = ja_text_from_ent($ent);
    #dumpf($ent, \&filter_dumped) if $vocab_ja_text eq "近く";
    my $tl_list = $ent->{cue}->{related}->{transliterations} or die;
    my $tt = transliterations($tl_list);
    my $vocab_ja_kana   = $tt->{ja_kana}   or die;
    my $vocab_ja_hira   = $tt->{ja_hira}   or die;
    my $vocab_ja_romaji = $tt->{ja_romaji} or die;
    my $vocab_ja_alt    = "";
    if (exists $ent->{cue}->{content}->{text_alt}) {
	$vocab_ja_alt = $ent->{cue}->{content}->{text_alt};
    }
    my $vocab_en_text_2k = '';	# fill in later
    my $vocab_en_text = $ent->{response}->{content}->{text} or die;
    my $vocab_en_text_6k = $vocab_en_text;
    my $pos = $ent->{cue}->{related}->{part_of_speech} or die;
    my $core_2k_seq = 0;	# fill in later
    my $core_6k_seq = $id_6k;

    # vocab entries also have sound at the top level
    my $vocab_sound_id    = $id_sounds++;
    my $vocab_sound_url   = $ent->{cue}->{content}->{sound} or die;
    create_sound_entry($dbh, "vocab", $vocab_sound_id, $vocab_sound_url);

    # should be enough for vocab table entry
    $dbh->do("insert into vocabulary values (" . 
	     (join ",", (
		  $id_6k,
		  $dbh->quote($vocab_ja_text),
		  $dbh->quote($vocab_ja_kana),
		  $dbh->quote($vocab_ja_hira),
		  $dbh->quote($vocab_ja_romaji),
		  $dbh->quote($vocab_ja_alt),
		  $dbh->quote($vocab_en_text),
		  $dbh->quote($vocab_en_text_2k),
		  $dbh->quote($vocab_en_text_6k),
		  $dbh->quote($pos),
		  0,
		  $vocab_sound_id,
	      )) . ")");

    # I also have a core6k-specific index, but it's just a subset of the above
    $dbh->do("insert into core_6k values (" . 
	     (join ",", (
		  $id_6k,
		  $dbh->quote($vocab_ja_text),
		  $dbh->quote($vocab_ja_kana),
		  $dbh->quote($vocab_en_text),
	      )) . ")");

    # That deals with all the outer stuff. Now we have to traverse all
    # the sentences within the vocab entry and popuate a bunch of
    # other tables.

    my $sen_list = $ent->{cue}->{related}->{sentences} or die;
    die unless ref($sen_list) eq "ARRAY";
    my $sen_offset = 0;
    foreach my $sent (@$sen_list) {

	# We'll add to sounds, images, sentences and core_6k_sentences

	# start with core_6k_sentences
	my $sid = $id_sentences++; # must match across all added recs
	$dbh->do("insert into core_6k_sentences values ($id_6k, $sid)");
	
	# sounds
	my $sen_sound_id  = $id_sounds++;
	my $sen_sound_url = $sent->{sound} or die;
	create_sound_entry($dbh,"sentence", $sen_sound_id, $sen_sound_url);

	# images
	my $img_id=0;		# will need this later
	if (exists($sent->{image}) or exists($sent->{square_image})) {
	    # I can't be bothered looking into this. Use whatever image is available
	    my $img_url;
	    $img_id  = $id_images++;
	    $img_url = $sent->{square_image} if exists $sent->{square_image};
	    $img_url = $sent->{image}        if exists $sent->{image};
	    create_image_entry($dbh, "sentence", $img_id, $img_url);
	}

	# all that remains is sentences table
	# already have $sid
	my $sen_ja_text = $sent->{text} or die;
	my $sen_tl_list = $sent->{transliterations} or die;
	my $sen_tt = transliterations($sen_tl_list);
	my $sen_ja_kana   = $sen_tt->{ja_kana}   or die;
	my $sen_ja_hira   = $sen_tt->{ja_hira}   or die;
	my $sen_ja_romaji = $sen_tt->{ja_romaji} or die;
	my $sen_ja_ruby   = '';

	my $sen_en_text   = $sent->{translations}->[0]->{text} or die;
	my $sen_en_text_2k = '';
	my $sen_en_text_6k = $sen_en_text;
	# already have sound, image ids saved from above

	$dbh->do("insert into sentences values (" . 
	     (join ",", (
		  $sid,
		  $dbh->quote($sen_ja_text),
		  $dbh->quote($sen_ja_kana),
		  $dbh->quote($sen_ja_hira),
		  $dbh->quote($sen_ja_romaji),
		  $dbh->quote($sen_ja_ruby),
		  $dbh->quote($sen_en_text),
		  $dbh->quote($sen_en_text_2k),
		  $dbh->quote($sen_en_text_6k),
		  $sen_sound_id,
		  $img_id,
	      )) . ")");

	my $sen_off = "$id_vocab:$sen_offset";
	#warn "$sen_off\n" if $sen_offset == 1;
	#die "all good" if exists $map_6k_indices_to_2k{"322:1"};
	if (exists $map_6k_indices_to_2k{$sen_off} ) {
	    #warn "got here\n";
#	    warn "got here too " if $sen_off eq "322:1";
#	    warn "added a :1\n" if $sen_offset == 1;
	    $map_6k_sen_offset_to_sid{$sen_off} = $sid;
	}
	
	++$sen_offset;
    }
    ++$id_vocab;
    ++$id_6k;
}
$dbh->commit;

# now go through all the core 2,000 entries.

#warn "Final revmap has " . (0 + keys %map_6k_sen_offset_to_sid) . " entries\n";
#warn "Final good" if exists $map_6k_sen_offset_to_sid{"322:1"};

$id_2k = 1;
for my $ent (@$core_2k) {
    die unless exists $map_2k_indices_to_6k{$id_2k};
    my $sen_off = $map_2k_indices_to_6k{$id_2k} or die;
    unless (exists $map_6k_sen_offset_to_sid{$sen_off}) {
	die "$id_2k => $sen_off\n" 
    }
    my $sid = $map_6k_sen_offset_to_sid{$sen_off};
    my $vid = $sen_off; $vid =~ s/:.*// or die;
    my $ruby = $ent->{ruby};
    
    $dbh->do("insert into core_2k values (" . 
	     (join ",", (
		  $id_2k,
		  $dbh->quote($ent->{ja_regular}),
		  $dbh->quote($ent->{ja_kana}),
		  $dbh->quote($ent->{en_index}),
		  $vid,
		  $sid
	      )) . ")");

    $dbh->do("update sentences set ja_ruby = " .
	     $dbh->quote($ruby) . " where id=$sid");

    $dbh->do("update vocabulary set core_2k_seq = $id_2k " .
	      "where id=$vid");

    ++$id_2k;
}


$dbh->commit;
$dbh->disconnect;
