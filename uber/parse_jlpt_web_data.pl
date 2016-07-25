#!/usr/bin/perl

# Take raw HTML files from various websites (see "Sources" below) and
# converts them into YML files for easier processing.

use strict;
use warnings;

use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use YAML::XS qw(Load Dump LoadFile DumpFile);

use constant  {
    HIRA_LO => 0x3041,
    HIRA_HI => 0x3095,
    KATA_LO => 0x30a1,
    KATA_HI => 0x30f9
};

my %ranges= (
    hiragana => [ 0x3041, 0x3095 ],
    katakana => [ 0x30a1, 0x30f9 ],
    roman_hankaku => [ 0xff00, 0xffef ],
);

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

#print "\x{3041}\x{30a1}\n";

# print various character ranges
if (1) {
    my ($low, $high) = @{ $ranges{roman_hankaku} };
    my ($i) = $low;
    while  ($i ++ <= $high) {
	print chr($i);
    } 
}

# quicker alternative to the above
if (1) {
    my ($low, $high) = @{ $ranges{katakana} };
    print map { chr } $low .. $high;
}

my $s = "かきくけこケ毛";
print "Has $s got:\n";
print "hiragana? ", (has_hiragana($s) ? "yes" : "no"), "\n";
print "katakana? ", (has_katakana($s) ? "yes" : "no"), "\n";
print "kanji? ",    (has_kanji($s)    ? "yes" : "no"), "\n";


my ($low, $high) = @{ $ranges{hiragana} };


# Sources
#
# Kanji
# -----
#
# www.jlptstudy.net:
#
# Has N5--N1.
# Includes basic list and details for each kanji:
# * title (class = k_ch, short for "kanji character")
# * id (class = k_id, matches anchor with a bit of text changing)
# * English meaning (class = k_m)
# * Multiple compounds (list starts with class=cmps, compounds with class=cmp):
# ** c_ch: kanji
# ** c_kn: kana
# ** c_tr: English translation
# ** c_ty: Type (part of speech, using English abbreviations)
#
# www.tanos.co.uk:
#
# Has N5--N1.
# Just a list of kanji with:
# * on-yomi
# * kun-yomi
# * English meaning(s)
#
# Tagaini Jisho:
#
# Missing N3 (N3 and N2 combined into N2).
# Just a list of kanji with:
# * on-yomi
# * kun-yomi
# * English meaning(s)
# on/kun yomi are just comma-separated with no tabs to distinguish
#

# Get basic information on kanji in each level

# helper routine to find files

my %source_dirs = (
    tanos => '../tanos',
    jlptstudy => '../jlptstudy.net',
    tagaini => '../tagaini_jlpt',
    );

my %search_types = (
    "kanji_all"  => undef,
    "expressions" => undef,
    "vocab" => undef,
    "grammar" => undef,
    );

sub input_file_name {
    my ($source, $type, $level, @junk) = @_;

    die unless exists($source_dirs{$source});
    my $base_source_dir=$source_dirs{$source};

    die unless exists($search_types{$type});

    # die if $level < 2;
    
#   return undef if $source eq "tagaini" and $level == 3;
    return undef if $type eq "compounds" and $source ne "jlptstudy";
    return undef if $type eq "expressions" and $source ne "jlptstudy";
#    return undef if $type eq "grammar" and ($source ne "jlptstudy" or $source ne "tanos");

    if ($type eq "kanji_all") {
	if ($source eq "tanos") {
	    return "$base_source_dir/N${level}_kanji";
	} elsif ($source eq "jlptstudy") {
	    return "$base_source_dir/JLPT Level N${level} Kanji List_files/" .
		"N${level}_kanji-detail.html";
	} elsif ($source eq "tagaini") {
	    return "$base_source_dir/N${level}_kanji.tsv";
	} else { die }

    } elsif ($type eq "vocab") {
	if ($source eq "jlptstudy") {
	    return "$base_source_dir/JLPT Level N${level} Vocabulary List.html";
	} elsif ($source eq "tanos") {
	    return "$base_source_dir/N${level}_vocab";
	} elsif ($source eq "tagaini") {
	    return "$base_source_dir/N${level}_vocab.tsv";
	} else { die; }

    } elsif ($type eq "grammar") {
	if ($source eq "jlptstudy") {
	    return "$base_source_dir/JLPT Level N${level} Grammar List.html";
	} elsif ($source eq "tanos") {
	    return "$base_source_dir/N${level}_grammar";
	} else { die }
    } else {
	die;
    }
}

