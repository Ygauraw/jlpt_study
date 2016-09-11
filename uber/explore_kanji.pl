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

