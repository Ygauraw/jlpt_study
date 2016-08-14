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

####################

package KanjiReadings::ReadingTally;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('reading_tallies');
__PACKAGE__->columns(Primary => qw(kanji read_type kana));
__PACKAGE__->columns(Others  => qw(hiragana exemplar raw_tally adj_tally));

__PACKAGE__->has_a  (kanji   => 'KanjiReadings::Summary');

####################

package KanjiReadings::VocabReading;
use base 'KanjiReadings::DBI';

KanjiReadings::VocabReading->table('vocab_readings');
# The following are not actually primary keys, but we need to pretend
# they are so that Class::DBI will work properly when doing has_many
# from Summary table.
__PACKAGE__->columns(Primary => qw(kanji vocab_kanji vocab_kana reading_type
                                   jlpt_grade));
__PACKAGE__->columns(Others  => qw(reading_hira reading_kana
                                   adj_hira adj_type adj_kana ignore_flag));

__PACKAGE__->has_a  (kanji   => 'KanjiReadings::Summary');

####################

package KanjiReadings::Summary;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('summary');
__PACKAGE__->columns(Primary => 'kanji');
__PACKAGE__->columns(Others  => qw(heisig6_seq num_readings adj_readings 
                                   num_vocab num_failed adj_failed));

__PACKAGE__->has_many(tallies => 'KanjiReadings::ReadingTally');
__PACKAGE__->has_many(vocab_readings => 'KanjiReadings::VocabReading',
    { order_by => vocab_kanji} );


1;
