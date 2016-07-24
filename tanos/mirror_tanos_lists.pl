#!/usr/bin/perl

use strict;
use warnings;

use LWP::Simple;
use HTTP::Status qw(:constants :is status_message);


my @levels=(1..5);
my @areas=qw(vocab kanji grammar);

sub make_url {
    my ($level, $area, @junk) = @_;
    return "http://tanos.co.uk/jlpt/jlpt$level/$area";
}

my %urls;			# map urls to files
for my $l (@levels) {
    for my $a (@areas) { 
	$urls{make_url($l,$a)} = "N${l}_$a";
    } };

for my $url (keys %urls) {
    my $file = $urls{$url};
    printf ("%-12s %-40s\n", $file, $url);
}


for my $url (keys %urls) {
    my $file = $urls{$url};
    my $rc;
    printf ("%-12s %-40s ", $file, $url);
    $rc = mirror($url, $file);
    if (is_success($rc)) {
	print "OK: ", status_message($rc), "\n";
    } else {
	print "NOT_OK: ", status_message($rc), "\n";
    }
}
    
    
