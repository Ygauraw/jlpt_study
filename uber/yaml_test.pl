#!/usr/bin/perl

use strict;
use warnings;

use utf8;			# for UTF-8 literal strings in this code

use Encode qw(encode decode);

binmode STDOUT, ':utf8';	# Get rid of "Wide character in printf" messages
#binmode STDOUT, ':raw';        # needed to print YAML::XS output
use YAML::XS qw(Load Dump LoadFile DumpFile);

my @uni_array = (
    {
	keyword => "trifle",
	kanji => "僅",
    },
    {
	keyword => "me",
	kanji => "僕",	    
    }
    );

sub print_array {
    my $aref = shift;
    my ($keyword, $kanji);
    printf("%-20s %s\n", "Keyword", "Kanji");
    foreach my $hashref (@$aref) {
	($keyword, $kanji) = ($hashref->{"keyword"},$hashref->{"kanji"});
	printf("%-20s %s\n", $keyword, $kanji);
    }
}

print_array(\@uni_array);

check_array(\@uni_array);

my $dumped = Dump(\@uni_array);

print "YAML Dump:\n$dumped\n";

sub check_array {
    my $aref = shift;
    my ($keyword, $kanji);
    foreach my $hashref (@$aref) {
	print "String contents '$hashref->{kanji}' is ", 
	(utf8::is_utf8($hashref->{kanji}) ? "on" : "off"), "\n";
	$kanji = $hashref->{"kanji"};
	print "Kanji string '$kanji' is ", 
	(utf8::is_utf8($kanji) ? "on" : "off"), "\n";
    }
}

print "Dumped string has utf8 flag ", 
	(utf8::is_utf8($dumped) ? "on" : "off"), "\n";

# If I explicitly turn the UTF8 flag on, then Load fails below

#Encode::_utf8_on($dumped);
#
#print "Turned utf8 flag on\n";
#print "YAML Dump:\n$dumped\n";

my ($loadref) = (Load($dumped));
print "Reloaded dumped data. Contents:\n";
print_array($loadref);

# now do things via a file
DumpFile('./.temp.yaml', \@uni_array) or die "Failed to dump?";
$loadref=undef;
$loadref=LoadFile('./.temp.yaml');

print "Contents of re-loaded file:\n";
print_array($loadref);

# Moral of the story:
#
# When binmode utf8 is in play on stdout, we get double-encoding of
# strings coming out of YAML::XS::Dump. Everything works fine if we
# use the DumpFile and LoadFile routines: data is stored correctly in
# the output file in utf-8 and the re-loaded data is intact.
#
# The only reason to set the utf8 flag on the dumped data string is to
# make it print correctly on an output file that's in utf8 (ie,
# prevents double-encoding). If you do that, you have to turn the flag
# off again if you want to reload that same string.
#
# A better alternative to using _utf8_on is to set the mode of stdout
# to ":raw" for the duration of printing the YAML string. Or just use
# YAML instead of YAML::XS

check_array($loadref);
