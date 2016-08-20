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

sub begin_work {
    my $self = shift;
    $self->db_Main->begin_work;
    }

sub end_work {
    my $self = shift;
    $self->db_Main->commit;
    }

sub dbh { shift -> db_Main }

sub tables {
    qw(
      series
      episodes
      vocab_reading
      vocab_ja
      episode_vocab_link
      series_status
      episode_status
      episode_vocab_status
    )
}

sub Tables {
    qw(
      JPod::VocabReading
      JPod::VocabJA
      JPod::Episode
      JPod::EpisodeVocabLink
      JPod::Series
      JPod::SeriesStatus
      JPod::EpisodeStatus
      JPod::EpisodeVocabStatus
    )
}

package JPod::EpisodeVocabLink;
use base 'Model::JPod';

__PACKAGE__->table('episode_vocab_link');	   
__PACKAGE__->columns(Primary => "link_id");
__PACKAGE__->columns(Others  => qw/episode_id vocab_id/);
				   
__PACKAGE__->has_a(episode_id => 'JPod::Episode');
__PACKAGE__->has_a(vocab_id   => 'JPod::Vocab');

package JPod::EpisodeOtherAudio;
use base 'Model::JPod';

__PACKAGE__->table('episode_other_audio');
__PACKAGE__->columns(Primary => qw(episode_id audio_type audio_file));

__PACKAGE__->has_a(episode_id => 'JPod::Episode');

package JPod::EpisodeTextFile;
use base 'Model::JPod';

__PACKAGE__->table('episode_text_files');
__PACKAGE__->columns(Primary => qw(episode_id file title contents));

__PACKAGE__->has_a(episode_id => 'JPod::Episode');

package JPod::Episode;
use base 'Model::JPod';

__PACKAGE__->table('episodes');
__PACKAGE__->columns(Primary => "episode_id");
__PACKAGE__->columns(Others  => qw/series_id episode_seq episode_dir episode_desc
                     main_audio/);

__PACKAGE__->has_a(series_id => 'JPod::Series');
__PACKAGE__->has_many(vocab_links => 'JPod::EpisodeVocabLink');
__PACKAGE__->has_many(other_audio => 'JPod::EpisodeOtherAudio');
__PACKAGE__->has_many(text_files  => 'JPod::EpisodeTextFile');

package JPod::Series;
use base 'Model::JPod';

__PACKAGE__->table('series');
__PACKAGE__->columns(Primary => "series_id");
__PACKAGE__->columns(Others  => qw/series_dir series_text ignore_flag/);

__PACKAGE__->has_many(episodes => 'JPod::Episode');

package JPod::VocabReading;
use base 'Model::JPod';

__PACKAGE__->table('vocab_reading');	   
__PACKAGE__->columns(Primary => qw/vocab_id english romaji kana/);
				   
__PACKAGE__->has_a(vocab_id => 'JPod::VocabJA');

package JPod::VocabJA;
use base 'Model::JPod';

__PACKAGE__->table('vocab_ja');	   
__PACKAGE__->columns(Primary => "vocab_id");
__PACKAGE__->columns(Others  => qw/japanese/);
				   
__PACKAGE__->has_many(readings => 'JPod::VocabReading');

package JPod::SeriesStatus;
use base 'Model::JPod';

__PACKAGE__->table('series_status');	   
__PACKAGE__->columns(Primary => "series_id");
__PACKAGE__->columns(Others  => qw/difficulty priority series_note/);
				   
__PACKAGE__->has_a(series_id => 'JPod::Series');

package JPod::EpisodeStatus;
use base 'Model::JPod';

__PACKAGE__->table('episode_status');
__PACKAGE__->columns(Primary => "episode_id");
__PACKAGE__->columns(Others  => qw/play_count learn_status short_note episode_note/);
				   
__PACKAGE__->has_a(episode_id => 'JPod::Episode');


package JPod::EpisodeVocabStatus;
use base 'Model::JPod';

__PACKAGE__->table('episode_vocab_status');
__PACKAGE__->columns(Primary => 'link_id');
__PACKAGE__->columns(Others  => qw/short_note learn_status
		jk_status js_status je_status kj_status ks_status ke_status
		sj_status sk_status se_status ej_status ek_status es_status /);
				
__PACKAGE__->has_a(link_id => 'JPod::EpisodeVocabLink');

1;