# Returns a hashref like:
# { level => jlpt_level,
#   kanji => { kanji_char => [ kanji_info, ... ] }
# }
# kanji_info is another hashref:
# {
#   id    => "ID, when used on source website",
#   on_yomi => [ on_reading, ...], 
#   kun_yomi => [ kun_reading, ... ],
#   other_readings => [ unrecognised_readings ],
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
#
sub jlptstudy_empty_kanji_info {
    { on_yomi => [], kun_yomi => [], other_readings => [],
      on_count => 0, kun_count => 0, reading_count => 0,
      stroke_count => undef, english => undef, vocab => [],
      kanji => undef, # copy of key used to index kanji
    }
}
sub parse_jlptstudy_kanji {
    my $level = shift;
    my $fn = input_file_name("jlptstudy", "kanji_all", $level);

    open FILE, "<:encoding(UTF-8)", $fn 
	or die "Failed to open $fn for reading in UTF8 mode: $!";

    my $kanjidic = {};		# will become kanji => kanji_info hash
    my $toplevel = { level => $level, kanji => $kanjidic };
    
    my $this_kanji = undef;
    my $kanjirec   = undef;
    my $compound   = undef;

    while (<FILE>) {
	last if /^<div class=\"k_ch\"/;
    }

    do {

	if (/^<div class=\"k_ch\"/) {
	    if (defined($this_kanji)) { # store previous kanji record
		# $kanjidic{$this_kanji} = $kanjirec;
		$this_kanji = undef; $kanjirec = undef;
	    }
	    if (/\">(.)<\/div>/) {
		$this_kanji = $1;
		$kanjirec = jlptstudy_empty_kanji_info();
		$kanjirec->{kanji} = $this_kanji;
		$kanjidic->{$this_kanji} = $kanjirec; # store new record now
	    } else {
		die "Failed to match k_ch line";
	    }
	    # not all kanji have stroke info
	    if (/strokes:\s*(\d+)\"/) {
		$kanjirec->{stroke_count} = $1;
	    }
	} elsif (/class=\"k_m\">(.*?)<\/div>/) {
	    $kanjirec->{english} = $1;
	} elsif (/class=\"readings\">(.*?)<\/div>/) {
	    $_ = $1;
	    for my $reading (split /\s*,\s*/) {	    
		if (has_hiragana($reading)) {
		    push @{$kanjirec->{kun_yomi}}, $reading;
		    ++ $kanjirec->{reading_count};
		    ++ $kanjirec->{kun_count};
		} elsif (has_katakana($reading)) {
		    push @{$kanjirec->{on_yomi}}, $reading;
		    ++ $kanjirec->{reading_count};
		    ++ $kanjirec->{on_count};
		} else {
		    warn "Kanji reading $reading doesn't appear to have hiragana/katakana";
		    ++ $kanjirec->{reading_count};
		    push @{$kanjirec->{other_readings}}, $reading;
		}
	    }
	} elsif (/class=\"c_ch\">(.*?)<\/div>/) {
	    $compound = { vocab => $1, kana => undef,
			  english => undef, type => undef };
	    push @{$kanjirec->{vocab}}, $compound; # store new record now
	} elsif (/class=\"c_kn\">(.*?)<\/div>/) {
	    $compound->{kana} = $1;
	} elsif (/class=\"c_tr\">(.*?)<\/div>/) {
	    $compound->{english} = $1;
	} elsif (/class=\"c_ty\">(.*?)<\/div>/) {
	    $compound->{type} = $1;
	} elsif (/^<\/div>/) {
	    $compound = undef;	# forces warnings if compounds listed out of order
	}
    } while ($_=<FILE>);

    close (FILE);
    return $toplevel;
}

## comment out for now (files already made and want to test next bit)
if (1) {
    my $i;
    for $i (2..5) {
	my $jlpt_kanji = parse_jlptstudy_kanji($i);
	DumpFile("./jlpt_n${i}_kanji.yaml", $jlpt_kanji);
    }
}
## jlptstudy.net vocabulary
#
# These appear to be in this order:
# * id (could be useful for looking up his vocab in context page)
# * hiragana/katakana
# * kanji (if any)
# * part of speech
# * English
#
# Not all lines are well-formed. He appears to put in a newline if the
# second field is empty.
#
# Return a reference to a list of hashrefs:
# {
#   id => number,
#   kana => "...",
#   regular => "...",
#   english => "...",
# }

