#!/usr/bin/perl


use Gtk2 qw/-init/;

use Gtk2::Ex::FormFactory;

use utf8;

my $ctx = Gtk2::Ex::FormFactory::Context->new;

# Try to do a simple UI with one main window that creates several
# different sub-windows

my $ff_main = Gtk2::Ex::FormFactory->new (
    context => $context,
    content => [
	Gtk2::Ex::FormFactory::Window->new(
	    title => "test",
	content => [
	    Gtk2::Ex::FormFactory::VBox->new(
		content => [
		    Gtk2::Ex::FormFactory::Button->new(
			label => "List 1",
		    ),
		    Gtk2::Ex::FormFactory::Button->new(
			label => "List 2",
		    )
		],
	    )
	    ]
	),
    ],
);


my $ff = Gtk2::Ex::FormFactory->new (
    context => $context,
    content => [
		
    ]
);

$ff_main->open;    # actually build the GUI and open the window
print "got here\n";
$ff_main->update;  # fill in the values from $config_object

Gtk2->main;
