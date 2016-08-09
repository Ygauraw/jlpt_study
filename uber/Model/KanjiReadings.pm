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
        AutoCommit     => 1,
    }
    );

sub autoupdate        { 1 }

####################

package KanjiReadings::ReadingTally;
use base 'KanjiReadings::DBI';

KanjiReadings::ReadingTally->table('reading_tallies');
KanjiReadings::ReadingTally->columns(
    Others => qw(kanji read_type kana hiragana raw_tally adj_tally));

KanjiReadings::ReadingTally->has_a(kanji => 'KanjiReadings::Summary');

####################

package KanjiReadings::VocabReading;
use base 'KanjiReadings::DBI';

KanjiReadings::VocabReading->table('vocab_readings');
KanjiReadings::VocabReading->columns(
    Others => qw(kanji vocab_kanji vocab_kana 
                reading_hira reading_type reading_kana
                jlpt_grade adj_hira adj_type adj_kana ignore_flag));

KanjiReadings::VocabReading->has_a(kanji => 'KanjiReadings::Summary');

    
####################

package KanjiReadings::Summary;
use base 'KanjiReadings::DBI';

KanjiReadings::Summary->table('summary');
KanjiReadings::Summary->columns(Primary => 'kanji');
KanjiReadings::Summary->columns(
    Others => qw(heisig6_seq num_readings adj_readings num_vocab
                num_failed adj_failed));

KanjiReadings::Summary->has_many(
    tallies        => 'KanjiReadings::ReadingTally');
KanjiReadings::Summary->has_many(
    vocab_readings => 'KanjiReadings::VocabReading');


1;
