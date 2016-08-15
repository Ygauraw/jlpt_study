#!/usr/bin/perl

# Tester for Core 2k/Core 6k vocabulary sets.
#

use strict;
use warnings;
use utf8;

binmode STDOUT, ":utf8";
binmode STDIN,  ":utf8";

use Data::Dump qw(dump dumpf pp);

use Model::CoreVocab;
use Model::CoreTracking;

use Gtk2 qw/-init/;
use Gtk2::Ex::FormFactory;

use GUI::CoreTestList;

my $context = Gtk2::Ex::FormFactory::Context->new;

my $mw = GUI::CoreTestList->new(
    context => $context,
    reload  => 1,
); 
warn "Before build, mw->{buttons} is $mw->{buttons}\n";
$mw->build_main_window;
Gtk2->main;


