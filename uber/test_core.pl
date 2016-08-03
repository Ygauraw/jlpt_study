#!/usr/bin/perl

# Use a bunch of different libraries to give a test on Core 6k (or 2k)
# vocabulary.
#
# Class::DBI to encapsulate database objects
# Gtk2::Ex::FormFactory to do most GUI stuff
# Gtk2::WebKit for <audio> support
# Net::OnlineCode::RNG for replayable random selections
#

# I happened to have this RNG lying around; I'll use it to generate
# sample tests and save the seed for replaying at a later time.
use Util::RNG;
use Util::Shuffle qw/fisher_yates_shuffle/;

use strict;
use warnings;
use utf8;

binmode STDOUT, ":utf8";
binmode STDIN,  ":utf8";

use Data::Dump qw(dump dumpf pp);

use Model::CoreVocab;
use Model::CoreTracking;

# test out Class::DBI stuff
my $core2k = CoreVocab::Core2k->retrieve(1);

print "First Core2k record:\n" ;
print "  ID: "           . $core2k->id  . "\n";
print "  JA_vocab: "     . $core2k->ja_vocab  . "\n";
print "  JA_kana: "      . $core2k->ja_vocab_kana  . "\n";
print "  EN_vocab: "     . $core2k->en_vocab  . "\n";

# How do I get linked records (ie, has_a relationships)?
# Core2k has a has_a Vocab and Sentence object linked to it

# pp provides some interesting information at this point
#pp $core2k;

print "  Vocab JA_text: "        . $core2k->vocab_id->ja_text  . "\n";
print "  Vocab POS: "            . $core2k->vocab_id->pos  . "\n";
print "  Vocab 2k sequence: "    . $core2k->vocab_id->core_2k_seq  . "\n";
print "  Vocab Vocab Sound ID: " . $core2k->vocab_id->sound_id  . "\n";
print "  Sentence JA: "          . $core2k->main_sentence_id->ja_text  . "\n";

# OK, that tests basic retrieval and retrieval from foreign tables

# The one thing I wasn't sure about in the schema is the relationship
# between the Core6k table and Core6kSentence

my $core6k = CoreVocab::Core6k->retrieve(2);

print "Second Core6k record:\n" ;
print "  ID: "           . $core6k->id  . "\n";
print "  JA_vocab: "     . $core6k->ja_vocab  . "\n";
print "  JA_kana: "      . $core6k->ja_vocab_kana  . "\n";
print "  EN_vocab: "     . $core6k->en_vocab  . "\n";

#pp $core6k;
# The following prints how many sentences there are. Thanks to the
# magic of auto-stringification, I guess
print "  Sentences: "    . $core6k->sentences  . "\n";

foreach my $sen ($core6k->sentences) {
    print "[" . $sen->core_6k_id . ":" .$sen->sentence_id . "] " .
	$sen->sentence_id->ja_text . "\n";
}

## End testing Core Class::DBI stuff

use Gtk2 qw/-init/;
use Gtk2::Ex::FormFactory;

use GUI::CoreTestList;

GUI::CoreTestList->new->build_main_window;
Gtk2->main;

## I'll try to keep a separation between DB stuff and GUI stuff

