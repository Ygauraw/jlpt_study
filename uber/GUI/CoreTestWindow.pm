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
    qw(context answer_visibility test_description progress_text
       challenge_text answer_text explain_button_text 
       question_text_1 question_text_2 yesno_1 yesno_2
       question_text_3 question_text_4 yesno_3 yesno_4
       items_tested items_total
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
	close_hook => undef,	# notify parent when we close our window
	@_,
	);
    my $id = $o{id};
    die unless defined $id;

    die if defined($o{close_hook}) and ref($o{close_hook}) ne "CODE";

    my $model        = $o{model_obj};
    die "Expected model to be a CoreTestQA object" 
	unless ref($model) eq 'Model::CoreTestQA';
    my $items_tested = $model->get_items_tested;
    my $items_total  = $model->get_items_total;
    if ($items_tested >= $items_total) {
	die "The chosen test object has already been completed";
    }

    # Put a trailing / on uri_base if it doesn't already have one
    $o{uri_base} =~ s|^(.+?)([^/])$|$1$2/|;
    
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
	close_hook   => $o{close_hook},
	need_db_update => 0,
    };

    
    bless $self, $class;
    
    # Set up some default (mostly dummy) values for Label widgets
    $self->set_answer_visibility       (0); # 'invisible');
    $self->set_test_description        ("Describe the Test");
    $self->set_progress_text           ("Completed X of Y");
    $self->set_challenge_text          ("Either listen -> write or read -> understand");
    $self->set_answer_text             ("This is where the answer goes");
    $self->set_explain_button_text     ("Answer the following questions:");

    warn "Answer visibility is " . $self->get_answer_visibility . "\n";
    
    $self;
}

# Not the correct way to remove ourselves... called too late
sub DESTROY {
    my $self = shift;
    warn "DESTROY $self->{name}, " . ref($self) . "\n";
}

# An explicit cleanup call is better
sub cleanup {
    my $self = shift;
    warn "Cleanup " . ref($self) . "\n";
    
    # update database counts and remove from context
    $self->{model}->update_answer_summary if $self->{need_db_update};
    $self->{context}->remove_object($self->{name});

    # have a death callback?
    my $callback = $self->{close_hook};
    if (defined($callback)) {
	warn "Calling user-supplied death callback\n";
	&$callback();
    };
}

sub build {

    my $self    = shift;
    my $context = $self->{context};
    my $name    = $self->{name};

    $context->add_object(
	name   => $name,
	object => $self,
	attr_depends_href => {
	    answer_text => "answer_visibility",
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
		closed_hook => sub {
		    warn "Test window $self->{name} is closing (closed_hook)\n";
		    $self->cleanup;
		    return 0;
		},
		content => [
		    $self->{vbox} = Gtk2::Ex::FormFactory::VBox->new(expand =>1)
		],
	    )
	]
	);

    $ff->open;
    $self->build_table;

    if ($self->{reload}) {
	$self->{vbox}->add_child_widget(
	    Gtk2::Ex::FormFactory::Button->new(
		label => 'Reload Program',
		clicked_hook => sub { exec $0, @ARGV or die },
	    ),
	)
    }

    $ff->update;
}

sub show {
    warn "got a call to show a window\n";
    # Things are complicated because the following just gets a VBox
    # rather than the window. Boo Hiss.
    #
    #    shift->{win}->get_gtk_widget->window_present;
    shift->{ff}->open; # this doesn't raise the window either
}

sub build_table {

    my $self     = shift;
    my $parent   = $self->{vbox};
    my $name     = $self->{name};
    my $context  = $self->{context};
    my ($hbox, $audio, $answer, $form);	# closure magic
    
    my $ff = Gtk2::Ex::FormFactory::Table->new(
	title   => "Core Vocabulary Tester",
	context => $context,
	expand  => 1,
	layout  => <<'END_TABLE', # must use camel case within (no _)
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
^ ButtonText2   ^   YesNo2        |
+---------------+-------------->--+
^ ButtonText3   |   YesNo3        |
+---------------+-------------->--+
^ ButtonText4   ^   YesNo4        |
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
	    my $play_button = Gtk2::Ex::FormFactory::Button->new(
		stock          => "gtk-media-play",
		label          => "",
		clicked_hook   => sub { $audio->play_pause },
		active_cond    => sub {
		    $self->{model}->get_challenge_mode eq "sound"
			or $self->get_answer_visibility
		},
	    ),
	    $audio = Gtk2::Ex::FormFactory::AudioPlayer->new(
		# Might as well extend AudioPlayer to optionally
		# display text as well. Need more code here to send
		# either audio playlist or kanji text, depending on mode
		debug => 0,
		# URI base should come from outside (not defined in GUI)
		uri_base => $self->{uri_base},
		initial_play_state =>
		$self->{model}->get_challenge_mode() eq "sound" ?
		"play" : "pause",
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
#		active_depends => "$name.answer_visibility",
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
		with_markup => 1,
	    ),
	    Gtk2::Ex::FormFactory::YesNo->new(
		attr  => "$name.yesno_1",
	    ),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "Question 2",
		attr  => "$name.question_text_2",
		with_markup => 1,
	    ),
	    Gtk2::Ex::FormFactory::YesNo->new(
		attr  => "$name.yesno_2",
	    ),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "Question 3",
		attr  => "$name.question_text_3",
		with_markup => 1,
	    ),
	    Gtk2::Ex::FormFactory::YesNo->new(
		attr  => "$name.yesno_3",
	    ),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "Question 4",
		attr  => "$name.question_text_4",
		with_markup => 1,
	    ),
	    Gtk2::Ex::FormFactory::YesNo->new(
		attr  => "$name.yesno_4",
	    ),
	    Gtk2::Ex::FormFactory::Button->new(
		label          => "Show Answer/Next Question",
		clicked_hook   => sub { 
		    $self->next_button_hook($audio, $answer);
		},
	    ),
