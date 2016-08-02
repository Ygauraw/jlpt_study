#!/usr/bin/perl

use strict;
use warnings;

use Gtk2 qw/-init/;

use Gtk2::Ex::FormFactory;

# This is the new widget class
use FormFactory::AudioPlayer;

my $context = Gtk2::Ex::FormFactory::Context->new;
my $ap_object;

my $ff = Gtk2::Ex::FormFactory->new(
    context => $context,
    content => [
	Gtk2::Ex::FormFactory::Window->new(
	    title => 'Test wrapping of audio widget',
	    height => 400,
	    width  => 400,
	    quit_on_close => 1,
	    content => [
		$ap_object = Gtk2::Ex::FormFactory::AudioPlayer->new(
		    track_delay_ms => 600,
		    auto_play      => 1,
		    auto_advance   => 1,
		    uri_base       => 'file:///home/dec/JLPT_Study/',
		    playlist       => ['JW03182A.mp3','2lck24b1d1lv4.mp3'],
		    allow_file_uri => 0,
		    loop => 1,
		),
	    ],
	),
    ],
    );

$ff->open;
$ff->update; 

print "AudioPlayer object's name is " . $ap_object->get_name . "\n";

Gtk2->main;
