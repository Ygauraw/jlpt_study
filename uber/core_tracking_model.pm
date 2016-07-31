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
CoreTracking::DataPoint->table('core_test_summary');
CoreTracking::DataPoint->columns(
    All => qw/epoch_time_created type mode items vocab_count sentence_count
              correct_voc_know correct_voc_read correct_voc_write
              correct_sen_know correct_sen_read correct_sen_write/);

CoreTracking::DataPoint->has_a(epoch_time_created => 'CoreTracking::Seed');

####################
package CoreTracking::TestDetail ;
use base CoreTracking::DBI;
CoreTracking::TestDetail->table('core_test_summary');
CoreTracking::TestDetail->columns(
    All => qw/id epoch_time_created epoch_time_start_test mode item_index
              correct_voc_know correct_voc_read correct_voc_write
              correct_sen_know correct_sen_read correct_sen_write/);

# half of many-to-one mapping to TestSummary
CoreTracking::TestDetail->has_a(id => 'CoreTracking::TestSummary');


####################
package CoreTracking::TestSummary;
use base CoreTracking::DBI;
CoreTracking::TestSummary->table('core_test_summary');
CoreTracking::TestSummary->columns(
    All => qw/id epoch_time_created epoch_time_start_test mode items_tested
              correct_voc_know correct_voc_read correct_voc_write
              correct_sen_know correct_sen_read correct_sen_write/);

CoreTracking::TestSummary->has_many(details => 'CoreTracking::TestDetail');



####################
package CoreTracking::Seed;
use base CoreTracking::DBI;
CoreTracking::Seed->table('core_test_seeds');
CoreTracking::Seed->columns(All => qw/epoch_time_created type mode items sound_items 
                                      kanji_items seed vocab_count sentence_count/);

CoreTracking::Seed->has_many(details     => 'CoreTracking::TestDetail');
CoreTracking::Seed->has_many(data_points => 'CoreTracking::DataPoint');

# expander/convertor from epoch time to something more useful (except
#that we can't initialise a Date::Simple from epoch seconds...)
#CoreTracking::Seed->has_a(epoch_time_created => 'Date::Simple');

1;
