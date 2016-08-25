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

sub get_status_text {
    my $class = shift;
    my $key   = shift || die "$class: Key must not be null\n";
    die "Class/type $class not registered in database"
	unless exists $class_name_id{$class};
    
    my $status = LearnableCurrentStatus->retrieve(
	class_id   => $class_name_id{$class},
	class_key  => $key);
    return '' unless (defined($status));
    my $st = $status->status;
    die "Status outside range [-5,7]\n" if $st < -5 or $st > +7;
    return $status_names[$st];	
}

package Learnable::KanjiExemplar;

use parent -norequire, 'Model::Learnable';

package Learnable::KanjiVocab;

use parent -norequire, 'Model::Learnable';


1;
