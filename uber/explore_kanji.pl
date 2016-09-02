#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use Model::KanjiReadings;
use Model::Learnable;

use Gtk2 qw(-init);
use Gtk2::Ex::FormFactory;
use GUI::KanjiExplorer;

binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";

GUI::KanjiExplorer->new->build_window;

Gtk2->main;

# package for kanji window

package GUI::KanjiDetails;

sub new {
    my $class = shift;
    my %opts = (
	context => undef,
	kanji   => undef,
	toplevel => 0,
	@_,
    );

    my $kanji   = $opts{kanji}   or die "KanjiWindow needs kanji => char option\n";
    my $context = $opts{context} or die "KanjiWindow needs context => ref option\n";

    my $self = bless { context => $context, kanji => $kanji,
		       toplevel => $opts{toplevel},
		       _kanji => KanjiReadings::Kanji->retrieve($kanji) };

    # GUI-related 
    $context->add_object(
	name => "gui_kanji_$kanji",
	object => $self,
	attr_depends_href => {
	    x => "y",
	}
    );

    $self->build_window;
    $self->{ff}->open;
    $self->{ff}->update_all;

    return $self;
}

sub build_window {

    my $self = shift;
    my $context = $self->{context};

    my $ff = Gtk2::Ex::FormFactory::Window->new(
	label => "Editing Kanji . $self->{kanji}",
	context => $context,
	content => [
	    
	]
	)

}

# package for vocab window

package GUI::VocabDetails;

1;
