package Model::Learnable;

use strict;
use warnings;

use utf8;

use Model::LearnableStorage;

our %class_name_id;
our @status_names;
our @status_2d_array;
our %status_2d_hash;

BEGIN {
    my $iter = LearnableClass->retrieve_all;
    while (my $class = $iter->next) {
	$class_name_id{$class->class_name} = $class->id;
    }
    @status_names = ( '-', 'Learning', 'Reviewing',
		      'SRS 1', 'SRS 2', 'SRS 3', 'SRS 4','SRS 5',
		      'Buried (-5)', 'Buried (-4)', 'Buried (-3)',
		      'Buried (-2)', 'Buried (-1)');
    for (-5 .. +7) {
	warn "Adding $_\n";
	push @status_2d_array, [$_, $status_names[$_]];
	$status_2d_hash{$_} = $status_names[$_];
    }
    warn "Have " . scalar(@status_2d_array) . " status elements\n";
}

sub get_statuses_2d {
    warn "Have a list of " . scalar(@status_names) . " named statuses\n";
    warn "Have " . scalar(@status_2d_array) . " status elements\n";
    [@status_2d_array]
}
sub get_statuses_hash {
    \%status_2d_hash
}


sub get_note {
    my $class = shift;
    die "Class/type $class not registered in database"
	unless exists $class_name_id{$class};
    $class->check_required_attributes(@_);
    my $key = $class->keyhash_to_string(@_);

    my $note = LearnableNote->retrieve(
	class_id   => $class_name_id{$class},
	class_key  => $key);
    return '' unless (defined($note));
    $note->note;
}

sub set_update_note {
    my $class = shift;
    my $newnote = shift;
    my $key = $class->keyhash_to_string(@_);
    my $class_id = $class_name_id{$class} or die "Class $class not in db\n";
    my ($cur, $hist, $oldstatus);

    $cur = LearnableNote->retrieve(
	class_id => $class_id, class_key => $key
    );
    if (defined($cur)) {
	return if $cur->note eq $newnote;
	$cur->note($newnote);
    } else {
	$cur = LearnableNote->insert({
	    class_id => $class_id, class_key => $key,
	    note => $newnote});
    }
    $cur->update;
}

sub status_text {
    my $class = shift;
    my $status = shift;
    die unless defined($status);
    die "Status outside range [-5,7]\n" if $status < -5 or $status > +7;
    return $status_names[$status];
}

sub get_status {
    my $class = shift;
    die "Class/type $class not registered in database"
	unless exists $class_name_id{$class};

    $class->check_required_attributes(@_);
    my $key = $class->keyhash_to_string(@_);
    
    my $status = LearnableCurrentStatus->retrieve(
	class_id   => $class_name_id{$class},
	class_key  => $key);
    return 0 unless (defined($status));
    $status->status;
}

# insert/update
sub set_update_status {
    my $class = shift;
    my $newstatus = shift;
    my $key = $class->keyhash_to_string(@_);
    my $class_id = $class_name_id{$class} or die "Class $class not in db\n";
    my ($now, $cur, $hist, $oldstatus) = (time);

    LearnableStorage->begin_work;
    $cur = LearnableCurrentStatus->retrieve(
	class_id => $class_id, class_key => $key
    );
    if (defined($cur)) {
	$oldstatus = $cur->status;
	$cur->status($newstatus);
	$cur->change_time($now);
    } else {
	$oldstatus = 0;
	$cur = LearnableCurrentStatus->insert({
	    class_id => $class_id, class_key => $key,
	    change_time => $now, status => $newstatus});
    }
    $cur->update;
    $hist = LearnableStatusChange->insert({
	class_id => $class_id, class_key => $key, change_time => $now,
	old_status => $oldstatus, new_status => $newstatus,
    });
    $hist->update;
    LearnableStorage->end_work;
}

# Checking required key attributes can be done in base class
sub required_attributes {
    my $class = shift;
    die "Subclass $class should define required_attributes() method!\n";
}
sub check_required_attributes {
    my $class = shift;
    my @attrs = $class->required_attributes;
    die "Wrong number of key attributes for $class\n" if @attrs - @_;
    my %hash = (@attrs, @_);
    if (2 * keys (%hash) - @attrs) {
	warn "Wrong attribute names for $class\n";
	warn join ",", @{%hash} . "\n";
	die;
    }
    foreach my $key (keys %hash) {
	# all key parts must be non-zero or a non-blank string
	die "$class attribute $key has invalid value $hash{$key}\n"
	    unless $hash{$key};
    }
}

package Learnable::Kanji;

use parent -norequire, 'Model::Learnable';

sub required_attributes { ( kanji => 0 ) }
sub keyhash_to_string {
    my $class = shift;
    my %opt   = @_;		# expected to have been validated
    return "$opt{kanji}";
}
sub keystring_to_hash {
    my $class  = shift;
    local($_)  = shift;
    die "Not a valid key string for $class: $_\n" unless /^(\w)$/;
    return { kanji => $1 };
}

package Learnable::KanjiExemplar;

use parent -norequire, 'Model::Learnable';

sub required_attributes { ( kanji => 0, yomi_id => 0 ) }

# subclass only responsible for marshalling key parameters
sub keyhash_to_string {
    my $class = shift;
    my %opt   = @_;		# expected to have been validated
    return "$opt{kanji}:$opt{yomi_id}";
}
sub keystring_to_hash {
    my $class  = shift;
    local($_)  = shift;
    die "Not a valid key string for $class: $_\n" unless /^(\w+):(\d+)$/;
    return { kanji => $1, yomi_id => $2 };
}

package Learnable::KanjiVocab;

use parent -norequire, 'Model::Learnable';

sub required_attributes { ( vocab_id => 0) }
sub keyhash_to_string {
    my $class = shift;
    my %opt   = @_;		# expected to have been validated
    return "$opt{vocab_id}";
}
sub keystring_to_hash {
    my $class  = shift;
    local($_)  = shift;
    die "Not a valid key string for $class: $_\n" unless /^(\d+)$/;
    return { vocab_id => $1 };
}

1;
