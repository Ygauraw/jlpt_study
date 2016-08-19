#
# Interface to database containing compiled lists of kanji and vocabulary
# taken from:
#
# * www.tanos.co.uk
# * jlptstudy.net
# * tagaini jisho
#
# The schema file and script that populates the database contain
# comments on what each of the tables/fields here mean.


package WebData::DBI;
use base 'Class::DBI::SQLite';

__PACKAGE__->connection(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/uber/web_data.sqlite",'','',
    {   # does Class::DBI accept DBI/DBD options like below? Yes.
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 1,
    }
);

package WebData::KanjiByJLPTGrade;
use base 'WebData::DBI';

__PACKAGE__->table('kanji_by_jlpt_grade');
__PACKAGE__->columns(Primary => "kanji");
__PACKAGE__->columns(Others  =>
              qw/en_best en_jlpt en_tanos en_tagaini tanos_site_id
                 jlpt_level
                 jlpt_level_jlpt jlpt_level_tanos jlpt_level_tagaini/);

package WebData::KanjiReadings;
use base 'WebData::DBI';

__PACKAGE__->table('kanji_readings');
__PACKAGE__->columns(Primary => qw/kanji type kana/);
__PACKAGE__->columns(Others  => qw/popularity sightings/);

package WebData::VocabByJLPTGrade;
use base 'WebData::DBI';

__PACKAGE__->table('vocab_by_jlpt_grade');
__PACKAGE__->columns(Others  => 
		     qw/ja_regular ja_kana 
                        en_best en_jlpt en_tanos en_tagaini pos
                        jlpt_level
                        jlpt_level_jlpt jlpt_level_tanos jlpt_level_tagaini
                        tanos_site_id/);


1;