#	    Gtk2::Ex::FormFactory::Label->new(label => "extra widget"),
	],
	);
    $self->{audio} = $audio;
    $self->{play_button} = $play_button;
    $parent->add_child_widget($ff);
    $self->populate_from_model;
}

sub next_button_hook {

    my ($self, $audio, $answer) = @_;
    my $context = $self->{context};
    my $name    = $self->{name};

    # Update this to set a context attribute controlling whether the
    # play button is functional or not

    my $show_answer = $self->{answer_visibility} ^=1;
    $context->set_object_attr("$name.answer_visibility", $show_answer);
    $self->{play_button}->update;

    if ($show_answer) {
	if ($self->{model}->get_challenge_mode eq "kanji") {
	    $audio->play;
	}
    } else {
	# save answers in DB
	$self->{need_db_update} = 1; # write summary during cleanup
	my %answer_attrs = (
	    item_index         => $self->{index},
	    correct_voc_know   => 0,
	    correct_voc_read   => 0,
	    correct_voc_write  => 0,
	    correct_sen_know   => 0,
	    correct_sen_read   => 0,
	    correct_sen_write  => 0,
	);
	$answer_attrs{$self->{q1_attribute}} = $self->get_yesno_1;
	$answer_attrs{$self->{q2_attribute}} = $self->get_yesno_2;
	$answer_attrs{$self->{q3_attribute}} = $self->get_yesno_3;
	$answer_attrs{$self->{q4_attribute}} = $self->get_yesno_4;
	$self->{model}->save_answers(%answer_attrs);
	warn "Got back from save_answers\n";

	# See if we're finished
	if (++$self->{items_tested} >= $self->get_items_total) {
	    # Move updating summary into window close callback
	    #	    $self->{model}->update_answer_summary;

	    # It appears that the following doesn't call our
	    # closed_hook and ->destroy isn't an option.
	    warn "All questions answered:\n  * closing window\n";
	    $self->{ff}->close;

	    warn " * doing cleanup\n";
	    $self->cleanup;

	    my $toplevel = $self->{toplevel};
	    Gtk2::main_quit if $toplevel;
	    return 0;
	}
	$self->populate_from_model;
	$self->{ff}->update;
    }
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
    return $listref if $uri_base eq '';
    # warn $uri_base;
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
	die "Advanced past last answered question"
	    if ++$index > $self->{items_total};
    } while ($model->rec_answered($index));
    $self->{index} = $index;

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

    # Populate playlist
    if ($mode eq "kanji") {
	$audio->set_play_state("pause");
    } elsif ($mode eq "sound") {
	$audio->set_play_state("play");
    }
    $audio->set_playlist(
	$self->localise_playlist($model->rec_playlist($index)));
    if ($mode eq "sound") {
	$audio->play;
    }

    # Setting challenge text/audio will require updates to AudioPlayer
    if ($mode eq "kanji") {
	$audio->set_text(
	    '<span size="x-large"><b>' .
	    $model->rec_vocab_kanji($index) .
	     ': </b></span>' .
	    $model->rec_sentence_ja_text($index) . "\n"
	    );
    } elsif ($mode eq "sound") {
	$audio->set_text('[Audio]');
    } else { die "Invalid challenge mode" }
   
    # Set up answer/response section
    my $answer_part = "\n" . '<span size="x-large"><b>' .
	$model->rec_vocab_kanji($index) .
	"</b> (" . $model->rec_vocab_kana($index) . "): ".
	$model->rec_vocab_en($index) . "\n\n" .
	$model->rec_sentence_ja_text($index) . "\n" .
	$model->rec_sentence_en_text($index) . "\n\n" .
	$model->rec_sentence_ja_kana($index) . "\n</span>";

    $self->set_answer_text($answer_part);

    # Text for questions. Select four out of six, depending on mode
    #	correct_voc_know  
    #	correct_voc_read  
    #	correct_voc_write 
    #	correct_sen_know  
    #	correct_sen_read  
    #	correct_sen_write 

    my %texts = (
	vr => "<b>Vocab Reading</b>: Were you able to read the vocab element?",
	vw => "<b>Vocab Writing</b>: Were you able to write the vocab element?",
	vm => "<b>Vocab Meaning</b>: Did you know the vocab's English meaning?",
	sr => "<b>Sentence Reading</b>: Were you able to read the full sentence?",
	sw => "<b>Sentence Reading</b>: Were you able to write the full sentence?",
	sm => "<b>Sentence Meaning</b>: Did you know the sentence's English meaning?",
	);
    
    if ($mode eq "kanji") {

	$self->set_question_text_1($texts{vr});
	$self->{q1_attribute} = "correct_voc_read";
	$self->set_question_text_2($texts{vm});
	$self->{q2_attribute} = "correct_voc_know";
	$self->set_question_text_3($texts{sr});
	$self->{q3_attribute} = "correct_sen_read";
	$self->set_question_text_4($texts{sm});
	$self->{q4_attribute} = "correct_sen_know";
    } else {
	$self->set_question_text_1($texts{vw});
	$self->{q1_attribute} = "correct_voc_write";
	$self->set_question_text_2($texts{vm});
	$self->{q2_attribute} = "correct_voc_know";
	$self->set_question_text_3($texts{sw});
	$self->{q3_attribute} = "correct_sen_write";
	$self->set_question_text_4($texts{sm});
	$self->{q4_attribute} = "correct_sen_know";
    }

    $self->set_yesno_1(0);
    $self->set_yesno_2(0);
    $self->set_yesno_3(0);
    $self->set_yesno_4(0);

    $self->{ff}->update;
}

1;
