#!/usr/bin/perl

use strict;
use warnings;

use LWP::Simple;

use YAML::XS qw(LoadFile);
use File::Slurp;
use File::Path qw(make_path);

my $check_local = 1;
my $turn = 0;

for my $file (<*.yaml>) {

    my @lines = read_file($file);

    my ($url,$asset_site,$lpath,$lfile,$rc);

    foreach (@lines) {
	chomp;

	next unless s/^.*:\s*(http:\/\/(assets\d+)\.)/$1/;
	$asset_site = $2;
	$url = $_;

	die unless m|iknow\.jp/(.*)/(.*)|;
	($lpath, $lfile) = ($1, $2);

#	die "$asset_site / $_/ $lpath : $lfile";
	make_path("./$asset_site/$lpath");
	if ($check_local) {
	    next if -f "./$asset_site/$lpath/$lfile";
	}
	$rc = mirror ($url, "./$asset_site/$lpath/$lfile");

	next if RC_NOT_MODIFIED == $rc;
	unless (is_success($rc)) {
	    print "Failed downloading $url\n";
	    print "Mirror error code was " . HTTP::Status::status_message($rc) . "\n";
	    die
	}
	sleep(1) unless $turn & 3; 
	++$turn; 
    }
}