sub parse_jlptstudy_vocab {
    my $level = shift;
    my $fn = input_file_name("jlptstudy", "vocab", $level);

    open FILE, "<:encoding(UTF-8)", $fn 
	or die "Failed to open $fn for reading in UTF8 mode: $!";

    my $toplevel = [ { level => $level } ]; # record with level info
    my $this_vocab = undef;

    while (<FILE>) {
	last if /^<tr id=\"(\d+)\"/;
    }

    do {
	if (/^<tr id=\"(\d+)\"/) {
	    # ID values are useless here (they're just row numbers)
	    # $this_vocab = { id => $1, kana => undef, regular => undef, english => undef };
	    $this_vocab = { kana => undef, regular => undef, english => undef };
	    push @{$toplevel}, $this_vocab;
	} elsif (/^<td class=\"kanji\">(.*)/) {
	    $_ = $1; s/<\/.*>//;
	    if (defined($this_vocab->{kana})) {
		die if defined $this_vocab->{regular};
		$this_vocab->{regular} = $_;
	    } else {
		$this_vocab->{kana} = $_;
	    }
	} elsif (/<td>(.*?)<\/td>/) {
		$this_vocab->{type} = $1;
	} elsif (/<td class=\"eng\">(.*?)<\//) {
		$this_vocab->{english} = $1;
	}
    } while ($_=<FILE>);

    close (FILE);
    return $toplevel;
}

## comment out for now (files already made and want to test next bit)
if (1) {
    my $i;
    for $i (2..5) {
	next if $i == 3;
	my $jlpt_vocab = parse_jlptstudy_vocab($i);
	DumpFile("./jlpt_n${i}_vocab.yaml", $jlpt_vocab);
    }
}

# Grammar lists have:
# * id
# * template
# * example

sub parse_jlptstudy_grammar {
    my $level = shift;
    my $fn = input_file_name("jlptstudy", "grammar", $level);

    open FILE, "<:encoding(UTF-8)", $fn 
	or die "Failed to open $fn for reading in UTF8 mode: $!";

    my $toplevel = [ { level => $level } ]; # record with level info
    my $this_grammar = undef;

    while (<FILE>) {
	last if /^<tr id=\"(\d+)\"/;
    }

    do {
	if (/^<tr id=\"(\d+)\"/) {
	    $this_grammar = { id => $1, template => undef, example => undef };
	    push @{$toplevel}, $this_grammar;
	} elsif (/^<td class=\"engkanji\">(.*)<\/td>/) {
	    $this_grammar->{template} = $1;
	} elsif (/^<td class=\"kanji\">(.*)</) {
	    $this_grammar->{example} = $1;
	}
    } while ($_=<FILE>);

    close (FILE);
    return $toplevel;
}

## comment out for now (files already made and want to test next bit)
if (1) {
    my $i;
    for $i (4..5) {
	next if $i == 3;
	my $jlpt_grammar = parse_jlptstudy_grammar($i);
	DumpFile("./jlpt_n${i}_grammar.yaml", $jlpt_grammar);
    }
}

# Kanji list from tagaini jisho
#
# Has kanji, readings and English in tab-separated file
#
# Readings field contains on- and kun-yomi in one list, separated by
# commas.
#
# Use a similar data structure as for jlptstudy.net
#
sub parse_tagaini_kanji {
    my $level = shift;
    my $fn = input_file_name("tagaini", "kanji_all", $level);

    open FILE, "<:encoding(UTF-8)", $fn 
	or die "Failed to open $fn for reading in UTF8 mode: $!";

    my $kanjidic = {};		# will become kanji => kanji_info hash
    my $toplevel = { level => $level, kanji => $kanjidic };
    my $kanjirec   = undef;
    my ($this_kanji, $readings, $english);

    while (<FILE>) {

	($this_kanji, $readings, $english) = split /\t/;
	$kanjirec = jlptstudy_empty_kanji_info();
	$kanjirec->{kanji} = $this_kanji;
	$kanjidic->{$this_kanji} = $kanjirec; # store new record now

	$kanjirec->{english} = $english;
	$_ = $readings;
	for my $reading (split /\s*,\s*/) {	    
	    if (has_hiragana($reading)) {
		push @{$kanjirec->{kun_yomi}}, $reading;
		++ $kanjirec->{reading_count};
		++ $kanjirec->{kun_count};
	    } elsif (has_katakana($reading)) {
		push @{$kanjirec->{on_yomi}}, $reading;
		++ $kanjirec->{reading_count};
		++ $kanjirec->{on_count};
	    } else {
		warn "Kanji reading $reading doesn't appear to have hiragana/katakana";
		++ $kanjirec->{reading_count};
		push @{$kanjirec->{other_readings}}, $reading;
	    }
	}
    }

    close (FILE);
    return $toplevel;
}

