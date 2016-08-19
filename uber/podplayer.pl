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
use FormFactory::AudioPlayer;

# Main program just creates the context and a top-level GUI object

my $context = Gtk2::Ex::FormFactory::Context->new;

my $player_window = GUI::PlayerWindow->new(
    context  => $context,
    filename => 'Newbie/05_New_Year_Greetings/0_NB5_010107_jpod101_review.mp3',
    toplevel => 1,
);

Gtk2->main;

exit 0;

package GUI::Base;

# Small package that all other GUI objects will derive from. Its
# purpose is to provide handling/stashing of common parameters such as
# Context.

sub new {
    my $class = shift;
    my %opt = ( context => 0, toplevel => 0, @_ );
    my ($context)  = $opt{context};
    my ($toplevel) = $opt{toplevel};

    die "Objects deriving from GUI::Base must have context => ... \n"
	unless $context;
    
    return bless {
	context  => $context,
	toplevel => $toplevel,
    }, $class;
}

sub get_context { shift->{context} }
sub set_context { shift->{context} = $_[1] }
sub get_ff { shift->{ff} }
sub set_ff { shift->{ff} = $_[1] }

# Don't know if I'll need this:
sub get_context_object { $_[0]->{context}->get_object($_[1]) }

# Generic message for missing methods in subclasses
our $AUTOLOAD;
sub AUTOLOAD {
    my $class  = shift;
    my $method = $AUTOLOAD;
    die "Class $class does not define a method $method()\n";
};


package GUI::PlayerWindow;

use base 'GUI::Base';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %opts  = (
	filename => undef,
	uri_base => 'file:///home/dec/jpod/',
	debug_audio => 0,
	@_
    );
    my ($filename, $toplevel, $uri_base, $debug_audio) = 
	@opts{qw/filename toplevel uri_base debug_audio/};

    unless (defined $filename) {
	warn "GUI::PlayerWindow needs a filename option\n";
	return undef;
    }
    $self->{filename} = $filename;
    $self->{uri_base} = $uri_base;
    $self->{debug_audio} = $debug_audio;

    $self->build;
    $self->{ff}->open;
    $self->{ff}->update;
    $self;
}

sub build {
    my $self = shift;
    $self->{ff} = my $ff = Gtk2::Ex::FormFactory->new(
	context => $self->get_context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new(
		title => 'Podcast Player',
		height => 400,
		width  => 400,
		quit_on_close => $self->{toplevel},
		content => [
		    $self->player_widgets(),
		],
	    ),
	],
    );
}

sub player_widgets {
    my $self = shift;
    (
     ($self->{ap_object} =
     Gtk2::Ex::FormFactory::AudioPlayer->new(
	 debug          => $self->{debug_audio},
	 track_delay_ms => 600,
	 auto_advance   => 0,
	 play_state     => "play",
	 uri_base       => $self->{uri_base},
	 playlist       => [$self->{filename}],
	 user_controls  => 1, # HTML5 play/pause/transport ui
     )),
     Gtk2::Ex::FormFactory::Button->new(
	 label => 'Play',
	 clicked_hook => sub { $self->{ap_object}->play; },
     ),		
     Gtk2::Ex::FormFactory::Button->new(
	 label => 'Pause',
	 clicked_hook => sub { $self->{ap_object}->pause; },
     ),
     Gtk2::Ex::FormFactory::Button->new(
	 label => 'Reload Program',
	 clicked_hook => sub { exec $0, @ARGV or die },
     ),
    )
};
