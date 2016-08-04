# Bundle up a bunch of questions and answers for testing

package Model::CoreTestQA;

use strict;
use warnings;
use Carp;

use Util::RNG;
use Util::Shuffle;

our $pkg = __PACKAGE__;

# Reuse valid types, modes from CoreTestList
our %valid_types;		# apparently if you use require
our %valid_modes;		# instead of use, these won't get
				# initialised unless we use BEGIN {}
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
#      'both'   => undef,
      );
}

sub new {
    my $class = shift;
    my %o = (
	creation_id    => undef, # epoch_time_created
	test_rec_id    => undef, # unique ID to record this test
				 # "sitting" (creation_id + a unique
				 # number)
	@_
	);

    my $self = {
	creation_id    => $o{creation_id},
	test_rec_id    => $o{test_rec_id},
	rng            => Util::RNG->new,
	# The following are taken from the database
	challenge_mode => undef, # "sound" or "kanji"
	test_set       => undef, # "core[26]k" or "test[26]k"
	items_total    => undef,
	items_tested   => undef,
	questions      => undef,
	answers        => undef,
	# The following three need to be taken together to ensure that
	# the same random selection is generated each time
	seed           => undef,
	vocab_pop      => undef,
	sentence_pop   => undef,
    };
    bless $self, $class;

    # load in stuff from database
    $self->read_test_record;

    # Validate retrieved data
    croak "Invalid mode $o{mode}" unless exists $valid_modes{$o{mode}};
    croak "Invalid type $o{type}" unless exists $valid_types{$o{type}};


    # The following is subject to change (requires schema changes)
    my ($sound_items, $kanji_items);
    if ($o{mode} eq "both") {
	croak "Challenge mode of both currently not implemented";
    } elsif ($o{mode} eq "sound") {
	($sound_items, $kanji_items) = ($o{items},0);
    } elsif ($o{mode} eq "kanji") {
	($sound_items, $kanji_items) = (0,$o{items});
    }

    # read in stuff from the database
    $o{seed} = $self->{rng}->seed_random unless defined $o{seed};
    
    


    bless $self, $class;

}

sub read_test_record {
    my $self = shift;

    my $test_summary =
	CoreTracking::TestSummary->retrieve($self->{creation_id})
	or croak "Didn't find a database index for $self->{creation_id}";

    # The following relate to the test in the abstract
    $self->{challenge_mode} = $test_summary->mode;
    $self->{test_set}       = $test_summary->type;
    $self->{items_total}    = $test_summary->items;
    $self->{seed}           = $test_summary->seed;
    $self->{vocab_pop}      = $test_summary->vocab_count;
    $self->{sentence_pop}   = $test_summary->sentence_count;

    # And the following relate to a particular sitting of the test
    my $test_sitting = CoreTracking::TestDetail->retrieve
	({
	    epoch_time_created    => $self->{creation_id},
	    epoch_time_start_test => $self->{test_rec_id},
	 })
	or croak "Didn't find a matching test sitting";

    
    
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

