# Class::DBI stuff for accessing kanji_readings database

package KanjiReadings::DBI;
use base 'Class::DBI::SQLite';

# Should probably make DB connection string an option somewhere
# instead of hard-wiring it.

KanjiReadings::DBI->connection(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/uber/kanji_readings.sqlite",'','',
    {   # does Class::DBI accept DBI/DBD options like below? Yes.
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );

sub autoupdate        { 1 }

package KanjiReadings::Summary;
use base KanjiReadings::DBI;

KanjiReadings::Summary->table('summary');

package KanjiReadings::ReadingTally;
use base KanjiReadings::DBI;

KanjiReadings::ReadingTally->table('reading_tallies');

package KanjiReadings::VocabReading;
use base KanjiReadings::DBI;

KanjiReadings::Summary->table('vocab_readings');

1;
