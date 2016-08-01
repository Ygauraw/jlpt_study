#!/usr/bin/perl

# Use a bunch of different libraries to give a test on Core 6k (or 2k)
# vocabulary.
#
# Class::DBI to encapsulate database objects
# Gtk2::Ex::FormFactory to do most GUI stuff
# Gtk2::WebKit for <audio> support
# Net::OnlineCode::RNG for replayable random selections
#

BEGIN {
    # I should probably figure out why I need to do this
    push @INC, "/usr/local/lib/x86_64-linux-gnu/perl/5.20.2/";
}

# I happened to have this RNG lying around; I'll use it to generate
# sample tests and save the seed for replaying at a later time.
use Net::OnlineCode::RNG;

use strict;
use warnings;
use utf8;

binmode STDOUT, ":utf8";
binmode STDIN,  ":utf8";

use Data::Dump qw(dump dumpf pp);

require 'core_vocab_model.pm';
require 'core_tracking_model.pm';


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

CoreTester::GUI->new->build_main_window;
Gtk2->main;

## I'll try to keep a separation between DB stuff and GUI stuff

package TestList;

use Carp;

sub get_list {
    my ($self, $attr) = @_;
    my @lol = ();

    warn "Got here\n";

    my $iter = CoreTracking::Seed->retrieve_all;
    while (my $test =  $iter->next) {
	my $int_list = [$test->id, $test->epoch_time_created, 
			$test->type, $test->mode];
	# to get % complete, need to check other tables
	push @lol, $int_list;
    }
    return \@lol;
}

our %valid_types;		# apparently these won't get
our %valid_modes;		# initialised unless we use BEGIN {}

BEGIN {				
  %valid_types = (		# test types
      'core2k' => undef,
      'core6k' => undef,
      'test2k' => undef,
      'test6k' => undef,
      );
  %valid_modes = (		# challenge modes
      'sound'  => undef,
      'kanji'  => undef,
      'both'   => undef,
      );
}

sub new {
    my $class = shift;
    my $self = {
	rng => Net::OnlineCode::RNG->new,
    };
    return bless $self, $class;
}

# Create a new test item
sub new_item {
    my $self = shift;
    warn "Creating new_item with values " . (join ",", @_) . "\n";
    my %o = (
	type => undef,		# check against %valid_types
	mode => undef,		# check against %valid_modes
	items => undef,		# non-null
	seed => undef,
	@_
    );

    my ($now, $sound_items, $kanji_items, $vocab_count, $sentence_count) =
	(time, 0, 0, 0, 0);

    warn "valid modes: " . (join ", ", keys %valid_modes) . "\n";
    croak "Invalid mode $o{mode}" unless exists $valid_modes{$o{mode}};
    croak "Invalid type $o{type}" unless exists $valid_types{$o{type}};

    # make a random seed if we weren't given one
    $o{seed} = $self->{rng}->seed_random unless defined $o{seed};

    if ($o{mode} eq "both") {
	croak "Must have even number of items for mode='both'" if $o{items} & 1;
	$sound_items = $kanji_items = $o{items} >> 1;
    } elsif ($o{mode} eq "sound") {
	($sound_items, $kanji_items) = ($o{items},0);
    } elsif ($o{mode} eq "kanji") {
	($sound_items, $kanji_items) = (0,$o{items});
    }

    if ($o{type} eq "core2k") {
	($vocab_count, $sentence_count) = (2000, 2000);
    } else {
	$vocab_count     = 6000;
	$sentence_count  = 0 + CoreVocab::Sentence->retrieve_all;
    }	

    # Create seed  entry. Only create summary record once test starts
    my $entry = CoreTracking::Seed->insert(
	{
	    epoch_time_created  => $now,
	    type                => $o{type},
	    mode                => $o{mode},
	    items               => $o{items},
	    sound_items         => $o{sound_items},
	    kanji_items         => $o{kanji_items},
	    seed                => $o{seed},
	    vocab_count         => $vocab_count,
	    sentence_count      => $sentence_count,
	}
	);
    #    $entry->update;
}

sub delete_item {
    my $self = shift;
    my $id  = shift or croak;	# unique timestamp of the thing to be deleted

    CoreTracking::Seed->search(epoch_time_created => $id)->delete;    
}


