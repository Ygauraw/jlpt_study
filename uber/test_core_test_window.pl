#!/usr/bin/perl

use GUI::CoreTestWindow;
use Gtk2 "-init";
GUI::CoreTestWindow->new->build;
Gtk2->main;
