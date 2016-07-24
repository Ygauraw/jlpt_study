#!/usr/bin/perl

use strict;
use warnings;

use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use YAML::XS qw(DumpFile);

# Try again, this time using the -layout option to pdftotext...

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

open FILE, "<:encoding(UTF-8)", "./Japanese_Core_2000.txt"
	or die "Failed to open file for reading in UTF8 mode: $!";

while (<FILE>) { last if /^\s*#(\d+)/ };

my $entry = "0001";
my $new_entry;
my @stanza = ();
my @entries = ();

sub parse_stanza {
    my $entry = shift;
    my ($line, $rec, $this_space, $min_space);

    # get rid of blank lines and page numbers at end of pages
    while ($line = pop @stanza) {
	unless ($line =~ /^\s*(\d*)\s*$/) {
	    push @stanza, $line;
	    last;
	}
    }

    # assume ruby only occupies one line
    $line = shift @stanza;
    $line =~ s/^(\s*)(\.*)\s*$/$2/;
    #    $min_space = strlen($1);
    $rec = { id => $entry, ruby => $line };

    $line = shift @stanza;
    $line =~ m|^\s+(.*)\s\s(.*)\s*$|;
    my ($ja_vocab, $ja_sentence) = ($1, $2);
    $ja_vocab =~ s/\s*$//;
    
    # possibly split up ja_vocab into ja_kana and ja_regular (katakana
    # just appears without a gloss)
    my ($ja_kana, $ja_regular);
    if ($ja_vocab =~ /\s*(.*)\s【(.*)】/) {
	($ja_kana, $ja_regular) = ($1, $2);
    } else {
	($ja_kana, $ja_regular) = ($ja_vocab, $ja_vocab);
    }
    die if $ja_regular eq "";
    
    #warn "$ja_regular ($ja_kana): $ja_sentence";
    $rec->{ja_regular}  = $ja_regular;
    $rec->{ja_kana}     = $ja_kana;
    $rec->{ja_sentence} = $ja_sentence;

    # en "keywords/indices" and sentence translations can be
    # complicated by going over several lines. The second and
    # subsequent lines seem to be vertically aligned.
    $line = shift @stanza;
    $line =~ m|^(\s+)(.*?)(\s\s+)(.*)|;
    my ($col1, $col2, $en_index, $en_sentence) = 
	( length ("$1"), length ("$1$2$3"), $2, $4 );
    #warn "$en_index // $en_sentence\n";

    # handle continuations, which must align (check if they don't)
    while ($line = shift @stanza) {
	chomp $line;
	my ($cont1, $cont2) = ("","");
	my $trimmed = "";
	if (length $line > $col2)
	{
	    $cont2=(substr $line, $col2);
	    (substr $line, $col2) = "";
	    #warn $line
	}
	#warn "$col2: $cont2";
	die $cont2 if $cont2 =~ /^\s+/;
	$trimmed = substr $line, 0, $col1;
	$cont1 = substr $line, $col1;
	$cont1 =~ s/\s+/ /g;
	(substr $line, 0, $col1) = "";
	die "gutter $trimmed" unless $trimmed =~ /^\s+$/;
	die "col1 [$line]" if $line =~ /^\s+\S/;
	
	if ($cont1) {
	    unless ($en_index =~ s/-$/$cont1/) {
		$en_index.=" $cont1";
	    }
	}
	if ($cont2) {
	    unless ($en_sentence =~ s/-$/$cont2/) {
		$en_sentence.=" $cont2";
	    }
	}
    }
    #warn "$en_index // $en_sentence\n";

    $rec->{en_index} = $en_index;
    $rec->{en_sentence} = $en_sentence;

    push @entries, $rec;
    
}

while (<FILE>) {

    if (/^\s*#(\d+)/) {
	$new_entry="$1";
	if ($entry ne $new_entry) {
	    parse_stanza($entry);
	    $entry = $new_entry;
	    @stanza = ();
	}
    } else {
	push @stanza, $_;
    }

} 

for (1..7) { pop @stanza; }
parse_stanza($entry);

close(FILE);

DumpFile ("core-2000.yaml", \@entries);
