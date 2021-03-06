# Bundle up a bunch of questions and answers for testing

package Model::CoreTestQA;

use Model::CoreVocab;
use Model::CoreTracking;

use strict;
use warnings;
use Carp;

use Util::RNG;
use Util::Shuffle;

our $pkg = __PACKAGE__;

# use autoload feature to provide simple get_* accessors for top-level
# attributes (stored in $self hash) or rec_* accessors for attributes
# relating to a specific test record (stored in $self->{selections}
# array).

our $AUTOLOAD;
our %get_attr =
    map { ($_ => undef) } 
    qw(sitting_id rng challenge_mode
       test_set items_total items_tested seed);
our %rec_attr =
    map { ($_ => undef) }
    qw(answered core_index core_list item_index playlist
       vocab_en vocab_kana vocab_kanji
       sentence_en_text sentence_ja_text sentence_ja_kana);
    
sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    if ($attr =~ s/^.*::get_//) {
	croak "Method get_$attr not registered for autoloading"
	    unless exists $get_attr{$attr};
	return $self->{$attr};
    }
    if ($attr =~ s/^.*::rec_//) {
	croak "Method rec_$attr not registered for autoloading"
	    unless exists $rec_attr{$attr};
	my $index = shift or die ;
	return $self->{selections}->[$index]->{$attr};
    }
    croak "Method $attr does not exist";
}

sub new {
    my $class = shift;
    my %o = (
	sitting_id    => undef,
	test_id       => undef,	# we could pull from db, but ...
	@_
	);

    # Both parameters below are mandatory
    unless (defined($o{sitting_id})) {
	carp "$pkg->new requires test sitting id";
	return undef;
    }
    unless (defined($o{test_id})) {
	carp "$pkg->new requires test spec id";
	return undef;
    }

    my $sitting_id  = $o{sitting_id};
    my $test_id     = $o{test_id};
    my $self = {
	sitting_id     => $sitting_id,
	test_id        => $test_id,
	creation_id    => undef,   # to be deleted
	test_rec_id    => undef,   # to be deleted
	rng            => Util::RNG->new,
	# The following come from the database
	test_set       => "unset", # "core2k" or "core6k"
	test_type      => "unset", # "range", "chapter" or "random"
	challenge_mode => "unset", # "sound" or "kanji"
	items_total    => undef,
	items_tested   => undef,
	# seed allows repeatable random selection
	seed           => undef,
	# private variables tracking Class::DBI objects
	_test_spec     => undef,
	_sitting       => undef,
    };
    bless $self, $class;

    die "RNG not a ref" unless ref($self->{rng});

    # load summary information from database
    $self->read_test_summary;

    # Validate retrieved data
    die "Invalid mode $self->{challenge_mode}" 
	unless Model::CoreTestList->validate_mode($self->{challenge_mode});
    die "Invalid type $self->{test_type}" 
	unless Model::CoreTestList->validate_type($self->{test_type});
    die "Invalid test set $self->{test_set}" unless 
	$self->{test_set} eq "core2k" or $self->{test_set} eq "core6k";

    # Next we need to actually (re)create the list of test items
    $self->generate_selection;

    # Then we update the test details based on any previous answers
    # stored in the database (so we don't ask them again in this test)
    $self->load_previous_answers;

    bless $self, $class;

}

sub read_test_summary {
    my $self = shift;
    my $sitting_id  = $self->get_sitting_id;
    my $sitting   = CoreTracking::TestSitting->retrieve($sitting_id)
	or croak "Didn't find a database index for $sitting_id";
    my $test_spec = $sitting->test_id;

    # The following relate to the test in the abstract
    $self->{test_set}       = $test_spec->core_set;
    $self->{test_type}      = $test_spec->test_type;
    $self->{items_total}    = $test_spec->test_items;
    $self->{seed}           = $test_spec->seed;
    $self->{range_start}    = $test_spec->range_start;
    $self->{range_end}      = $test_spec->range_end;
    $self->{challenge_mode} = $test_spec->test_mode;

    $self->{items_tested}   = $sitting->items_tested;

    # stash the db accessors used here
    $self->{_sitting}       = $sitting;
    $self->{_test_spec}     = $test_spec;
    
}


