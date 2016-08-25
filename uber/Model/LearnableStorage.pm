package LearnableStorage;

# DB storage for Learnable class

use base 'Class::DBI::SQLite';

# Should probably make DB connection string an option somewhere
# instead of hard-wiring it.

LearnableStorage->connection(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/uber/learnables.sqlite",'','',
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 1, # set to 0 locally for big, slow updates
    }
);

sub begin_work {
    my $self = shift;
    $self->db_Main->begin_work;
}

sub end_work {
    my $self = shift;
    $self->db_Main->commit;
}


sub autoupdate        { 1 }

1;


package LearnableClass;
use parent -norequire, 'LearnableStorage';

__PACKAGE__->table  ('classes');
__PACKAGE__->columns(Primary => qw(class_id));
__PACKAGE__->columns(Others  => qw(class_name));

package LearnableConfig;
use parent -norequire, 'LearnableStorage';

__PACKAGE__->table  ('config');
__PACKAGE__->columns(Primary => qw(c_id));
__PACKAGE__->columns(Others  => qw(c_name c_value));

package LearnableCurrentStatus;
use parent -norequire, 'LearnableStorage';

__PACKAGE__->table  ('current_status');
__PACKAGE__->columns(Primary => qw(class_id class_key));
__PACKAGE__->columns(Others  => qw(change_time status));

__PACKAGE__->has_a(class_id => 'LearnableClass');


package LearnableStatusChange;
use base 'LearnableStorage';

__PACKAGE__->table  ('status_changes');
__PACKAGE__->columns(Primary => qw(class_id class_key change_time));
__PACKAGE__->columns(Others  => qw(old_status new_status));

__PACKAGE__->has_a(class_id => 'LearnableClass');


package LearnableTag;
use base 'LearnableStorage';

__PACKAGE__->table  ('tags');
__PACKAGE__->columns(Primary => qw(class_id class_key tag));

__PACKAGE__->has_a(class_id => 'LearnableClass');

package LearnableListContent;
use base 'LearnableStorage';

__PACKAGE__->table  ('list_contents');
__PACKAGE__->columns(Primary => qw(list_id class_id class_key));
__PACKAGE__->columns(Others  => qw(added_time));

__PACKAGE__->has_a(list_id => 'LearnableList');

package LearnableList;
use base 'LearnableStorage';

__PACKAGE__->table  ('lists');
__PACKAGE__->columns(Primary => qw(list_id));
__PACKAGE__->columns(Others  => qw(list_name list_note create_time update_time));

__PACKAGE__->has_many(contents => 'LearnableListContent');

