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

