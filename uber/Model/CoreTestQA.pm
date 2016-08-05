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

# use autoload feature to provide simple get_* accessors
#use vars qw(%auto_attr $AUTOLOAD);
our $AUTOLOAD;
our %auto_attr = 
    map { ($_ => undef) } 
    qw(creation_id test_rec_id rng challenge_mode
       test_set items_total items_tested seed
       vocab_pop sentence_pop);
    
sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/^.*::get_//;
    croak "Method $attr can't be autoloaded" 
	unless exists $auto_attr{$attr};
    return $self->{$attr};
}

# More complicated accessors for multi-dimensional data


# Reuse valid types, modes from CoreTestList
our %valid_types = (
    'core2k' => undef,
    'core6k' => undef,
    'test2k' => undef,
    'test6k' => undef,
    );
our %valid_modes = (
    'sound'  => undef,
    'kanji'  => undef,
    #      'both'   => undef,
    );

sub new {
    my $class = shift;
    my %o = (
	creation_id    => undef, # epoch_time_created
	test_rec_id    => undef, # unique ID to record this test
				 # "sitting" (creation_id + a unique
				 # number)
	@_
	);

    # Both parameters below are mandatory
    unless (defined($o{creation_id}) and defined($o{test_rec_id})) {
	carp "$pkg->new requires both creation_id and test_rec_id args";
	return undef;
    }
    
    my $self = {
	creation_id    => $o{creation_id},
	test_rec_id    => $o{test_rec_id},
	rng            => Util::RNG->new,
	# The following are taken from the database
	challenge_mode => undef, # "sound" or "kanji"
	test_set       => undef, # "core[26]k" or "test[26]k"
	items_total    => undef,
	items_tested   => undef,
	questions      => [undef],
	answers        => [undef],
	# The following three need to be taken together to ensure that
	# the same random selection is generated each time
	seed           => undef,
	vocab_pop      => undef,
	sentence_pop   => undef,
	# private variables tracking Class::DBI objects
	_seed          => undef,
	_summary       => undef,
	_details       => undef,
    };
    bless $self, $class;

    die unless ref($self->{rng});
    
    # load summary information from database
    $self->read_test_summary;

    # Validate retrieved data
    croak "Invalid mode $o{mode}" unless exists $valid_modes{$self->{challenge_mode}};
    croak "Invalid type $o{type}" unless exists $valid_types{$self->{test_set}};

    
    
    # Next we need to actually (re)create the list of test items
    $self->generate_selection;

    
    
    # The following is subject to change (requires schema changes)
    my ($sound_items, $kanji_items);
    if ($self->{challenge_mode} eq "both") {
	croak "Challenge mode of both currently not implemented";
    } elsif ($self->{challenge_mode} eq "sound") {
	($sound_items, $kanji_items) = ($self->{items_total},0);
    } elsif ($self->{challenge_mode} eq "kanji") {
	($sound_items, $kanji_items) = (0,$self->{items_total});
    }


    # Then we update the test details based on any previous answers
    # stored in the database (so we don't ask them again)

    
    # read in stuff from the database
    
    


    bless $self, $class;

}

sub read_test_summary {
    my $self = shift;

    # Have to create a synthetic composite key
    my $summary_id  = "$self->{creation_id}_$self->{test_rec_id}";
    
    my $seed = CoreTracking::Seed->retrieve($self->{creation_id});

    my $test_summary =
	CoreTracking::TestSummary->retrieve($summary_id)
	or croak "Didn't find a database index for $summary_id";

    # The following relate to the test in the abstract
    $self->{test_set}       = $seed->type;
    $self->{items_total}    = $seed->items;
    $self->{seed}           = $seed->seed;
    $self->{vocab_pop}      = $seed->vocab_count;
    $self->{sentence_pop}   = $seed->sentence_count;
    
    $self->{challenge_mode} = $test_summary->mode;
    $self->{items_tested}   = $test_summary->items_tested;

    # stash the db accessors used here
    $self->{_summary} = $test_summary;
    $self->{_seed}    = $seed;
    
}

sub read_test_details {
    my $self = shift;

    my $summary = $self->{_summary}; # stashed DB accessor

    # use DB's one-to-many relationship for an easy iterator
    my $details = $summary->details;

    carp "DB inconsistency wrt number of items tested" 
	if $details != $self->{items_tested};

}

# used by generate_selection below. Go through the list and replace
# them with a struct containing sentence IDs and from the database
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
	$core6k = CoreVocab::Core6k->retrieve($_) or die;
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
    my $selections = shift or die;

    foreach my $sen (@$selections) {

	# $selections is now a list of hashes
	my $sid = $sen->{sentence_id} or die;

	# $sid (sentence ID) is in fact a Class::DBI handle so it can be
	# used for queries
	$sen->{sentence_ja_text}     = "" . $sid->ja_text;
	$sen->{sentence_ja_kana}     = "" . $sid->ja_kana;
	# English translations can vary between core2k data sets
	if      ($sen->{core_list} eq "core6k") {
	    $sen->{sentence_en_text}     = "" . $sid->en_text_6k;
	} elsif ($sen->{core_list} eq "core2k") {
	    $sen->{sentence_en_text}     = "" . $sid->en_text_2k;
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

    if ($test_set         eq "test2k") {
	$selections = [ 1..$items ];
	$self->populate_2k_entries($selections);
    } elsif ($test_set eq "test6k") {
	$selections = [ 1..$items ];
	$self->populate_6k_entries($selections);
    } elsif ($test_set eq "core2k") {
	$selections = [1 .. 2000];
	fisher_yates_shuffle($selections, $rng, $items);
	$self->populate_2k_entries($selections);
    } elsif ($test_set eq "core6k") {
	$selections = [1 .. 6000];
	fisher_yates_shuffle($selections, $rng, $items);
	$self->populate_6k_entries($selections);
    } else { die }

    $self->populate_sentence_details($selections);

    # Add a null element at the start (so indexing counts from 1) and
    # stash the resulting array
    unshift @$selections, undef;
    $self->{selections}=$selections;
}

1;
