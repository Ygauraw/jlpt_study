package Model::Learnable;

use Model::LearnableStorage;

our %class_name_id;
our @status_names = ( '', 'Enrolled', 'Reviewing',
		      'SRS 1', 'SRS 2', 'SRS 3', 'SRS 4','SRS 5',
		      'Buried (-5)', 'Buried (-4)', 'Buried (-3)', 'Buried (-2)',
		      'Buried (-1)');

BEGIN {
    my $iter = LearnableClass->retrieve_all;
    while (my $class = $iter->next) {
	$class_name_id{$class->class_name} = $class->id;
    }
}

sub status_text {
    my $class = shift;
    my $status = shift;
    die unless defined($status);
    die "Status outside range [-5,7]\n" if $st < -5 or $st > +7;
    return $status_names[$st];	
}

sub get_status {
    my $class = shift;
    my $key   = shift || die "$class: Key must not be null\n";
    die "Class/type $class not registered in database"
	unless exists $class_name_id{$class};
    
    my $status = LearnableCurrentStatus->retrieve(
	class_id   => $class_name_id{$class},
	class_key  => $key);
    return 0 unless (defined($status));
    $status->status;
}

package Learnable::KanjiExemplar;

use parent -norequire, 'Model::Learnable';

# subclass only responsible for marshalling/checking key arguments
sub get_status {
    warn join "\n", @_;
    my $self = shift;
    my $opt = {
	kanji => 0,
	yomi_id => 0,
	@_
    };
    die "Extra parameters to $self::get_status\n" unless 2 == keys %$opt;
    die "Bad kanji parameter passed to $self::get_status\n" unless $opt->{kanji};
    die "Bad yomi_id passed to $self::get_status\n" unless $opt->{yomi_id} > 0;
    # Super doesn't need to know we're using a composite key
    $self->SUPER::get_status("$opt->{kanji}:$opt->{yomi_id}");
}

package Learnable::KanjiVocab;

use parent -norequire, 'Model::Learnable';

# subclass only responsible for marshalling/checking key arguments
sub get_status {
    warn join "\n", @_;
    my $self = shift;
    my $opt = {
	vocab_id => 0,
	@_
    };
    die "Extra parameters to $self::get_status\n" unless 1 == keys %$opt;
    die "Bad vocab_id passed to $self::get_status\n" unless $opt->{vocab_id} > 0;
    $self->SUPER::get_status($opt->{vocab_id});
}


1;
