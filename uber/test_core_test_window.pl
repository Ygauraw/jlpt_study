#!/usr/bin/perl

use Model::CoreTestQA;

use GUI::CoreTestWindow;

use Gtk2 "-init";


# copypasta from test_core_test_qa
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
    } -> {@ARGV[0]};
} else {
    $id = '1470346273';
}

my $test = Model::CoreTestQA->new(
    creation_id => $id,
    test_rec_id => $id,
    );

die "use no arg or [test|core][2k|6k]_[kanji|sound]\n" unless defined $id;


my $context = Gtk2::Ex::FormFactory::Context->new;
GUI::CoreTestWindow->new(
    context   => $context,
    model_obj => $test,
    reload    => 1,		# add a reload button
    )->build;

Gtk2->main;
