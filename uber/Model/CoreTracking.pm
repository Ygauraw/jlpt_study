#
# Class::DBI stuff for accessing testing/tracking database

package CoreTracking::DBI;
use base 'Class::DBI::SQLite';

# based partly on tutorial code that comes with FormFactory

# Should probably make DB connection string an option somewhere
# instead of hard-wiring it.

CoreTracking::DBI->connection(
    "dbi:SQLite:dbname=test_tracking.sqlite",'','',
    {   # does Class::DBI accept DBI/DBD options like below? Yes.
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 1,
    }
    );

#sub accessor_name_for { "get_$_[1]" }
#sub mutator_name_for  { "set_$_[1]" }
sub autoupdate        { 1 }


# Order of definitions below is important since any table with a
# has_many relationship has to appear after the table with the foreign
# key


####################
package CoreTracking::DataPoint ;
use base CoreTracking::DBI;
__PACKAGE__->table('data_points');
__PACKAGE__->columns(Primary => 'sitting_id');
__PACKAGE__->columns(Others  => 'test_id');

__PACKAGE__->has_a(sitting_id => CoreTracking::TestSitting);

####################
package CoreTracking::TestSittingDetail ;
use base CoreTracking::DBI;
__PACKAGE__->table('test_sitting_details');
__PACKAGE__->columns( # All?
Others   => qw/sitting_id test_id test_start_time test_mode item_index
              correct_voc_know correct_voc_read correct_voc_write
              correct_sen_know correct_sen_read correct_sen_write/);

# half of many-to-one mapping to TestSitting
__PACKAGE__->has_a(sitting_id => CoreTracking::TestSitting);


####################
package CoreTracking::TestSitting;
use base CoreTracking::DBI;
__PACKAGE__->table('test_sittings');
__PACKAGE__->columns(Primary => qw/sitting_id/);
__PACKAGE__->columns(Others  => qw/test_id test_start_time test_end_time
                items_tested
                correct_voc_know correct_voc_read correct_voc_write
                correct_sen_know correct_sen_read correct_sen_write/);

__PACKAGE__->has_many(details => CoreTracking::TestSittingDetail);

####################
package CoreTracking::TestSpec;
use base CoreTracking::DBI;

__PACKAGE__->table('test_specs');
# __PACKAGE__->set_up_table('test_specs');
__PACKAGE__->columns(Primary => 'test_id');
__PACKAGE__->columns(Others  => qw/time_created core_set test_type test_mode
                                   test_items randomise range_start range_end
                                   seed latest_sitting_id/);

__PACKAGE__->has_many  (details     => CoreTracking::TestSittingDetail
			=> 'latest_sitting_id');
__PACKAGE__->might_have(data_point  => CoreTracking::DataPoint);
# __PACKAGE__->sequence('test_specs_id_seq');

####################
package CoreTracking::ChapterOverview;
use base CoreTracking::DBI;

__PACKAGE__->table('chapter_overview');
__PACKAGE__->columns(Others  => qw/default_core2k_chapter_size
                                   default_core6k_chapter_size
                                   core_2k_progress core_6k_progress/);

1;
