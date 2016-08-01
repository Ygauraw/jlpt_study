#!/usr/bin/perl

use strict;
use warnings;

use Gtk2 qw/-init/;

use Gtk2::Ex::FormFactory;

require 'ff-audio.pm';

my $context = Gtk2::Ex::FormFactory::Context->new;

my $ff = Gtk2::Ex::FormFactory->new(
    context => $context,
    content => [
	Gtk2::Ex::FormFactory::Window->new(
	    title => 'Test wrapping of audio widget',
	    height => 400,
	    width  => 400,
	    quit_on_close => 1,
	    content => [
		Gtk2::Ex::FormFactory::AudioPlayer->new(
		    track_delay_ms => 600,
		    auto_play      => 1,
		    uri_base       => 'file:///home/dec/JLPT_Study/',
		    playlist       => ['JW03182A.mp3'],
		    allow_file_uri => 1,
		),
	    ],
	),
    ],
    );

$ff->open;
$ff->update; 

Gtk2->main;
