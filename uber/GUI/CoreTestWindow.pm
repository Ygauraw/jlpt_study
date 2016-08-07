package GUI::CoreTestWindow;

# GUI element to give a test on selected core vocabulary

use strict;
use warnings;
use Carp;

use Model::CoreTestList;

use Gtk2::Ex::FormFactory;
use FormFactory::AudioPlayer;

our $AUTOLOAD;
our %get_set_attr = (
    map { ($_ => undef) } 
    qw(context form_factory answer_visibility test_description progress_text
       challenge_text answer_text explain_button_text 
       question_text_1 question_text_2 yesno_1 yesno_2
    ));
sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    if ($attr =~ s/^.*::get_//) {
        croak "Method get_$attr not registered for autoloading"
            unless exists $get_set_attr{$attr};
        return $self->{$attr};
    }
    if ($attr =~ s/^.*::set_//) {
        croak "Method set_$attr not registered for autoloading"
            unless exists $get_set_attr{$attr};
        return $self->{$attr}=shift;
    }

    croak "Method $attr does not exist";
}

# Organise things a little differently from CoreTestList.pm. We won't
# create a context, for a start. Instead, we'll take an existing one,
# store it and (if needed) register our own attributes or whatever
# with it. This is to make it easier for us to integrate this GUI
# element within a larger program.
# 
sub new {
    my $class = shift;
    my %o = (
	id         => undef,	# required, used to suffix object name
	model_obj  => undef,	# object containing the test questions/answers
	context    => undef,	# probably required
	toplevel   => 1,	# when set, quit when window closed
	reload     => 0,	# whether to add a reload button (for testing)
	uri_base   => '',
	@_,
	);

    my $id = $o{id} = 1;
    
    my $model        = $o{model_obj};
    my $items_tested = $model->get_items_tested;
    my $items_total  = $model->get_items_total;
    if ($items_tested >= $items_total) {
	die "The passed test object has already been completed";
    }

    my $self = {
	test_id      => undef,
	context      => $o{context},
	ff           => undef,
	toplevel     => $o{toplevel},
	reload       => $o{reload},
	model        => $model,
	uri_base     => $o{uri_base},
	# set unique object name based on ID
	name         => "core_test_window_$id",
	index        => 0,	# which test item are we doing?
	items_total  => $items_total,
	items_tested => $items_tested,
    };

    
    bless $self, $class;
    
    # Set up some default (mostly dummy) values for Label widgets
    $self->set_answer_visibility       (0); # 'invisible');
    $self->set_test_description        ("Describe the Test");
    $self->set_progress_text           ("Completed X of Y");
    $self->set_challenge_text          ("Either listen -> write or read -> understand");
    $self->set_answer_text             ("This is where the answer goes");
    $self->set_explain_button_text     ("Did you get the following questions right?");

    warn "Answer visibility is " . $self->get_answer_visibility . "\n";
    
    $self;
}


sub build {

    my $self    = shift;
    my $context = $self->{context};
    my $name    = $self->{name};

    $context->add_object(
	name   => $name,
	object => $self,
	attr_depends_href => {
	    answer_text => ["answer_visibility", ],
	},
	);

    $self->{ff} = my $ff = Gtk2::Ex::FormFactory->new (
	context => $context,
	content => [
	    $self->{win} = Gtk2::Ex::FormFactory::Window->new (
		title   => " Vocabulary Tester",
		properties => {
		    default_width  => 640,
		    default_height => 640,
		},
		quit_on_close => $self->{toplevel},
		content => [
		    $self->{vbox} = Gtk2::Ex::FormFactory::VBox->new (expand=>1)
		],
	    )
	]
	);

    $self->build_table;

    if ($self->{reload}) {
	$self->{vbox}->add_child_widget(
	    Gtk2::Ex::FormFactory::Button->new(
		label => 'Reload Program',
		clicked_hook => sub { exec $0, @ARGV or die },
	    ),
	)
	    
    }
    
    $ff->open;
    $ff->update;
}

