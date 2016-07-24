#!/usr/bin/perl

# Based on similar code for JMdict XML/YAML file

use strict;
use warnings;

use YAML::XS qw(LoadFile);
use Data::Dumper;
use Data::Dump qw(dump dumpf);

use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
binmode STDIN,  ":utf8";

$| = 1;
print "Loading database: ";
my $dict = LoadFile("kanjidic2.yaml");
print "done\n";

sub delete_non_eng_info {
    my $ent = shift;
    my $meanings;
    
    die unless exists($ent->{reading_meaning}->{rmgroup}->{meaning});
    die unless exists($ent->{reading_meaning}->{rmgroup}->{reading});

    my $meaning_list = $ent->{reading_meaning}->{rmgroup}->{meaning};
    $meaning_list = [ $meaning_list] unless ref($meaning_list) eq "ARRAY";
    my $reading_list = $ent->{reading_meaning}->{rmgroup}->{reading};
    $reading_list = [ $reading_list] unless ref($reading_list) eq "ARRAY";

    my $replacement_meaning_list = [];
    for my $meaning (@$meaning_list) {
	if (ref($meaning) eq "") {
	    push @$replacement_meaning_list, $meaning;
	    next;
	} elsif (ref($meaning) eq "HASH") {
	    ;
	} else {
	    die "Got ref of $meaning: " . ref($meaning);
	}
    }
    # demote list in the case of there only being a single item
    $replacement_meaning_list = $replacement_meaning_list->[0] 
	if @$replacement_meaning_list == 1;
    $ent->{reading_meaning}->{rmgroup}->{meaning}=$replacement_meaning_list;
    my $replacement_reading_list = [];
    for my $reading (@$reading_list) {
	if (ref($reading) eq "") {
	    die;
	} elsif (ref($reading) eq "HASH") {
	    my $reading_lang = $reading->{r_type} or die;
	    if ($reading_lang =~ /^ja_/) {
		push @$replacement_reading_list, $reading;
	    }
	} else {
	    die
	}
    }
    # demote list in the case of there only being a single item
    $replacement_reading_list = $replacement_reading_list->[0] 
	if @$replacement_reading_list == 1;
    $ent->{reading_meaning}->{rmgroup}->{reading}=$replacement_reading_list;
}

# Data::Dump is great, but it converts strings to Unicode escapes and
# is overly-verbose.
sub filter_dumped {
    my ($ctx, $object_ref) = @_;
    if ($ctx->is_scalar) {
	return { dump => "'" . $$object_ref . "'" }; # needs $$!
    } elsif($ctx->is_hash) {
	return { hide_keys => ['xml:lang'] };
    } else {
	return undef;
    }
    return undef;
}

# Build an index of kanji to containing entities
my %literal_to_ent_index = ();
my $ent_list = $dict->{character} or die;
foreach my $ent (@$ent_list) {
    my $key = $ent->{literal} or die;
    die if exists $literal_to_ent_index{$key};
    $literal_to_ent_index{$key} = $ent;
}



my $ent;
while (my $line = <STDIN>) {

    chomp $line;
    
    next unless $line =~ s/^\s*(\S).*/$1/;

    unless (exists($literal_to_ent_index{$line})) {
	warn "No entry $line\n";
	next;
    }

    $ent = $literal_to_ent_index{$line};
    delete_non_eng_info($ent);
    
    #print Dumper($ent);
    print dumpf($ent, \&filter_dumped);
    print "\n";
}
