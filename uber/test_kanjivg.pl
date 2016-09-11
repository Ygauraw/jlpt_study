#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Gtk2 qw/-init/;

use Gtk2::Ex::FormFactory;
use GUI::KanjiDetails;

my $context = Gtk2::Ex::FormFactory::Context->new;

#$context->add_object(

my $kanji = '雨';

$kanji = shift if @ARGV;

my $win = GUI::KanjiDetails->new(kanji => $kanji, toplevel => 1, context => $context);

Gtk2->main;
