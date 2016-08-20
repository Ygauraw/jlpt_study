#
#

package Model::JPod;
use base 'Class::DBI::SQLite';

__PACKAGE__->connection(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/uber/jpodcasts.sqlite",'','',
    {   # does Class::DBI accept DBI/DBD options like below? Yes.
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 1,
    }
);


package JPod::EpisodeVocabLink;
use base 'Model::JPodCast';

__PACKAGE__->table('episode_vocab_link');	   
__PACKAGE__->columns(Primary => "link_id");
__PACKAGE__->columns(Others  => qw/episode_id vocab_id/);
				   
__PACKAGE__->has_a(episode_id => 'JPod::Episode');
__PACKAGE__->has_a(episode_id => 'JPod::Vocab');

package JPod::Episode;
use base 'Model::JPodCast';

__PACKAGE__->table('episodes');
__PACKAGE__->columns(Primary => "episode_id");
__PACKAGE__->columns(Others  => qw/series_id episode_num episode_dir episode_text
                     file_main file_dialogue file_review file_grammar file_bonus
                     file_other/);

__PACKAGE__->has_a(series_id => 'JPod::Series');
__PACKAGE__->has_many(vocab_links => 'JPod::EpisodeVocabLink');

package JPod::Series;
use base 'Model::JPodCast';

__PACKAGE__->table('series');
__PACKAGE__->columns(Primary => "series_id");
__PACKAGE__->columns(Others  => qw/series_dir series_text ignore_flag/);

__PACKAGE__->has_many(episodes => 'JPod::Episode');

package JPod::VocabReading;
use base 'Model::JPodCast';

__PACKAGE__->table('vocab_reading');	   
__PACKAGE__->columns(Primary => qw/vocab_id english romaji kana/);
				   
__PACKAGE__->has_a(vocab_id => 'JPod::VocabJA');

package JPod::VocabJA;
use base 'Model::JPodCast';

__PACKAGE__->table('vocab_ja');	   
__PACKAGE__->columns(Primary => "vocab_id");
__PACKAGE__->columns(Others  => qw/japanese/);
				   
__PACKAGE__->has_many(readings => 'JPod::VocabReading');

package JPod::SeriesStatus;
use base 'Model::JPodCast';

__PACKAGE__->table('series_status');	   
__PACKAGE__->columns(Primary => "series_id");
__PACKAGE__->columns(Others  => qw/difficulty priority series_note/);
				   
__PACKAGE__->has_a(series_id => 'JPod::Series');

package JPod::EpisodeStatus;
use base 'Model::JPodCast';

__PACKAGE__->table('episode_status');
__PACKAGE__->columns(Primary => "episode_id");
__PACKAGE__->columns(Others  => qw/play_count learn_status short_note episode_note/);
				   
__PACKAGE__->has_a(episode_id => 'JPod::Episode');


package JPod::EpisodeVocabStatus;
use base 'Model::JPodCast';

__PACKAGE__->table('episode_vocab_status');
__PACKAGE__->columns(Primary => 'link_id');
__PACKAGE__->columns(Others  => qw/short_note learn_status
		jk_status js_status je_status kj_status ks_status ke_status
		sj_status sk_status se_status ej_status ek_status es_status /);
				
__PACKAGE__->has_a(link_id => 'JPod::EpisodeVocabLink');

1;
