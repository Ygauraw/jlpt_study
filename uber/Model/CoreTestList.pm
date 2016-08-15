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

use Util::RNG;
use Util::Shuffle;


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

    my $now = time;

    warn "valid modes: " . (join ", ", keys %valid_modes) . "\n";
    croak "Invalid mode $o{mode}" unless exists $valid_modes{$o{mode}};
    croak "Invalid type $o{type}" unless exists $valid_types{$o{type}};

    # make a random seed if we weren't given one
    $o{seed} = $self->{rng}->seed_random unless defined $o{seed};

    # Create seed  entry. Only create summary record once test starts
    my $entry = CoreTracking::TestSpec->insert(
	{
	    epoch_time_created  => $now,
	    latest_test_sitting => $now,
	    test_type           => $o{type},
	    mode                => $o{mode},
	    items               => $o{items},
	    seed                => $o{seed},
	}
	);
    $entry->update;      # auto-update when $entry goes out of scope?

    my $summary = CoreTracking::TestSitting->insert(
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

    return "${now}_$now";	# handy for gui to launch test straight away
    
}

sub delete_item {
    my $self = shift;
    my $id  = shift or croak;	# unique timestamp of the thing to be deleted

    CoreTracking::Seed->search(epoch_time_created => $id)->delete;    
}


1;


