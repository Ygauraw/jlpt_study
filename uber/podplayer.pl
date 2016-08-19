#!/usr/bin/perl

#
# Interface for playing podcasts from JapanesePod101
#
# Initially, this will play local files that I've downloaded and
# collated, but later I will may add external URL capability.
#



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
		    debug => 1,
		    track_delay_ms => 600,
		    auto_play      => 1,
		    auto_advance   => 0,
		    uri_base       => 'file:///home/dec/jpod/tmp/',
		    playlist       => ['Newbie/05_New_Year_Greetings/0_NB5_010107_jpod101_review.mp3'],
		    user_controls  => 1, # HTML5 play/pause/transport ui
		    allow_file_uri => 0,
		    loop => 0,
		),
		Gtk2::Ex::FormFactory::Button->new(
		    label => 'Play',
		    clicked_hook => sub { $ap_object->play; },
		),		
		Gtk2::Ex::FormFactory::Button->new(
		    label => 'Pause',
		    clicked_hook => sub { $ap_object->pause; },
		),
		Gtk2::Ex::FormFactory::Button->new(
		    label => 'Set Text',
		    clicked_hook => sub { $ap_object->set_text("Set Text"); },
		),
		Gtk2::Ex::FormFactory::Button->new(
		    label => 'Reload Program',
		    clicked_hook => sub { exec $0, @ARGV or die },
		),
	    ],
	),
    ],
    );

$ff->open;
$ff->update; 

#$ap_object->set_text("A different text");

print "AudioPlayer object's name is " . $ap_object->get_name . "\n";

Gtk2->main;