sub build_table {

    my $self     = shift;
    my $parent   = $self->{vbox};
    my $name     = $self->{name};
    my $context  = $self->{context};
    my ($hbox, $audio, $answer, $form);	# closure magic
    
    my $ff = Gtk2::Ex::FormFactory::Table->new(
	title  => "Core Vocabulary Tester",
	expand => 1,
	layout => <<'END_TABLE', # must use camel case within (no _)
+>>>>>>>>>>>>>>>+---------------]-+
| Description   |          XofY   |
|               |                 |
+->-------------+-----------------+
' HSeparator                      |
+->------------------+-%----------+
| ItemInstructions   ~ PlayPause  |
|                    |            |
+->------------------+            |
^ Challenge          |            |
|                    |            |
+->------------------+------------+
| HSeparator                      |
+->---------+[--------------------+
|           |                     |
'           '                     |
|Answer     | Align               |
|           |                     |
|           |                     |
+-----------+---------------------+
' HSeparator                      |
+---------------------------------+
'                                 |
| ButtonExplanation               |
+---------------+-------------->--+
^ ButtonText1   |   YesNo1        |
+---------------+-------------->--+
^ ButtonText2   |   YesNo2        |
+---------------+-----------------+
|        AnswerNextButton         |
+---------------------------------+
END_TABLE
# '
	content => [
	    Gtk2::Ex::FormFactory::Label->new(
		attr   => "$name.test_description",
	    ),
	    Gtk2::Ex::FormFactory::Label->new(
		attr  => "$name.progress_text",
	    ),
	    Gtk2::Ex::FormFactory::HSeparator->new(label => "Space after description"),
	    Gtk2::Ex::FormFactory::Label->new(
		attr   => "$name.challenge_text",
	    ),
	    Gtk2::Ex::FormFactory::Button->new(
		stock          => "gtk-media-play",
		label          => "",
		clicked_hook   => sub {$audio->play_pause },
	    ),
	    $audio = Gtk2::Ex::FormFactory::AudioPlayer->new(
		# Might as well extend AudioPlayer to optionally
		# display text as well. Need more code here to send
		# either audio playlist or kanji text, depending on mode
		debug => 1,
		# The following value really shouldn't go in a GUI
		uri_base => $self->{uri_base},
		),
	    Gtk2::Ex::FormFactory::HSeparator->new(label => "Correct Answers"),
	    # I can't get an "invisible" answer text to work within a
	    # container so I'm making an alignment container beside it
	    # and giving it a fixed size to prevent the whole widget
	    # from resizing when I hide/show the answer text.
	    $answer = Gtk2::Ex::FormFactory::Label->new(
		attr  => "$name.answer_text",
		with_markup => 1,
		inactive => 'invisible',
		# The below doesn't work so I have to use active_cond instead
		#active_depends => "$name.answer_visibility",
		active_cond => sub { $self->get_answer_visibility },
	    ),
	    Gtk2::Ex::FormFactory::HBox->new( # alignment container
		height => 180,
		width  => 1
	    ),
	    Gtk2::Ex::FormFactory::HSeparator->new(label => "Your Answers"),
	    Gtk2::Ex::FormFactory::Label->new(
		attr  => "$name.explain_button_text",
	    ),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "Question 1",
		attr  => "$name.question_text_1",
	    ),
	    Gtk2::Ex::FormFactory::YesNo->new(
		attr  => "$name.yesno_1",
	    ),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "Question 2",
		attr  => "$name.question_text_2",
	    ),
	    Gtk2::Ex::FormFactory::YesNo->new(
		attr  => "$name.yesno_2",
	    ),
	    Gtk2::Ex::FormFactory::Button->new(
		label          => "Show Answer/Next Question",
		clicked_hook   => sub {
		    $self->{answer_visibility} ^=1;
		    $answer->update;
		    $self->next_button 
		},
	    ),
#	    Gtk2::Ex::FormFactory::Label->new(label => "extra widget"),
	],
	);

    $self->{audio} = $audio;
#    $audio->build_widget;	# apparently needed before we can
#				# call set_text or set_playlist

#    warn "Added audio " . ref($audio);
    $parent->add_child_widget($ff);

    $self->populate_from_model;
}

# If we have been given a URI base to pass to the audio player, then
# the local path names in the database need to be rewritten so that
# full path (from db) = uri base + relative name (returned from here)
sub localise_playlist {
    my $self     = shift;
    my $uri_base = $self->{uri_base};
    my $listref  = shift;
    my $newlist  = [];		# use a new list instead of modifying
				# the old one. Old list might
				# accidentally have db accessor, which
				# we don't want to cause changes to db
    warn $uri_base;
    foreach my $fn (@$listref) {
	my $urised = "file://$fn";
	my $front = substr $urised, 0, length $uri_base, '';
	if ($front eq $uri_base) {
	    warn "Matched against URI base; local is $urised\n";
	    push @$newlist, $urised;
	} else {
	    warn "No match against URI base $uri_base; ($urised)\n";
	    push @$newlist, $fn;
	}

    }
    return $newlist;    
}

# Call this at the start and whenever we advance to the next test item
sub populate_from_model {

    my $self  = shift;
    my $model = $self->{model};
    my $audio = $self->{audio};

    # advance to the next unanswered question
    my $index = $self->{index};	# starts at 0
    do {
	die if ++$index > $self->{items_total};
    } while ($model->rec_answered($index));

    my $mode     = $model->get_challenge_mode;
    my $test_set = $model->get_test_set;

    $test_set =~ s/(core|test)(\d)k/Testing a selection of Core $2,000 Vocab/;
    $self->set_test_description($test_set);

    $self->set_challenge_text(
	$mode eq "sound" ?
	"Listen to the audio to test your writing ability.\n" :
	"Read the text below to test your reading ability.\n");

    $self->set_progress_text(
	"Answered $self->{items_tested}/$self->{items_total}");

    # Setting challenge text/audio will require updates to AudioPlayer
    if ($mode eq "kanji") {
	$audio->set_auto_play(0);
	$audio->set_text(
	    '<b>' .
	    $model->rec_vocab_kanji($index) .
	     ': </b>' .
	    $model->rec_sentence_ja_text($index) . "\n"
	    );
    } elsif ($mode eq "sound") {
	$audio->set_auto_play(1);
	$audio->set_text('');
    } else { die }
    # Populate playlist
    $audio->set_playlist(
	$self->localise_playlist($model->rec_playlist($index)));
    
    # Set up answer/response section
    my $answer_part = "\n" . '<span size="x-large"><b>' .
	$model->rec_vocab_kanji($index) .
	"</b> (" . $model->rec_vocab_kana($index) . "): ".
	$model->rec_vocab_en($index) . "\n\n" .
	$model->rec_sentence_ja_text($index) . "\n" .
	$model->rec_sentence_en_text($index) . "\n\n" .
	$model->rec_sentence_ja_kana($index) . "\n</span>";

    $self->set_answer_text($answer_part);
    
}

1;
