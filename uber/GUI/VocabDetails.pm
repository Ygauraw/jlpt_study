# package for vocab window

package GUI::VocabDetails;

our $format = <<'_END';
+---------------------------------------------+
| Notes                                       |
|                                             |
|                                             |
|                                             |
|                                             |
|                                             |
+------------------------+--------------------+
|   VocabMatchingKanji   |     Homonyms       |
+------------------------+--------------------+
| MatchingVocabList      | HomonymList        |
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

    my $self = bless { context => $context, vocabid => $vocabid,
		       toplevel => $opts{toplevel},
		       death_hook => $opts{death_hook},
		       _vocab => $_vocab,
		       vocab_ja => $vocab_ja,
    };

    # GUI attributes; won't use "depends" since FF won't be synchronous
    $context->add_object(
	name => $basename,
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
    my $basename = $self->{basename};

    $context->add_object(
	name => "gui",
	object => $self
    );

    $self->{ff} = Gtk2::Ex::FormFactory->new(
	sync    => 0,
	context => $context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new(
		title => "Editing Vocab . $self->{vocab_ja}",
		height => 400,
		width => 600,
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
    my $basename = $self->{basename};
    warn "Basename is $basename\n";
    Gtk2::Ex::FormFactory::Table->new(
	expand => 1,
	layout => $format,
	content => [
	    Gtk2::Ex::FormFactory::Label->new(label => "Notes"),
	    Gtk2::Ex::FormFactory::Label->new(label => "VocabMatchingKanji"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Homonyms"),
	    Gtk2::Ex::FormFactory::Label->new(label => "MatchingVocabList"),
	    Gtk2::Ex::FormFactory::Label->new(label => "HomonymList"),
	]
    );
}

1;
