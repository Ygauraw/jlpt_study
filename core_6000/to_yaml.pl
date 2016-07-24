#!/usr/bin/perl

use strict;
use warnings;

use JSON;
use YAML::XS qw(LoadFile DumpFile);
use File::Slurp;

my ($text, $decoded);
for my $file (<*json>) {
    print "$file: ";
    $text = read_file($file) or die "Not OK";
    print "read OK\n";

    my $to_file = $file;
    $to_file =~ s/json$/yaml/i;
    
    $decoded = decode_json $text;
    DumpFile($to_file, $decoded);
    
}