sub fisher_yates_shuffle {	# (loosely) based on recipe 4.18 from
				# the Perl Cookbook
    my $array = shift;		# let next die catch missing array
    my $rng   = shift or die;
    # Change recipe to allow picking a certain number of elements
    my $picks = shift;		# allow it to be undef, as seen below

    $picks=scalar(@$array) unless
	defined($picks) and $picks >=0 and $picks<scalar(@$array);

    my ($i, $j) = (scalar(@$array),undef);
    while (--$i >= scalar(@$array) - $picks) {
	$j=$rng->rand ($i + 1); # random int from [0,$i]
	# next if $i==$j;       # don't swap element with itself
	@$array[$i,$j]=@$array[$j,$i]
    }

    # Return the last $picks elements from the end of the array
    splice @$array, 0, scalar @$array - $picks;
}

# used by generate_selection below. Go through odd elements in the
# list and replace them with values from the database
sub populate_selections {
    my $listref = shift;
    my $i       = 0;
    my $sentence;
    while ($i < @$listref) {
	if ($listref->[$i+1] eq "2k") {
	    $sentence = CoreVocab::Core2k->retrieve($listref->[$i])->main_sentence_id;
	} elsif ($listref->[$i+1] eq "6k") {
	    $sentence = CoreVocab::Sentence->retrieve($listref->[$i]);
	} else { die }
	$listref->[$i+1] = $sentence; # might as well just pass this object?
    } continue {
	$i += 2;
    }

}

# Look up the test record in the db and return something suitable for
# a testing window to work with (so it doesn't have to do DB lookups
# itself)
sub generate_selection {
    my $self = shift;
    my $id   = shift or die; 	# look up in database

    # Get the ID from the database
    my $ent = CoreTracking::Seed->retrieve($id);

    my $selections;

    if ($ent->type      eq "test2k") {
	$selections = [ map { $_, "2k" } 1..$ent->items ];	
    } elsif ($ent->type eq "test6k") {
	$selections = [ map { $_, "6k" } 1 ..$ent->items ];	
    } elsif ($ent->type eq "core2k") {
	my $picks = fisher_yates_shuffle([1 .. 2000], $self->rng, $ent->items);
	$selections = [ map { ($picks->[$_], "2k") } 0 .. scalar (@$picks) - 1 ];	
    } elsif ($ent->type eq "core6k") {
	my $nsentences = 0 + CoreVocab::Sentence->retrieve_all;
	my $picks = fisher_yates_shuffle([1 .. $nsentences], $self->rng, $ent->items);
	$selections = [ map { ($picks->[$_], "6k") } 0 .. scalar (@$picks) - 1 ];	
    } else { die }

    populate_selections($selections);

}

1;


package CoreTester::GUI;

# basic accessors
sub get_context                 { shift->{context}                      }
sub get_form_factory            { shift->{form_factory}                 }

sub set_context                 { shift->{context}              = $_[1] }
sub set_form_factory            { shift->{form_factory}         = $_[1] }


sub new {
    my $class = shift;
    bless { }, $class;
}

sub create_context {
    my $self = shift;
    $self->{context} = my $context = Gtk2::Ex::FormFactory::Context->new;

    # Add all objects
    $context -> add_object(
	name   => "tests",
	object => TestList->new,
	);

    return $context;
}

# A list of available tests
sub build_test_list {
    return Gtk2::Ex::FormFactory::List->new (
	name    => "test_list",
	attr    => "tests.list",
	columns => [ qw/time Created Type Mode %Complete/ ],
	visible => [ 0, 1,1,1 ],
	scrollbars         => [ "never", "automatic" ],
	height  => 400,
	expand_h => 1,
	selection_mode     => "single",
	);
}

# Testing of a single test selection
sub build_test_window {


}

sub build_main_window {
    
    my $self = shift;
    my $context = $self->create_context;

    my $ff = Gtk2::Ex::FormFactory->new (
	context => $context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new (
		title   => "Core Vocabulary Tester",
		properties => {
		    default_width  => 640,
		    default_height => 640,
		},
		quit_on_close => 1,
		content => [
		    Gtk2::Ex::FormFactory::VBox->new(
			content => [
			    build_test_list,
			    Gtk2::Ex::FormFactory::Button->new(
				label => 'Add test',
				clicked_hook => sub {
				    my $test_list = $context->get_object("tests");
				    $test_list -> new_item(
					mode => "kanji",
					type => "test2k",
					items => 20,
					);
				    $context->update_object_widgets("tests");
				}
			    )
			],
		    ),
		],
	    ),
	],
	);

    $ff->open;
    $ff->update;

}
