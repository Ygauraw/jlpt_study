#
# Class::DBI stuff for accessing Core database

package CoreVocab::DBI;
use base 'Class::DBI::SQLite';

# based partly on tutorial code that comes with FormFactory

# Should probably make DB connection string an option somewhere
# instead of hard-wiring it.

CoreVocab::DBI->connection(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/core_6000/core_2k_6k.sqlite",'','',
    {   # does Class::DBI accept DBI/DBD options like below? Yes.
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );

#sub accessor_name_for { "get_$_[1]" }
#sub mutator_name_for  { "set_$_[1]" }
sub autoupdate        { 1 }

# Whereas tables are set up with plural names (eg, "sounds"), objects
# will have singular names.

#################
package CoreVocab::Sound;
use base CoreVocab::DBI;

CoreVocab::Sound->table('sounds');
CoreVocab::Sound->columns(Primary => qw/id/);
CoreVocab::Sound->columns(Other   => qw/url type content_type local_filename audio/);

#################
package CoreVocab::Image;
use base CoreVocab::DBI;

CoreVocab::Image->table('images');
CoreVocab::Image->columns(All => qw/id url type content_type local_filename audio/);

#################
package CoreVocab::Vocab;
use base CoreVocab::DBI;

CoreVocab::Vocab->table('vocabulary');
CoreVocab::Vocab->columns(Primary => qw/id/);
CoreVocab::Vocab->columns(Other => qw/ja_text ja_kana ja_hira ja_romaji ja_alt
    en_text en_text_2k en_text_6k pos core_2k_seq sound_id/);

CoreVocab::Vocab->has_a(sound_id => 'CoreVocab::Sound');

#################
package CoreVocab::Sentence;
use base CoreVocab::DBI;

CoreVocab::Sentence->table('sentences');
CoreVocab::Sentence->columns(All => qw/id ja_text  ja_kana ja_hira ja_romaji ja_ruby 
    en_text en_text_2k en_text_6k sound_id image_id/);

# We have sound and images
CoreVocab::Sentence->has_a(sound_id => 'CoreVocab::Sound');
CoreVocab::Sentence->has_a(image_id => 'CoreVocab::Image');

#################
package CoreVocab::Core2k;
use base CoreVocab::DBI;

CoreVocab::Core2k->table('core_2k');
CoreVocab::Core2k->columns(All => qw/id ja_vocab ja_vocab_kana en_vocab vocab_id 
    main_sentence_id/);

# We have full vocab item (includes sound/image links) and a single sentence
CoreVocab::Core2k->has_a(vocab_id => 'CoreVocab::Vocab');
CoreVocab::Core2k->has_a(main_sentence_id => 'CoreVocab::Sentence');

#################
package CoreVocab::Core6kSentence;
use base CoreVocab::DBI;
CoreVocab::Core6kSentence->table('core_6k_sentences');

# This table has a a composite primary key
CoreVocab::Core6kSentence->columns(Primary => qw/core_6k_id sentence_id/);

# And it has one sentence, indexed by sentence_id
CoreVocab::Core6kSentence->has_a(sentence_id => 'CoreVocab::Sentence');

# It seems this sets up the reciprocal link for the foreign key used
# in Core6k. This class must come before that one.
CoreVocab::Core6kSentence->has_a(core_6k_id =>'CoreVocab::Core6k');

#################
package CoreVocab::Core6k;
use base CoreVocab::DBI;

CoreVocab::Core6k->table('core_6k');
CoreVocab::Core6k->columns(All => qw/id ja_vocab ja_vocab_kana en_vocab/);

# For has_many to work, we need to have the reciprocal has_a link
# set up prior to this
CoreVocab::Core6k->has_many(sentences => 'CoreVocab::Core6kSentence',
			    { order_by => 'sentence_id' });

1;