# No point updating totals until a test is finished
sub update_answer_summary {
    my $self    = shift;
    my $sitting = $self->{_sitting}; # reuse saved query
    my $items_tested = 0;
    my $tallies = {
	correct_voc_know  => 0,
	correct_voc_read  => 0,
	correct_voc_write => 0,
	correct_sen_know  => 0,
	correct_sen_read  => 0,
	correct_sen_write => 0,
    };

    foreach my $rec (@{$self->{selections}}) {
	next unless defined $rec;
	next unless $rec->{answered};
	for (keys %$tallies) {
	    $tallies->{$_} += $rec->{$_}
	}
	++$items_tested;
    }
    croak unless $self->get_items_tested == $items_tested;
    # Use low-level method to update Class::DBI data
    $tallies->{items_tested} = $items_tested;
    $sitting->_attribute_set($tallies);
    $sitting->update;
}


# used by generate_selection below. Go through the list and replace
# them with a struct containing sentence IDs and other data from the
# database
sub populate_2k_entries {
    my $self    = shift;
    my $listref = shift;
    my $core2k;
    
    foreach (@$listref) {	# do in-place replacement of elements
	my $replacement = {};
	$core2k = CoreVocab::Core2k->retrieve($_);
	$replacement->{core_index}  = $_; # original core2k index
	$replacement->{core_list}   = 'core2k';
	# Stringify the values below (actually Class::DBI objects)
	# since we don't need to do queries on them any more
	$replacement->{vocab_kanji} = "" . $core2k->ja_vocab;
	$replacement->{vocab_kana}  = "" . $core2k->ja_vocab_kana;
	$replacement->{vocab_en}    = "" . $core2k->en_vocab;
	$replacement->{sentence_id} = $core2k->main_sentence_id;

	# Create a playlist with the sound for this vocab element
	$replacement->{playlist} = [
	    $core2k->vocab_id->sound_id->local_filename . "",
	    ];
	$_ = $replacement;
    }
}

# 6k is similar to 2k. We have different tables to search, naturally,
# but we may also have to select between several possible
# sentences. Keep using the original RNG for repeatable results.
sub populate_6k_entries {
    my $self    = shift;
    my $listref = shift;
    my $core6k;
    my $rng     = $self->get_rng;

    foreach (@$listref) { # do in-place replacement of elements
	my $replacement = {};
	$core6k = CoreVocab::Core6k->retrieve($_) 
	    or die "$_ returned no Core6k elements";
	$replacement->{core_index}  = $_; # original core6k index
	$replacement->{core_list}   = 'core6k';
	$replacement->{vocab_kanji} = "" . $core6k->ja_vocab;
	$replacement->{vocab_kana}  = "" . $core6k->ja_vocab_kana;
	$replacement->{vocab_en}    = "" . $core6k->en_vocab;

	# $_ should also index directly into vocabulary table
	$replacement->{playlist} = [
	    CoreVocab::Vocab->retrieve($_)->sound_id->local_filename . "",
	    ];
	# Pick one of the sample sentences 
	my @sentence_choices = $core6k->sentences;
	my @indices = (0..scalar(@sentence_choices) - 1);
	my $pick = fisher_yates_shuffle(\@indices, $rng, 1)->[0];
	my $selected_sentence = $sentence_choices[$pick]->sentence_id;
	$replacement->{sentence_id} = $selected_sentence;
	$_ = $replacement;
    }
}

# Called once we have a sentence ID and other vocab info stored
sub populate_sentence_details {
    my $self       = shift;
    my $selections = shift or die "No sentence selections to populate";
    my $item_index = 1;
    
    foreach my $sen (@$selections) {

	# $selections is now a list of hashes
	my $sid = $sen->{sentence_id} or die;

	# Also store an item index
	$sen->{item_index} = $item_index++;

	# $sid (sentence ID) is a Class::DBI object so it can be used
	# for queries
	$sen->{sentence_ja_text}     = "" . $sid->ja_text;
	$sen->{sentence_ja_kana}     = "" . $sid->ja_kana;
	# English translations can vary between core2k data sets
	$sen->{sentence_en_text}     = "" . $sid->en_text;
	if      ($sen->{core_list} eq "core6k") {
	    $sen->{sentence_en_text}     = "" . $sid->en_text_6k
		if $sid->en_text_6k;
	} elsif ($sen->{core_list} eq "core2k") {
	    $sen->{sentence_en_text}     = "" . $sid->en_text_2k
		if $sid->en_text_2k;
	} else {die}

	push @{$sen->{playlist}}, "" . $sid->sound_id->local_filename;

	# Now that we've finished using the overloaded $sid, stringify
	# it so that it isn't a database object any more
	$sen->{sentence_id} = "$sid";
    }
}

