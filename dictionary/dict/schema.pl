#!/usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(LoadFile);

use DBI;
#use DBD::SQLite;

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

# The first difficult question is whether to index on ent_seq, keb or
# reb or a combination of all three. At least ent_seq is unique, while
# I suspect that there may be overlaps among the others. I will test
# out this theory. Well at least it's obvious that reb won't be unique
# because of possible homonyms...

# First, load in the YAML file and create indexes for ent_seq
# (copy/paste)

use YAML::XS qw(LoadFile);
use Data::Dumper;

$|=1;
print "Loading dictionary: ";
my $dict = LoadFile("JMdict.yaml");
print "done.\n";

# We need a lookup for sequence number since there are gaps in the
# numbering
my %seq_to_entry = ();
my $ent_base = $dict->{entry};
my $ent_index= 0;
foreach my $ent (@{$ent_base}) {
    die unless exists $ent->{ent_seq};
    $seq_to_entry{$ent->{ent_seq}} = $ent;
    $ent_index++;		# not used right now
}

print "Done indexing ent_seq entries\n";

sub has_more_than_one_key {
    my $keb_hash = shift;
    return 1 if ((keys %$keb_hash) > 1);
    return 0;
}

if (1) {
    print "Testing for uniqueness of keb entries\n";
    my %keb_index = ();
    my %hiragana_only_index = ();
    my %katakana_only_index = ();
    my ($unusual_more_than_keb, $unusual_more_than_reb, $hira_kata_paths,
	$keb_clashes, $kata_clashes, $hira_clashes, $keb_hira_clashes) = ((0) x 7);
    foreach my $ent (@{$ent_base}) {
	if (exists $ent->{k_ele}) {
	    die unless exists $ent->{r_ele};
	    my $k_ele = $ent->{k_ele};
	    # k_ele can be a hash ( { keb => ... } ) or a list of such
	    # items. To cut down on duplicated code, promote a single
	    # hash to a list of hashes
	    my $k_ele_list = (ref($k_ele) eq "HASH") ? [ $k_ele ] : $k_ele;
	    for my $keb_hash (@$k_ele_list) {
		$unusual_more_than_keb += has_more_than_one_key($keb_hash);
		die unless exists $keb_hash->{keb};
		my $keb = $keb_hash->{keb};
		if (exists $keb_index{$keb}) {
		    ++$keb_clashes;
		} else {
		    $keb_index{$keb} = undef;
		}
		
		# Because we scan k_ele and r_ele in one pass, we
		# might not detect the case of a clash between k_ele
		# and hiragana if the k_ele hasn't been seen yet. Do
		# the reciprocal test here.
		if (exists($hiragana_only_index{$keb})) {
		    ++$keb_hira_clashes;
		}
	    }
	} else {
	    # If there's no k_ele, then we could be dealing with
	    # either a hiragana or katakana term. Rather than promote
	    # them blindly, I'll keep two separate indices for them.
	    ++$hira_kata_paths;
	    die unless exists $ent->{r_ele};
	    my $r_ele = $ent->{r_ele};
	    # r_ele can have several reb, so promote single items to a list
	    my $r_ele_list = (ref($r_ele) eq "HASH") ? [ $r_ele ] : $r_ele;
	    for my $reb_hash (@$r_ele_list) {
		die unless exists $reb_hash->{reb};
		my $reb = $reb_hash->{reb};
		$unusual_more_than_reb += has_more_than_one_key($reb_hash);
		if (has_katakana($reb)) {
		    if (exists $katakana_only_index{$reb}) {
			++$kata_clashes;
		    } else {
			$katakana_only_index{$reb}=undef;
		    }
		} else {	# treat this as hiragana
		    if (exists($hiragana_only_index{$reb})) {
			++$hira_clashes;
		    } else {
			$hiragana_only_index{$reb}=undef;
		    }
		    if (exists $keb_index{$reb}) {
			++$keb_hira_clashes;
		    }
		}
	    }
	}
    }
    print "Clash Summary:" .
	"\n\tClashing k_ele entries:\t$keb_clashes".
	"\n\tClashing katakana entries:\t$kata_clashes".
	"\n\tClashing hiragana entries:\t$hira_clashes".
	"\n\tClashing hiragana <-> k_ele entries:\t$keb_hira_clashes".
	"\n";
    print "There were $unusual_more_than_keb keb entries with unusual keys\n";
    print "There were $unusual_more_than_reb reb entries with unusual keys\n";

    # Above is reporting zero clashes, but I'd better count how many
    # elements are in each hash, just to be sure.
    print "The hiragana/katakana path was followed $hira_kata_paths times\n";
    print "k_ele hash contains " . (0 + keys %keb_index) . " key entries\n";
    print "hiragana hash contains " . (0 + keys %hiragana_only_index) . " key entries\n";
    print "katakana hash contains " . (0 + keys %katakana_only_index) . " key entries\n";

    # OK, profiling revealed an error where I wasn't scanning any
    # r_ele elements. After fixing it:
    #
    #  Testing for uniqueness of keb entries
    #  Clash Summary:
    # 	Clashing k_ele entries:	2881
    # 	Clashing katakana entries:	33
    # 	Clashing hiragana entries:	16
    #  	Clashing hiragana <-> k_ele entries:	0
    #  There were 28067 keb entries with unusual keys
    #  There were 5045 reb entries with unusual keys
    #  The hiragana/katakana path was followed 33220 times
    #  k_ele hash contains 170225 key entries
    #  hiragana hash contains 3496 key entries
    #  katakana hash contains 46375 key entries

    # So the upshot of this is that none of the things are unique
    # apart from the ent_seq numbers. Also, there are elements besides
    # keb/reb within some k_ele/r_ele elements.

}
    
