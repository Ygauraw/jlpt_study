#!/usr/bin/perl

use strict;
use warnings;

use Model::CoreTestQA;

use Util::RNG;

use Data::Dump qw(pp dumpf);
my $id = undef;
if (@ARGV) {
    # some tests I prepared in the db of the appropriate types:
    $id = {
	"test2k_kanji" => '1470346273',
	"test6k_kanji" => '1470346275',
	"core2k_kanji" => '1470346277',
	"core6k_kanji" => '1470346280',
	"test2k_sound" => '1470346284',
	"test6k_sound" => '1470346286',
	"core2k_sound" => '1470346288',
	"core6k_sound" => '1470346290',
    } -> {shift @ARGV};
} else {
    $id = '1470346273';
}

die "use no arg or [test|core][2k|6k]_[kanji|sound]\n" unless defined $id;

my $rng = Util::RNG->new;
print ref ($rng) . "\n";

my $test = Model::CoreTestQA->new(
    creation_id => $id,
    test_rec_id => $id,
    );

pp $test;
