#!/usr/bin/perl

use strict;
use warnings;

use Gtk2 qw/-init/;

use Gtk2::Ex::FormFactory;
use Data::Dump qw(pp);

my $ctx = Gtk2::Ex::FormFactory::Context->new;

my @values = ("foo", "bar", "semprini", "wibble");
my @tv = @values;
my $index = 0;
sub on_click {
    warn "Click " . join ",", @_;
    my $edit_val = shift @tv;
    return unless defined $edit_val;

    # Create a new storage object named after this index
    $ctx->add_object(
	name => "edit_$index",
	object => [$index],	# can't use 0 as an object, apparently
	accessor => sub {
	    warn;
	    my $index  = shift->[0];
	    my $attr   = shift or die; # assume always "value"
	    my $new    = shift || $values[$index];
	    $values[$index] = $new;	    
	} );

    # Now create a top-level window
    my $win = Gtk2::Ex::FormFactory->new (
	context     => $ctx,
	content     => [
	    Gtk2::Ex::FormFactory::Window->new(
	    title => "Editing index $index",
		content => [
		    Gtk2::Ex::FormFactory::Form->new(
			content => [
			    Gtk2::Ex::FormFactory::Entry->new(
				label => "New value for index $index",
				attr  => "edit_$index.value",
				cached => 1,
			    ),
			],
		    ),
		],
	    )
	],
	);
    
    $win->open;
    $win->update;

    ++$index;
}

my $mw = Gtk2::Ex::FormFactory->new (
    context     => $ctx,
    content     => [
	Gtk2::Ex::FormFactory::Window->new(
	    title => "Click button for new window",
	    content => [
		Gtk2::Ex::FormFactory::Button->new(
		    clicked_hook => \&on_click,
		    label => "Click me",
		),
	    ],
	    quit_on_close => 1,
	)
    ],
    );

$mw->open;
$mw->update;

Gtk2->main;

print "List is now: " . pp(@values) . "\n";