## comment out for now (files already made and want to test next bit)
if (1) {
    my $i;
    for $i (2..5) {
	next if $i == 3;
	my $kanji = parse_tagaini_kanji($i);
	DumpFile("./tagaini_n${i}_kanji.yaml", $kanji);
    }
}

sub parse_tagaini_vocab {
    my $level = shift;
    my $fn = input_file_name("tagaini", "vocab", $level);

    open FILE, "<:encoding(UTF-8)", $fn 
	or die "Failed to open $fn for reading in UTF8 mode: $!";

    my $toplevel = [ { level => $level } ];
    my $this_vocab = {};
    my $kanjirec   = undef;

    my ($written, $readings, $english);

    while (<FILE>) {

	($written, $readings, $english) = split /\t/;
	$this_vocab = { kana => $readings, regular => $written, english => $english };
	push @{$toplevel}, $this_vocab;
    }

    close (FILE);
    return $toplevel;
}

## comment out for now (files already made and want to test next bit)
if (1) {
    my $i;
    for $i (2..5) {
	#	next if $i == 3;  # it appears that we have N3 vocab
	my $vocab = parse_tagaini_vocab($i);
	DumpFile("./tagaini_n${i}_vocab.yaml", $vocab);
    }
}

## Tanos
#
# kanji all appear on a single, long line. Follow the same format as
# for the other two, even though we don't have compounds

sub parse_tanos_kanji {
    my $level = shift;
    my $fn = input_file_name("tanos", "kanji_all", $level);

    open FILE, "<:encoding(UTF-8)", $fn 
	or die "Failed to open $fn for reading in UTF8 mode: $!";

    my $kanjidic = {};		# will become kanji => kanji_info hash
    my $toplevel = { level => $level, kanji => $kanjidic };
    
    my $this_kanji = undef;
    my $kanjirec   = undef;
    my $compound   = undef;

    while (<FILE>) {
	last if /kanjiid=\d+/;
    }

    do {
	goto finish unless s/.*?kanjiid=(\d+)\">//;

	my $id = $1;
	$kanjirec = jlptstudy_empty_kanji_info();
	$kanjirec -> {id} = $id;

	die unless s/^(.)\s*<\/a><\/td><td>\s*//;
	$this_kanji = $1;
	$kanjirec->{kanji} = $this_kanji;
	$kanjidic->{$this_kanji} = $kanjirec; # store new record now
	
	if (s/^<a class.*?>(.*?)<\/a><\/td><td>\s*//) {
	    my $reading = $1;
	    $reading =~ s/^\s*//;
	    $reading =~ s/\s*$//;
	    my @readings = split /\s+/, $reading;
	    $kanjirec->{on_yomi} = [ @readings ];
	    $kanjirec->{on_count} = (@readings + 0);
	    $kanjirec->{reading_count} += (@readings + 0);
	    # warn "on-yomi: $reading\n";
	} elsif (s/^<\/td><td>\s*//) {
	    ;
	} else { die }

	if (s/^<a class.*?>(.*?)<\/a><\/td><td>\s*//) {
	    my $reading = $1;
	    $reading =~ s/^\s*//;
	    $reading =~ s/\s*$//;
	    my @readings = split /\s+/, $reading;
	    $kanjirec->{kun_yomi} = [ @readings ];
	    $kanjirec->{kun_count} = (@readings + 0);
	    $kanjirec->{reading_count} += (@readings + 0);
	} elsif (s/^<\/td><td>\s*//) {
	    ;
	} else { die $_ }

	if (s/^<a class.*?>\s*(.*)<\/a><\/td><\/tr>\s*//) {
	    $kanjirec->{english} = $1;
	} elsif (s/^<\/td><td>\s*//) {
	    warn "Empty English text";
	} else { die }

    } while ($_=<FILE>);

  finish:
    close (FILE);
    return $toplevel;
}

