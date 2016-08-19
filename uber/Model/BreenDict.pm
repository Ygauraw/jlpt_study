#
# Interface to SQL database containing data from Jim Breen's Edict
# dictionary file (XML version)
#

package BreenDict::DBI;
use base 'Class::DBI::SQLite';

__PACKAGE__->connection(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/dictionary/dict/jmdict.sqlite",'','',
    {   # does Class::DBI accept DBI/DBD options like below? Yes.
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 1,
    }
);

package BreenDict::Entries;
use base 'BreenDict::DBI';

__PACKAGE__->table('entries_by_sequence');
__PACKAGE__->columns(Primary => "ent_seq");
__PACKAGE__->columns(Others  => "yaml_entry");

package BreenDict::EngSearch;
use base 'BreenDict::DBI';

__PACKAGE__->table('eng_search');
__PACKAGE__->columns(Primary => qw(english ent_seq sense_num sense_cnt));

package BreenDict::JpnSearch;
use base 'BreenDict::DBI';

__PACKAGE__->table('jpn_search');
__PACKAGE__->columns(Primary => qw/japanese ent_seq rebkeb rebkeb_num rebkeb_cnt/);