# Based on the above, my primary key obviously has to be the sequence
# number. But that brings a second problem: what to do about senses?
# Since each ent_seq might have zero or more k_ele and one or more
# r_ele, I'll have to do something like:
#
# * not make a primary key, but use a non-unique index instead
# * use separate keb/reb indices? Or just make them implicit
# * leave sorting out what, eg, missing k_ele means to the app
#
# I guess that I could have a "primary sort" field (reb/keb), but it's
# just easier to leave it to the application.

# Next up is "sense". It appears from looking at the files that this
# tag only ever appears once per entry. It can, however, contain
# multiple glosses and these glosses are, in fact, the different
# senses. No, wait. The sense attribute can be a list. I see that
# fields like:
#
# <gloss xml:lang="spa">sencillamente</gloss>
# <gloss>lightly (flavored food, applied makeup)</gloss>
#
# both get converted with the key "content" added under the gloss
# entry. What's interesting in the second example is that the entry I
# looked at (1000360) doesn't have the xml:lang key set in the
# original XML, so there must have been a default language being
# applied automatically during the conversion process.
#
# Backing up a little bit, I think that it's probably better to
# explicitly mark out the position of a particular search string
# within the relevant k_ele or r_ele elements. My reasoning for this
# is that it provides a caller who is searching only on strings with a
# way to know directly that the returned keb or reb is not the most
# common way to spell this word. Maybe this isn't needed (because
# there will probably be a second search on the returned ent_seq) but
# I think it's better to be explicit since it may sometimes save a
# query.
#
# Of course, what about when someone does search for a 2nd-tier k_ele
# or r_ele? It might be worth saving the top tier item along with each
# k_ele or r_ele. I'm thinking that it's like doing a search for 取り
# 引き and being told that it's a version of 取引 (the latter being
# the main entry)
#
# But if I do that, I'm back to the problem of entries with no k_ele.
# It brings up the question, too, of whether it's up to the client to
# decide whether the search string has kanji in it (and thus will
# search on that field) or whether to have a unified search field that
# includes a type, eg:
#
# 1599120 | 取引 | keb | 1 |
# 1599120 | 取り引き | keb | 2 |
# ...
# 1599120 | とりひき | reb | 1 |
#
# This assumes relative comparability of keb and reb fields. That's
# probably not a bad assumption. 
#
# While I'm on the subject of making things explicit, I could also
# count up the number of keb/reb items that a piece of vocab has.
#

# ----------------------------------------------------------------------
#
# A rethink...
#
# I'm thinking of doing the bare minimum as far as converting this
# file into a database. I will have one table that has the individual
# YAML entry corresponding to an ent_seq. The rest will simply be one
# or more tables provided specifically for indexing.
#
# There's one slight problem with using YAML::XS to write directly to
# the database, and that's that I will have to manually set the utf8
# encoding flag on the string before putting it into the database. I
# may also have to quote the value before putting it into the
# database, unless I use a blob object type.
#
# In fact, rather than reading in the full YAML file, I could always
# read it in as a text file. In fact, I think I'll to do that in
# jmdict_yaml_to_sql.pl right now.