## comment out for now (files already made and want to test next bit)
if (1) {
    my $i;
    for $i (1..5) {
	my $kanji = parse_tanos_kanji($i);
	DumpFile("./tanos_n${i}_kanji.yaml", $kanji);
    }
}

sub strip_a_link {
    local($_) = shift;
    s/^\s*<a .*?>//;
    s/\s*<.*$//;
    $_;
}

sub parse_tanos_vocab {
    my $level = shift;
    my $fn = input_file_name("tanos", "vocab", $level);

    open FILE, "<:encoding(UTF-8)", $fn 
	or die "Failed to open $fn for reading in UTF8 mode: $!";

    my $toplevel = [ { level => $level} ];
    my $id;
    my $record   = undef;

    while (<FILE>) {
	last if /vocabid=\d+/;
    }

    do {
	/vocabid=(\d+)/;
	my $id = $1;
	goto finish unless s/.*?<tr>//;

	my $field = undef;
	$record = {id => $id, kana => undef, regular => undef, english => undef };
	push @{$toplevel}, $record;

#	warn "---\n$_";

	die "regular: $_" unless s/<td>(.*?)<\/td>\s*//;
	$record->{regular} = strip_a_link($1);

#	warn "got regular $record->{regular}\n";
#	
	die "$. kana: $_" unless s/<td>(.*?)<\/td>\s*//;
	$record->{kana} = strip_a_link($1);

#	warn "got kana $record->{kana}\n";
	
	die "english: $_" unless s/<td>(.*?)<\/td>\s*//;
#	warn "$1:$_";
	$record->{english} = strip_a_link($1);

    } while ($_=<FILE>);

  finish:
    close (FILE);
    return $toplevel;
}

## comment out for now (files already made and want to test next bit)
if (1) {
    my $i;
    for $i (1..5) {
	my $vocab = parse_tanos_vocab($i);
	DumpFile("./tanos_n${i}_vocab.yaml", $vocab);
    }
}

# last one: Tanos grammar
#
sub parse_tanos_grammar {
    my $level = shift;
    my $fn = input_file_name("tanos", "grammar", $level);

    open FILE, "<:encoding(UTF-8)", $fn 
	or die "Failed to open $fn for reading in UTF8 mode: $!";

    my $toplevel = [ { level => $level} ];

    while (<FILE>) {
	if (/grammarid=(\d+)\">\s*(.*?)<\/a>/) {
	    push @{$toplevel}, { id => $1, grammar => $2 };
	}
    }

    close (FILE);
    return $toplevel;
}

## comment out for now (files already made and want to test next bit)
if (1) {
    my $i;
    for $i (1..5) {
	my $grammar = parse_tanos_grammar($i);
	DumpFile("./tanos_n${i}_grammar.yaml", $grammar);
    }
}
    
    
## Final thing: pull in my RTK flashcards
if (1) {

    open FILE, "<:encoding(UTF-8)", "../koohii/rtk_flashcards_2200.csv"
	or die "Failed to open RTK file for reading in UTF8 mode: $!";

    my ($frame, $kanji, $keyword);
    my $toplevel = { by_frame => [ { frame => 0, keyword => undef, kanji => undef } ],
		     by_kanji => {},
		     by_keyword => {},
    };

    while (<FILE>) {
	next if /^Frame/;
	die unless s/^(\d+),//;     $frame   = $1;
	die unless s/^\"(.*?)\",//; $kanji   = $1;
	die unless s/^\"(.*?)\",//; $keyword = $1;

	# YAML supports self-referential structures ... handy
	my $rec = { frame => $frame, keyword => $keyword, kanji => $kanji };
	push @{$toplevel->{by_frame}}, $rec;
	$toplevel->{by_keyword}->{$keyword} = $rec;
	$toplevel->{by_kanji}->{$kanji} = $rec;
    }

    DumpFile("./rtk_kanji.yaml", $toplevel);

}
