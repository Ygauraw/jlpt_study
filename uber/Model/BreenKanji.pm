#
# Interface to SQL database containing kanji from Jim Breen's Edict
# kanjidic2 file
#

package BreenKanji::DBI;
use base 'Class::DBI::SQLite';

__PACKAGE__->connection(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/dictionary/kanji/kanjidic2.sqlite",'','',
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 1,
    }
);
sub autocommit {1};
1;

package BreenKanji::Entry;
use base 'BreenKanji::DBI';

__PACKAGE__->table('entries_by_literal');
__PACKAGE__->columns(Primary => "literal");
__PACKAGE__->columns(Others  => qw/heisig6 frequency jlpt jouyou yaml_entry/);

package BreenKanji::EngMeaning;
use base 'BreenKanji::DBI';

__PACKAGE__->table('english_meanings');
__PACKAGE__->columns(Primary => qw(literal));
__PACKAGE__->columns(Others  => qw(english));

package BreenKanji::KanjiReading;
use base 'BreenKanji::DBI';

__PACKAGE__->table('on_kun_readings');
__PACKAGE__->columns(Primary => qw/literal type text/);
__PACKAGE__->columns(Others  => qw/kun_dict_form/);

1;
