package Model::CoreTestList;

# Implements storage for a list of different types of tests and
# associated data.
#

use strict;
use Carp;

use Util::RNG;
use Util::Shuffle;

sub new {
    my $class = shift;
    my $self = {
	rng => Util::RNG->new,
    };
    return bless $self, $class;
}


our %valid_types;		# apparently if you use require
our %valid_modes;		# instead of use, these won't get

BEGIN {
  %valid_types = (		# test types
      'random' => undef,
      'range' => undef,
      'chapter' => undef,
      );
  %valid_modes = (		# challenge modes
      'sound'  => undef,
      'kanji'  => undef,
#      'both'   => undef,
      );
}

sub validate_type {
    my $class = shift;
    #warn keys %valid_types;
    exists $valid_types{$_[0]}
}

sub validate_mode {
    my $class = shift;
    exists $valid_modes{$_[0]}
}

# Aggregate data relating to test and sitting tables and return them
# as a hash for easier querying/manipulation.
sub test_fields_from_test_iter {
    my ($self, $iter) = @_;
    die "iter is not a reference" unless ref($iter);
    my %ls_fields = ();		# fields from last sitting table
    my $sit = $iter->latest_sitting_id;
    if ($sit != 0) {
	%ls_fields = (
	    ls_test_start_time	   => $sit->test_start_time,
	    ls_test_end_time       => $sit->test_end_time,
	    ls_items_tested        => $sit->items_tested,
	    ls_correct_voc_know    => $sit->correct_voc_know,
	    ls_correct_voc_read    => $sit->correct_voc_read,
	    ls_correct_voc_write   => $sit->correct_voc_write,
	    ls_correct_sen_know    => $sit->correct_sen_know,
     	    ls_correct_sen_read    => $sit->correct_sen_read,
     	    ls_correct_sen_write   => $sit->correct_sen_write,
     	);
    }
    my %fields = (
	# does the following line create a new handle for, eg,
	# updating the row?
	test_row_iter      => $iter->test_id,
	test_id            => $iter->test_id,
	time_created       => $iter->time_created,
	core_set           => $iter->core_set,
	test_type          => $iter->test_type,
	test_mode          => $iter->test_mode,
	test_items         => $iter->test_items,
	randomise          => $iter->randomise,
	range_start        => $iter->range_start,
	range_end          => $iter->range_end,
	seed               => $iter->seed,
	latest_sitting_id  => $iter->latest_sitting_id,
	%ls_fields,
    );
    # Could add more pseudo-fields like number of sittings, times
    # completed and so on
    return \%fields;
}
sub test_fields_from_test_id {
    my ($self, $id) = @_;
    test_fields_from_test_iter(CoreTracking::TestSpec->retrieve($id));
}


# Create a new test item
sub new_item {
    my $self = shift;
    #warn "Creating new_item with values " . (join ",", @_) . "\n";
    my %o = (
	type => "undef",	# check against %valid_types
	mode => "undef",	# check against %valid_modes
	set  => "undef",        # core2k or core6k
	items => 0,		# non-null
	first => 0,		# if set, first + items is last item
	seed => undef,
	@_
    );

    croak "Can't add a test with 0 items (did you forget items?)"
	unless $o{items} >0;

    my $now = time;

    #warn "valid modes: " . (join ", ", keys %valid_modes) . "\n";
    croak "Bad mode $o{mode}" unless $self->validate_mode($o{mode});
    croak "Bad type $o{type}" unless $self->validate_type($o{type});
    croak "Bad set $o{set}"   unless $o{set} eq "core6k" or $o{set} eq "core2k";

    # Test type and items are mandatory (checked above), but first can
    # be optional. Check/set first, then set range_start/range_end
    my $max_items = $o{set} eq "core6k" ? 6_000 : 2_000;
    my ($range_start, $range_end);
    if ($o{type} eq "chapter") {
	die "'first' argument needed for 'chapter' test" unless $o{first} >0;
	if ($o{first} + $o{items} - 1 > $max_items) {
	    ($range_start, $range_end) = ($o{first}, $max_items);
	    $o{items} = $range_end - $range_start;
	}
    } elsif ($o{type} eq "range") {
	die "'first' argument needed for 'range' test" unless $o{first} >0;
	if ($o{first} + $o{items} - 1 > $max_items) {
	    croak "Selection of $o{first} + $o{items} is too big for $o{set}\n";
	}
	($range_start, $range_end) = ($o{first}, $o{first} + $o{items} - 1);
    } elsif ($o{type} eq "random") {
	# first is optional
	$o{first} = 1 unless $o{first};
	if ($o{items} > $max_items) {
	    croak "There aren't $o{items} in $o{set}\n";
	}
	($range_start, $range_end) = ($o{first}, $max_items);
    } else {
	die;
    }

    #warn "range is [$range_start .. $range_end]\n";

    # Make a random seed if we weren't given one
    $o{seed} = $self->{rng}->seed_random unless defined $o{seed};

    # Create test spec.  Only create sitting record once test starts
    my $entry = CoreTracking::TestSpec->insert(
	{
	    # allow Class::DBI to create a new id
	    time_created        => $now,
	    latest_sitting_id   => 0,
	    core_set            => $o{set},
	    test_type           => $o{type},
	    test_mode           => $o{mode},
	    test_items          => $o{items},
	    range_start         => $range_start,
	    range_end           => $range_end,
	    seed                => $o{seed},
	}
    );
    # maybe don't update straight away ... will add sitting_id below
    #$entry->update;

    my $sitting = CoreTracking::TestSitting->insert(
	{
	    test_id         => $entry->id, # Class::DBI autoincrement magic
	    test_start_time => $now,

	    items_tested          => 0,
	    correct_voc_know      => 0,
	    correct_voc_read      => 0,
	    correct_voc_write     => 0,
	    correct_sen_know      => 0,
	    correct_sen_read      => 0,
	    correct_sen_write     => 0,
	}
	);

    # Not sure if calling $sitting->id twice does double increment (I
    # tested it and it doesn't)
    my $sitting_id = "". $sitting->id;
    $entry->latest_sitting_id($sitting_id);
    $entry->update;
    $sitting->update;

    return $sitting_id;	  # handy for gui to launch test straight away

}

sub delete_item {
    my $self = shift;
    my $test_id  = shift or croak;
    CoreTracking::TestSpec->search(test_id => $test_id)->delete;
}


1;
