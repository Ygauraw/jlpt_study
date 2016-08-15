package GUI::CoreTestList;

use Model::CoreTestList;
use Model::CoreTestQA;
    
use GUI::CoreTestWindow;

use strict;
use warnings;

# basic accessors
sub get_context                 { shift->{context}                      }
sub get_form_factory            { shift->{form_factory}                 }

sub set_context                 { shift->{context}              = $_[1] }
sub set_form_factory            { shift->{form_factory}         = $_[1] }

sub get_selected_test_id        { shift->{selected_test_id}             }
sub set_selected_test_id        { shift->{selected_test_id}     = $_[1] }

# constructor registers objects with new/passed FormFactory::Context
sub new {
    my $class = shift;
    my %o = (
	context => undef,
	reload  => 0,
	buttons => 1,
	@_
    );
    my ($self, $context);
    if (defined($o{context})) {
	$context = $o{context};
    } else {
	$context = Gtk2::Ex::FormFactory::Context->new;
    }
    $self = bless { 
	context => $context,
	reload  => $o{reload},
	buttons => $o{buttons},
    }, $class;

    $context -> add_object(
	name   => "tests",
	object => Model::CoreTestList->new,
    );
    $context -> add_object(
	name   => "gui_main",
	object => $self,
    );

    $self;
}

# Populate 
sub get_test_list {
    my $self = shift;
    my @lol = ();

    my $iter = CoreTracking::TestSpec->retrieve_all;
    while (my $test =  $iter->next) {
	my $int_list = [
	    map { $test->$_ } qw(id test_type mode latest_test_sitting items)
	];
	
	# to get % complete, need to check TestSitting table
	my $test_id  = $int_list->[0];
	my $sit_date = $int_list->[3];
	my $sit_id   = "${test_id}_$sit_date";
	warn "sit id is $sit_id";
	my $sitrec = CoreTracking::TestSitting->retrieve($sit_id);

	my $items_tested = $sitrec->items_tested;
	my $items_total  = $int_list->[4];
	push @$int_list, int (100 * $items_tested / $items_total);
	
	push @lol, $int_list;
    }
    return \@lol;
}

sub build_test_list {
    my $self = shift;
    return Gtk2::Ex::FormFactory::List->new (
	attr    => "gui_main.test_list",
	columns => [ "Created", "Last Sitting", "Times\nCompleted", "Type", "Mode", "%Complete" ],
	visible => [ 1, 1,1,1 ],
	scrollbars         => [ "never", "automatic" ],
	height  => 400,
	expand_h => 1,
	selection_mode     => "single",
	attr_select        => "gui_main.selected_test_id",
	attr_select_column => 0,
	signal_connect => {
	    row_activated => sub {
		$self->build_test_window(@_);
	    }
	},
    );
}

# Testing of a single test selection
sub build_test_window {

    # Turn callback into method call for our class so we can look up
    # context
    my ($self, $list, $path, $column) = @_;
    
    my $row_ref = $list->get_row_data_from_path ($path);
    my $creation_id = $row_ref->[0];
    my $test_rec_id = $row_ref->[3];

    my $test_win_id = "${creation_id}_$test_rec_id";

    my $context = $self->{context};

    if (0) {
	# the following fails if the object doesn't exist...
	my $existing = $context->get_object("core_test_window_$test_win_id");
	if ($existing) {
	    warn "This test window is still open";
	    # how to get that window to show? $existing isn't a gui object...
	    return 0;
	}
    }
    
    # add check here to see if test was already taken and
    # if it was (optionally) create a new sitting

    # start up a new test window
    my $test_model = Model::CoreTestQA->new(
	creation_id => $creation_id,
	test_rec_id => $test_rec_id,
    );

    my $win = GUI::CoreTestWindow->new(
	id => $test_win_id,
	model_obj => $test_model,
	context => $context,
	toplevel => 0,
	uri_base => 'file:///home/dec/JLPT_Study/core_6000/',
	close_hook => sub {
	    # signal update of the parent GUI when window closes
	    warn "Got window $test_win_id closure callback\n";
	    $context->update_object_attr_widgets("gui_main.test_list");
	}
    );

    $win->build;
}

sub build_main_window {
    
    my $self = shift;
    my $context = $self->{context};

    my $ff = Gtk2::Ex::FormFactory->new (
	context => $context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new (
		title   => "Core Vocabulary Tester",
		properties => {
		    default_width  => 640,
		    default_height => 640,
		},
		quit_on_close => 1,
		content => [
		    my $vbox = Gtk2::Ex::FormFactory::VBox->new(
			content => [
			    ($self->build_test_list),
			    ($self->build_quick_add_buttons),
			]
		    ),
		],
	    ),
	],
    );

    if ($self->{reload}) {
	$vbox -> add_child_widget(
	    Gtk2::Ex::FormFactory::Button->new(
		label => 'Reload Program',
		clicked_hook => sub { exec $0, @ARGV or die },
	    ),
	);
    }

    $ff->open;
    $ff->update;

}

sub build_quick_add_buttons {
    my $self = shift;
    my $context = $self->{context};
    return unless $self->{buttons};
    return (
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add kanji 2k test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    mode => "kanji",
		    type => "test2k",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add kanji 6k test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    mode => "kanji",
		    type => "test6k",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add kanji 2k random test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    mode => "kanji",
		    type => "core2k",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add kanji 6k random test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    mode => "kanji",
		    type => "core6k",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add sound 2k test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    mode => "sound",
		    type => "test2k",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add sound 6k test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    mode => "sound",
		    type => "test6k",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add sound 2k random test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    mode => "sound",
		    type => "core2k",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add sound 6k random test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    mode => "sound",
		    type => "core6k",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
    )
}

1;
