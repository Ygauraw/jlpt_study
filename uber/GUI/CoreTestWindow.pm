package GUI::CoreTestWindow;

# GUI element to give a test on selected core vocabulary

use Model::CoreTestList;

use Gtk2::Ex::FormFactory;
use FormFactory::AudioPlayer;

# basic accessors
sub get_context                 { shift->{context}                      }
sub get_form_factory            { shift->{form_factory}                 }

sub set_context                 { shift->{context}              = $_[1] }
sub set_form_factory            { shift->{form_factory}         = $_[1] }

sub get_selected_test_id        { shift->{selected_test_id}             }
sub set_selected_test_id        { shift->{selected_test_id}     = $_[1] }

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
	model_obj  => undef,	# object containing the test data
	context    => undef,	# probably required
	toplevel   => 1,	# when set, quit when window closed
	@_,	
	);

    my $self = {
	test_id   => undef,
	context   => $o{context},
	ff        => undef,
	toplevel  => $o{toplevel},
    };
    
    bless $self, $class;
}


sub build {

    my $self    = shift;
    my $context = $self->{context};
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
		],
	    )
	]
	);

    $self->build_table;
    
    $ff->open;
    $ff->update;
}

sub build_table {

    my $self = shift;
    my $parent = $self->{win};
    
    my $ff = Gtk2::Ex::FormFactory::Table->new(
	title  => "Core Vocabulary Tester",
	expand => 1,
	layout => <<'END_TABLE', # must use camel case
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
' HSeparator                      |
+---------------------------------+
^ Answer                          |
|                                 |
+->-------------------------------+
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
	content => [
	    Gtk2::Ex::FormFactory::Label->new(label => "Describe the Test"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Completed X of Y"),
	    Gtk2::Ex::FormFactory::HSeparator->new(label => "Space after description"),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "Either listen -> write or read -> understand"),
	    Gtk2::Ex::FormFactory::Button->new(
		stock          => "gtk-media-play",
		label          => "",
		clicked_hook   => sub {},
	    ),
	    Gtk2::Ex::FormFactory::AudioPlayer->new(
		# Might as well extend AudioPlayer to optionally
		# display text as well. Need more code here to send
		# either audio playlist or kanji text, depending on mode
		),
	    Gtk2::Ex::FormFactory::HSeparator->new(label => "Correct Answers"),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "This is where the answer goes"),
	    Gtk2::Ex::FormFactory::HSeparator->new(label => "Your Answers"),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "Did you get the following questions right?"
	    ),
	    Gtk2::Ex::FormFactory::Label->new(
		label => "This will be another box with questions and buttons/checkboxes"
	    ),
	    Gtk2::Ex::FormFactory::Button->new(
		label          => "Show Answer/Next Question",
		clicked_hook   => sub {},
	    ),
#	    Gtk2::Ex::FormFactory::Label->new(label => "extra widget"),
	],
	);

    $parent->add_child_widget($ff);

}


1;
