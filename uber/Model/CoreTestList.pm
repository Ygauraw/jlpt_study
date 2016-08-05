package Model::CoreTestList;

# Implements storage for a list of different types of tests.
#
# I want to have an MVC-style separation of (at least) GUI elements
# and other logic. It's not very easy to map this onto what happens
# within FormFactory, but at least for now I have GUI stuff in one
# directory and "other" stuff in here.
#
# Things are a little bit muddy, however, since this object gets
# registered directly with the FormFactory::Context object with a
# particular name and we also provide an accessor for it.
#
# So many ways to look at MVC and organise code around that pattern,
# apparently.

use strict;
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
    my $self = {
	rng => Util::RNG->new,
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
    $entry->update;      # auto-update when $entry goes out of scope?

    my $summary = CoreTracking::TestSummary->insert(
	{
	    id                    => "${now}_$now",
	    epoch_time_created    => $now,
	    epoch_time_start_test => $now,
	    mode                  => $o{mode},
	    # end of key fields

	    items_tested          => 0,
	    correct_voc_know      => 0,
	    correct_voc_read      => 0,
	    correct_voc_write     => 0,
	    correct_sen_know      => 0,
	    correct_sen_read      => 0,
	    correct_sen_write     => 0,
	}
	);

}

sub delete_item {
    my $self = shift;
    my $id  = shift or croak;	# unique timestamp of the thing to be deleted

    CoreTracking::Seed->search(epoch_time_created => $id)->delete;    
}


1;


