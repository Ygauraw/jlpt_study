package GUI::CoreTestWindow;

# GUI element to give a test on selected core vocabulary

use strict;
use warnings;

use Model::CoreTestList;

use Gtk2::Ex::FormFactory;
use FormFactory::AudioPlayer;

# basic accessors
sub get_context                 { shift->{context}                      }
sub get_form_factory            { shift->{form_factory}                 }

sub set_context                 { shift->{context}              = $_[1] }
sub set_form_factory            { shift->{form_factory}         = $_[1] }

sub get_answer_visibility       { shift->{answer_visibility}            }
sub set_answer_visibility       { shift->{answer_visibility}    = $_[1] }
sub get_test_description        { shift->{test_description}             }
sub set_test_description        { shift->{test_description}     = $_[1] }
sub get_progress_text           { shift->{progress_text}                }
sub set_progress_text           { shift->{progress_text}        = $_[1] }
sub get_challenge_text          { shift->{challenge_text}               }
sub set_challenge_text          { shift->{challenge_text}       = $_[1] }
sub get_answer_text             { shift->{answer_text}                  }
sub set_answer_text             { shift->{answer_text}          = $_[1] }
sub get_explain_button_text     { shift->{explain_button_text}          }
sub set_explain_button_text     { shift->{explain_button_text}  = $_[1] }



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
    my ($hbox, $audio, $answer);	# closure magic
    
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
+---------------------------------+
^ ButtonTable                     |
|                                 |
+---------------------------------+
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
		clicked_hook   => sub {$self->play_pause },
	    ),
	    $audio = Gtk2::Ex::FormFactory::AudioPlayer->new(
		# Might as well extend AudioPlayer to optionally
		# display text as well. Need more code here to send
		# either audio playlist or kanji text, depending on mode
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
		label => "This will be another box\nwith questions and\nbuttons/checkboxes"
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
    $audio->build_widget;	# apparently needed before we can
				# call set_text or set_playlist
    
    warn "Added audio " . ref($audio);
    $parent->add_child_widget($ff);

    $self->populate_from_model;

}

# Call this at the start and whenever we advance to the next test item
sub populate_from_model {

    my $self  = shift;
    my $model = $self->{model};

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
	$self->{audio}->set_text(
	    '<b>' .
	    $model->rec_vocab_kanji($index) .
	     ': </b>' .
	    $model->rec_sentence_ja_text($index) . "\n"
	    );
    }

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
