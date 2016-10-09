# package for vocab window

package GUI::VocabDetails;

use Model::WebData;
use Model::KanjiReadings;
use Model::BreenDict;

use strict;
use warnings;

our $format = <<'_END';
+->-------------------------------------------+
^ Notes                                       |
|                                             |
|                                             |
|                                             |
+---------------------------------------------+
|                                             |
+--------------+>>>---------------------------+
' ShortEnglish ' EnglishEntry                 |
+--------------+------------------------------+
|                                             |
+--------------+---------+--------------------+
'   VocabMatchingKanji   '     Homonyms       |
+------------------------+--------------------+
^ MatchingVocabList      ^ HomonymList        |
+------------------------+--------------------+
_END
					       


sub new {
    my $class = shift;
    my %opts = (
	context => undef,
	vocabid => undef,
	death_hook => undef,
	toplevel => 0,
	@_,
    );

    my $vocabid = $opts{vocabid}
    or die "VocabDetails needs vocabid => num option\n";

    die "Don't supply us with a context" if defined $opts{context};

    my $context = Gtk2::Ex::FormFactory::Context->new;
    my $_vocab = KanjiReadings::Vocabulary->retrieve($vocabid);
    my $vocab_ja = $_vocab->vocab_ja;
    my $vocab_kana = $_vocab->vocab_kana;

    my $self = bless { context => $context, vocab_id => $vocabid,
		       toplevel => $opts{toplevel},
		       death_hook => $opts{death_hook},
		       _vocab => $_vocab,
		       vocab_ja => $vocab_ja,
		       vocab_kana => $vocab_kana,
    };

    # GUI attributes; won't use "depends" since FF won't be synchronous
    $context->add_object(
	name => "vocab",
	object => $self,
    );

    $self->build_window;
    $self->{ff}->open;
    $self->{ff}->update_all;

    return $self;
}


sub build_window {

    my $self = shift;
    my $context = $self->{context};

    $self->{ff} = Gtk2::Ex::FormFactory->new(
	sync    => 0,
	context => $context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new(
		title => "Editing Vocab $self->{vocab_ja} ($self->{vocab_kana})",
		height => 400,
		width => 600,
		expand => 1,
		content => [
		    $self->build_table,
		],
		closed_hook => sub {
		    $self->{ff}->ok();
		    if (defined $self->{death_hook}) {
			$self->{death_hook}->();
		    }
		}
	    )
	]
    );
}


sub build_table {
    my $self = shift;
    my $kanji = $self->{kanji};
    Gtk2::Ex::FormFactory::Table->new(
	expand => 1,
	layout => $format,
	content => [
	    Gtk2::Ex::FormFactory::TextView->new(label => "Notes", 
						 attr => "vocab.note"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Short definition", 
					      expand => 0),
	    Gtk2::Ex::FormFactory::Entry->new(attr  => "vocab.short_english",
					      expand => 1),
	    Gtk2::Ex::FormFactory::Label->new(label => "All definition(s)"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Homonyms"),
	    Gtk2::Ex::FormFactory::List->new(attr => "vocab.english_list",
					     columns => ['Source', 'Meaning'],
					     no_header => 0),
	    Gtk2::Ex::FormFactory::List->new(attr => "vocab.homonyms",
					     columns => ['Japanese', 'Meaning'],
					     no_header => 0),
	]
    );
}

sub get_short_english {
    my $self = shift;
    my $vocab = KanjiReadings::Vocabulary->retrieve($self->{vocab_id});
    $vocab->vocab_en;
}

sub set_short_english {
    my $self = shift;
    my $newvocab = shift;
    my $oldvocab = KanjiReadings::Vocabulary->retrieve($self->{vocab_id});

    return if $newvocab eq $oldvocab->vocab_en;
    $oldvocab->vocab_en($newvocab);
    $oldvocab->update;    
}

sub get_english_list {
    my $self = shift;
    my $iter = WebData::VocabByJLPTGrade->search(
	ja_regular => $self->{vocab_ja});
    my %sources = ();
    my @list = ();
    if ($iter) {
	my $data = $iter->next or die "Strange...\n";
	warn "Got multiple hits for $self->{vocab_ja} in web data database\n"
	    if $iter->next;
	$sources{tanos} = $data->en_tanos;
	$sources{edict} = $data->en_tagaini;
	$sources{jlpt} =  $data->en_jlpt;
	for my $key (qw(tanos jlpt edict)) {
	    for (split /,\s*/, $sources{$key}) {
		push @list, ["$key", $_ ]
	    }
	}
    } else {
	warn "Didn't find kanji $self->{vocab_ja} in web data database\n";
	# look up Edict instead
	$iter = BreenDict::JpnSearch->search(japanese => $self->{vocab_ja});
	die "Didn't find $self->{vocab_ja} in edict\n" unless $iter;
	while (my $data = $iter->next) {
	    my $ent_seq = $data->ent_seq;
	    my $sense_num = $data->rebkeb_num;
	    my $eng_iter = BreenDict::EngSearch->search(
		ent_seq => $ent_seq,
		sense_num => $sense_num);
	    my $eng_data = $eng_iter->next;
	    push @list, ["Edict", $eng_data->english ];
	    warn "Edict lookup returned more than one row\n"
		if $eng_iter->next;
	}
    }
    return \@list;
}

sub get_homonyms {
    my $self = shift;
    []
}

sub get_note {
    my $self = shift;
    Learnable::KanjiVocab->get_note(vocab_id => $self->{vocab_id});
}
sub set_note {
    my $self = shift;
    my $note = shift;
    warn "Setting vocab note to $note\n";
    Learnable::KanjiVocab->set_update_note($note, vocab_id => $self->{vocab_id});
}
    
1;
