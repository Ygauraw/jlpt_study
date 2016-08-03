#!/usr/bin/perl

use GUI::CoreTestWindow;
use Gtk2 "-init";
my $context = Gtk2::Ex::FormFactory::Context->new;
GUI::CoreTestWindow->new(context => $context)->build;
Gtk2->main;
