#!/usr/bin/perl                       --  -*- Perl -*-

#use strict;
use warnings;
use utf8;

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Data::Dump qw(dump dumpf);


sub filter_dumped {
    my ($ctx, $object_ref) = @_;
    warn "got '$object_ref', which is a " . $ctx->reftype . "\n";
#    if ($ctx->is_scalar) {
    if ($ctx->reftype eq "SCALAR") {
        return { dump => "'" . $$object_ref . "'" }; # needs $$!
    } elsif($ctx->is_hash) {
	# make a copy of the hash
	my $copy = [ %$object_ref ];
	foreach (@$copy) {
	    warn $_;
	    $_ = "'" . $_ . "'";
	} 
        return { object => $copy };
    } else {
        return undef;
    }
    return undef;
}

# OK, apparently there's no way to override the dump behaviour of
# converting unicode in keys into escaped form ... 
dumpf({'行く' => "来る"}, \&filter_dumped);
