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


###############################################################################
#
# I'm doing a complete rework of all tables, now basing them around
# the central many-to-many relationship between kanji and vocab.
#
# The order of tables below is mandated by has_many semantics
#

####################

package KanjiReadings::KanjiVocabLink;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('kanji_vocab_link');
__PACKAGE__->columns(Primary=> qw(kv_link_id));
__PACKAGE__->columns(Others => qw(kanji yomi_id adj_yomi_id adj_reason vocab_id));

__PACKAGE__->has_a(kanji    => KanjiReadings::Kanji);
__PACKAGE__->has_a(vocab_id => KanjiReadings::Vocabulary);
__PACKAGE__->has_a(yomi_id  => KanjiReadings::Yomi);

####################

package KanjiReadings::KanjiYomiTally;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('kanji_yomi_tally');
__PACKAGE__->columns(Primary => qw(kanji yomi_id));
__PACKAGE__->columns(Others  => qw(
                                  yomi_count adj_count
                                  exemplary_vocab_id));

__PACKAGE__->has_a(kanji                => KanjiReadings::Kanji);
__PACKAGE__->has_a(yomi_id              => KanjiReadings::Yomi);
__PACKAGE__->might_have(exemplary_vocab => KanjiReadings::Vocabulary);

####################

package KanjiReadings::Kanji;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('kanji');
__PACKAGE__->columns(Primary=> qw(kanji));
__PACKAGE__->columns(Others => qw(rtk_frame rtk_keyword jlpt_grade jouyou_grade));

__PACKAGE__->has_many(kv_link => KanjiReadings::KanjiVocabLink);
__PACKAGE__->has_many(tallies => KanjiReadings::KanjiYomiTally);

####################

package KanjiReadings::Vocabulary;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('vocabulary');
__PACKAGE__->columns(Primary=> qw(vocab_id));
__PACKAGE__->columns(Others => qw(vocab_ja vocab_kana vocab_en jlpt_grade));

__PACKAGE__->has_many(kv_link => KanjiReadings::KanjiVocabLink);


####################

package KanjiReadings::Yomi;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('yomi');
__PACKAGE__->columns(Primary=> qw(yomi_id));
__PACKAGE__->columns(Others => qw(yomi_type yomi_kana yomi_hira));


###############################################################################
#
# All that follows is to be obsoleted..


package KanjiReadings::Vocab;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('vocab');
__PACKAGE__->columns(Primary  => 'vocab_id');
__PACKAGE__->columns(Others   => qw(vocab_ja vocab_kana vocab_en jlpt_grade));

####################

package KanjiReadings::KanjiInContext;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('kanji_in_context');
__PACKAGE__->columns(Primary  => qw(kic_id kanji vocab_id yomi_id));
__PACKAGE__->columns(Others   => qw(
                                    adj_yomi adj_kana adj_hira adj_type reason));

__PACKAGE__->has_a  (kanji    => 'KanjiReadings::Summary');
__PACKAGE__->has_a  (yomi_id  => 'KanjiReadings::OldYomi');
__PACKAGE__->has_a  (vocab_id => 'KanjiReadings::Vocab');

####################

package KanjiReadings::ReadingTally;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('reading_tallies');
__PACKAGE__->columns(Primary => qw(kanji read_type kana));
__PACKAGE__->columns(Others  => qw(hiragana exemplar raw_tally adj_tally));

__PACKAGE__->has_a  (kanji   => 'KanjiReadings::Summary');

####################

package KanjiReadings::OldVocabReading;
use base 'KanjiReadings::DBI';

__PACKAGE__->table('old_vocab_readings');
# The following are not actually primary keys, but we need to pretend
# they are so that Class::DBI will work properly when doing has_many
# from Summary table.
__PACKAGE__->columns(Primary => qw(kanji vocab_kanji vocab_kana reading_type
                                   jlpt_grade));
__PACKAGE__->columns(Others  => qw(reading_hira reading_kana
                                   adj_hira adj_type adj_kana ignore_flag));

__PACKAGE__->has_a  (kanji   => 'KanjiReadings::Summary');

####################

package KanjiReadings::OldYomi;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('yomi');
__PACKAGE__->columns(Primary  => qw(yomi_id kanji reading_kana));
__PACKAGE__->columns(Others   => qw( reading_type reading_hira));

__PACKAGE__->has_a  (kanji    => 'KanjiReadings::Summary');

####################

package KanjiReadings::YomiTally;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('yomi_tallies');
__PACKAGE__->columns(Primary  => qw(tally_id kanji yomi_id));
__PACKAGE__->columns(Others   => qw(raw_tally exemplar adj_tally ));

__PACKAGE__->has_a  (kanji    => 'KanjiReadings::Summary');
__PACKAGE__->has_a  (yomi_id  => 'KanjiReadings::OldYomi');

####################

package KanjiReadings::KanjiYomiLink;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('kanji_yomi_link');
__PACKAGE__->columns(Primary  => qw(kanji yomi_id));

__PACKAGE__->has_a  (kanji    => 'KanjiReadings::Summary');
__PACKAGE__->has_a  (yomi_id  => 'KanjiReadings::Yomi');

####################

package KanjiReadings::Summary;
use base 'KanjiReadings::DBI';

__PACKAGE__->table  ('summary');
__PACKAGE__->columns(Primary => 'kanji');
__PACKAGE__->columns(Others  => qw(heisig6_seq num_vocab  num_readings 
                                   num_failed adj_readings adj_failed));

__PACKAGE__->has_many(tallies => 'KanjiReadings::ReadingTally');
__PACKAGE__->has_many(vocab_readings => 'KanjiReadings::OldVocabReading',
    { order_by => vocab_kanji} );

# New tables
__PACKAGE__->has_many(yomi             => 'KanjiReadings::KanjiYomiLink');
__PACKAGE__->has_many(yomi_tallies     => 'KanjiReadings::YomiTally');
__PACKAGE__->has_many(kanji_in_context => 'KanjiReadings::KanjiInContext', "kanji");


1;
