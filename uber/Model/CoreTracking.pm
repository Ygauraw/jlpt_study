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
__PACKAGE__->table('core_test_summary');
__PACKAGE__->columns(
    All => qw/epoch_time_created type mode items vocab_count sentence_count
              correct_voc_know correct_voc_read correct_voc_write
              correct_sen_know correct_sen_read correct_sen_write/);

__PACKAGE__->has_a(epoch_time_created => CoreTracking::TestSpec);

####################
package CoreTracking::TestSittingDetail ;
use base CoreTracking::DBI;
__PACKAGE__->table('core_test_sitting_details');
__PACKAGE__->columns(
    All => qw/id epoch_time_created epoch_time_start_test mode item_index
              correct_voc_know correct_voc_read correct_voc_write
              correct_sen_know correct_sen_read correct_sen_write/);

# half of many-to-one mapping to TestSummary
__PACKAGE__->has_a(id => CoreTracking::TestSitting);


####################
package CoreTracking::TestSitting;
use base CoreTracking::DBI;
__PACKAGE__->table('core_test_sitting');
__PACKAGE__->columns(
    All   => qw/id epoch_time_created epoch_time_start_test
                mode items_tested correct_voc_know correct_voc_read
                correct_voc_write correct_sen_know correct_sen_read
                correct_sen_write/);

__PACKAGE__->has_many(details => CoreTracking::TestSittingDetail);



####################
package CoreTracking::TestSpec;
use base CoreTracking::DBI;

__PACKAGE__->table('core_test_specs');
__PACKAGE__->columns(All => qw/epoch_time_created latest_test_sitting
                               test_type mode items seed /);

__PACKAGE__->has_many(details     => CoreTracking::TestSittingDetail);
__PACKAGE__->has_many(data_points => CoreTracking::DataPoint);

# expander/convertor from epoch time to something more useful (except
#that we can't initialise a Date::Simple from epoch seconds...)
#CoreTracking::Seed->has_a(epoch_time_created => 'Date::Simple');

1;
