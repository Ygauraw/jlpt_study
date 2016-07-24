#!/usr/bin/perl

package main;

use strict;
use warnings;

# This will be a GTK app to do statistical testing of the Core
# vocabulary databases

sub find_95pc_error_margin {
    my $p = shift;
    my $n = shift;

    return 1.96 * sqrt (((1.0 - $p) * $p) / $n);
}

use Gtk2 qw/-init/;
use Gtk2::Ex::FormFactory;

my $context = Gtk2::Ex::FormFactory::Context->new;

# example of adding a basic variable backed by an object/package
#$context->add_object( name   => "worksheet",
#		      object => $worksheet);

my $answer = Gtk2::Ex::FormFactory::Table->new(
    layout => "+------------+--------------+
               |   l1       |     l2       |
               +------------+--------------+
               | JA_Vocab   | JA_Sentence  |
               +------------+--------------+
               |   l3       |     l4       |
               +------------+--------------+
               | EN_Meaning | EN_Sentence  |
               +------------%--------------+
               |         Buttons           |
               +---------------------------+",
    content => [
	Gtk2::Label->new("Vocab"),
	Gtk2::Label->new("Sentence"),
    ]
);	

my $ff = Gtk2::Ex::FormFactory -> new(
    context => $context,
    content => [
	Gtk2::Ex::FormFactory::Window->new(
	    title   => "Testing Core 2k",
	    quit_on_close => 1,
	    width => 600,
	    height => 400,
	    expand => 1,
	),
    ],
    );


    

$ff->open;    # actually build the GUI and open the window
$ff->update;  # fill in the values from $config_object

Gtk2->main;

## Shamelessly copied from DVDrip
#package GUI;
no strict "subs";
package GUI::Base;

sub get_context                 { shift->{context}                      }
sub set_context                 { shift->{context}              = $_[1] }

sub get_form_factory            { shift->{form_factory}                 }
sub set_form_factory            { shift->{form_factory}         = $_[1] }

sub get_context_object          { $_[0]->{context}->get_object($_[1])   }

sub new {
    my $class = shift;
    my %par   = @_;
    my ( $form_factory, $context ) = @par{ 'form_factory', 'context' };

    $context ||= $form_factory->get_context if $form_factory;

    my $self = bless {
        form_factory => $form_factory,
        context      => $context,
    }, $class;

    return $self;
}

package GUI::Answer;

use base GUI::Base;

sub new {

    my $self = SUPER::new(@_);

    return $self;

}