# Look up the test record in the db and return something suitable for
# a testing window to work with (so it doesn't have to do DB lookups
# itself)
sub generate_selection {
    my $self  = shift;
    my $items = $self->get_items_total;
    my $rng   = $self->get_rng;
    $rng->seed($self->get_seed);

    # We should already have data read in from the db.
    my $test_set = $self->get_test_set;

    # selections will just be a list of selections from the relevant
    # core list. After selection, those records need to be looked up.
    my $selections;		

    my $range_start = $self->{range_start};
    my $range_end   = $self->{range_end};

    #warn "using $items items from range [$range_start .. $range_end]\n";

    $selections = [$range_start .. $range_end];

    if ($self->{test_type} eq "random") {
	fisher_yates_shuffle($selections, $rng, $items);
    }

    if ($test_set eq "core2k") {
	$self->populate_2k_entries($selections);
    } elsif ($test_set eq "core6k") {
	$self->populate_6k_entries($selections);
    } else {
	die
    }

    $self->populate_sentence_details($selections);

    # Add a null element at the start (so indexing counts from 1) and
    # stash the resulting array
    unshift @$selections, undef;
    $self->{selections}=$selections;
}

sub load_previous_answers {
    my $self = shift;
    
    my $sitting_id = $self->{sitting_id};

    # use DB's one-to-many relationship for an easy iterator
    my $sitting = $self->{_sitting}; # stashed DB accessor
    my @details = $sitting->details;

    my $items_total = $self->{items_total};

    foreach (@{$self->{selections}}) {
	next unless defined;
	$_->{answered} = 0;
    }

    # Do some validation on the data returned
    die "DB inconsistency wrt number of items tested" 
	if scalar (@details) != $self->{items_tested};
    foreach my $detail (@details) {
	my $index = $detail->item_index;
	croak if $index < 1 or $index > $items_total;
	die "dying here" if $detail->sitting_id ne $sitting_id;
	my $ent = $self->{selections}->[$index];
	# The six questions and a flag to indicate we have the answer
	$ent->{answered} = 1;
	$ent->{correct_voc_know}  = $detail->correct_voc_know;
	$ent->{correct_voc_read}  = $detail->correct_voc_read;
	$ent->{correct_voc_write} = $detail->correct_voc_write;
	$ent->{correct_sen_know}  = $detail->correct_sen_know;
	$ent->{correct_sen_read}  = $detail->correct_sen_read;
	$ent->{correct_sen_write} = $detail->correct_sen_write;
    }
}

sub save_answers {
    my $self = shift;
    # all fields are mandatory
    my $fields = {
	item_index        => undef,
	correct_voc_know  => undef,
	correct_voc_read  => undef,
	correct_voc_write => undef,
	correct_sen_know  => undef,
	correct_sen_read  => undef,
	correct_sen_write => undef,
	@_
    };
    
    #warn "Adding new test detail:" . join ",", @_;
    croak "Extraneous arguments to save_answers" unless 7 == keys %$fields;

    foreach (keys %$fields) {
	die "Undefined field $_\n" unless defined $fields->{$_};
    }
    my $index = $fields->{item_index};
    die "Index out of range"
	if $index < 1 or $index > $self->get_items_total;
    my $rec = $self->{selections}->[$index];
    if ($rec->{answered}) {
	die "But question #$index is already answered!";
    }

    # update local structures so that it's quicker to update total
    # counts in the summary table later
    $rec->{answered}=1;
    $self->{items_tested}++;
    # set answer fields (and also item_index, which is the same)
    for (keys %$fields) { 
	$rec->{$_} = $fields->{$_}
    }

    # Now write a database record
    #warn "About to insert into db\n";
    $fields->{sitting_id} = $self->{sitting_id};
    my $ent = CoreTracking::TestSittingDetail->insert($fields);
    $ent->update;
    #warn "Added new test detail\n";
}

1;
