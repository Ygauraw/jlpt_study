#!/usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(DumpFile);
use File::Slurp;

use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $story_file = "my_stories.csv";
my $flash_file = "rtk_flashcards_2200.csv";

my @story_lines = read_file($story_file, binmode => ':utf8');
my @flash_lines = read_file($flash_file, binmode => ':utf8');

# This program will basically just do a join on the two files,
# throwing an error if there's any inconsistency (eg, differing
# kanji/keywords for the same frame number). I'll also create some
# indexes.
sub empty_entry {
    my $frame_num = shift;
    {
	frame_num    => $frame_num,
	kanji        => undef,
	keyword      => undef,
	keyword_def  => undef,	# "default", unaltered keyword
	last_review  => undef,
	expire_date  => undef,
	leitner_box  => undef,
	fail_count   => undef,
	pass_count   => undef,
	# from story file (just store a single story)
	story_date   => undef,
	story_pub    => undef,
	story        => undef,
    }
}
my $null_entry = empty_entry(undef);
my $dict = {
    meta => {
	file_times => {
	    # all files in epoch seconds time
	    stories    => ((stat $story_file)[9]),
	    flashcards => ((stat $flash_file)[9]),
	    yaml_time  => time(),
	},
	# count of entries assumes no custom selection/gaps
	entries    => @flash_lines - 1,
    },
    frame_index => [ $null_entry ], # indices count from 1
    kanji_index => { },
    keyword_index => { },
};

# flashcard file is easy
shift @flash_lines;
my $frame_index = 1;
foreach my $flash (@flash_lines) {
    $flash =~ s/[\r\l\n]*$//;
    my @fields = split(/"?,"?/, $flash);
    die $flash unless 8 == @fields;
    my $frame_num = $fields[0];
    die unless $frame_num == $frame_index;
    my $ent = empty_entry($frame_num);

    $ent->{kanji}       = $fields[1];
    $ent->{keyword}     = $fields[2];
    $ent->{last_review} = $fields[3];
    $ent->{expire_date} = $fields[4];
    $ent->{leitner_box} = $fields[5] + 0;
    $ent->{fail_count}  = $fields[6] + 0;
    $ent->{pass_count}  = $fields[7] + 0;

    # register in dict
    push @{$dict->{frame_index}}, $ent;
    $dict->{kanji_index}->{$ent->{kanji}} = $ent;
    die if exists $dict->{keyword_index}->{$ent->{keyword}};
    $dict->{keyword_index}->{$ent->{keyword}} = $ent;
    
    last if ++$frame_index > 6e6; # use lower num for testing
}

# check that above gives desired output
DumpFile("tmp.yaml", $dict) if(0);

# Story file is a bit more complicated than kanji file because of
# possibility of embedded newlines. There are libraries for reading in
# these files but it's easier just to write my own code here.

shift @story_lines;
my @joined_story_lines = ();

while (my $line = shift @story_lines) {
    my $ent;
    $line =~ s/[\r\l\n]*$//;

    # probably better to iterate over fields first
    die $line unless $line =~ /^(\d+),(.),"(.*?)",(\d),(.*?),(.*)$/;
    my @fields = ($1,$2,$3,$4,$5,$6);

    if (1 & ($line =~ tr|"|"|)) { # odd number of " chars?
	do {
	    $line = shift @story_lines or die;
	    $line =~ s/[\r\l\n]*$//;
	    $fields[5] .= "\n$line";
	} until (1 & ($line =~ tr|"|"|)); # until another odd line
	die unless ($fields[5] =~ s/"$//);
    }

    $fields[5] =~ tr|"|"|s;
    $fields[5] =~ s/^"(.*)"/$1/;
    
    die unless exists($dict->{keyword_index}->{$fields[2]});
    die unless exists($dict->{kanji_index}->{$fields[1]});
    $ent = $dict->{kanji_index}->{$fields[1]};
    die unless $ent->{frame_num} == $fields[0];
    die unless $ent->{kanji}     eq $fields[1];

    $ent->{story_pub}  = $fields[3] + 0;
    $ent->{story_date} = $fields[4];
    $ent->{story}      = $fields[5];
    
}    

DumpFile("rtk_dict.yaml", $dict);
