#!/usr/bin/perl


use Gtk2 qw/-init/;

use Gtk2::Ex::FormFactory;

use utf8;

my $ctx = Gtk2::Ex::FormFactory::Context->new;

# Try to build a scrollable list of vocab items with a check field
# associated with each one

# Idea #1: sub-class from Widget

# Idea #2: use FF to create a composite widget and reuse it?

# Thinking about the life-cycle of these objects. We'll have a search
# box or something that's linked to the display box. When the search
# is carried out, it will tell the container to delete all sub-widgets
# first, and then it will populate it with new stuff.
#
# When the button associated with the vocab entry is toggled, it may
# update a data structure immediately or maybe we have to click on
# something to "add selected". 

package Gtk2::Ex::FormFactory::MyTest;
use strict;

use base qw( Gtk2::Ex::FormFactory::Widget );






package main;

$ff->open;    # actually build the GUI and open the window
print "got here\n";
$ff->update;  # fill in the values from $config_object

Gtk2->main;
