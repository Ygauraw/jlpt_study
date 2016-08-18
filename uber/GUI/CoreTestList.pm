package GUI::CoreTestList;

use Date::Format;

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
	active  => {},		# hash of active test windows (key=id)
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
	# use new sub from model to get all the fields
	my $fields = Model::CoreTestList->test_fields_from_test_iter($test);
	my $int_list = [
	    # $fields,		# Can't store; gets stringified
	    $fields->{test_id},
	    $fields->{latest_sitting_id},
	    time2str("%Y-%m-%d %R", $fields->{time_created}),
	    map { $fields->{$_} } 
	    qw(ls_test_end_time core_set test_type test_mode test_items)
	];

	my $items_tested = $fields->{ls_items_tested};
	my $items_total  = $fields->{test_items};
	push @$int_list, int (100 * $items_tested / $items_total);
	push @lol, $int_list;
    }
    return \@lol;
}

sub build_test_list {
    my $self = shift;
    return Gtk2::Ex::FormFactory::List->new (
	attr    => "gui_main.test_list",
	columns => [ "#", "[latest_sitting_id]", "Created", "Last Sat", "Set", 
		     "Type", "Mode", "Items", "%Complete" ],
	visible => [ 1,0,1,1,1,1,1 ],
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
#
# First, some routines to keep track of active test windows
sub look_up_test_window {
    my ($self, $id) = @_;
    return undef unless exists $self->{active}->{$id};
    #warn join ", ". keys(%{$self->{active}}) . "\n";
    #warn "Lookup says $id exists\n";
    return $self->{active}->{$id};
}
sub register_test_window {
    my ($self, $id, $obj) = @_;
    die unless defined $obj;
    #warn "Registering window $id\n";
    die if exists $self->{active}->{$id};
    $self->{active}->{$id} = $obj;
}
sub dereg_test_window {
    my ($self, $id) = @_;
    die unless exists $self->{active}->{$id};
    delete $self->{active}->{$id};
}
sub build_test_window {

    # Turn callback into method call for our class so we can look up
    # context
    my ($self, $list, $path, $column) = @_;
    
    my $context = $self->{context};
    my $row_ref = $list->get_row_data_from_path ($path);
    my $test_id    = $row_ref->[0];
    my $sitting_id = $row_ref->[1];

    my $win_id = "core_test_window_$sitting_id";
    
    my $win_obj = $self->look_up_test_window($win_id);
    if (defined($win_obj)) {
	#warn "Test window $win_id does already exist\n";
	$win_obj->show;
	return;
    } else {
	#warn "Test window $win_id doesn't already exist\n";
    }

    # add check here to see if test was already taken and
    # if it was (optionally) create a new sitting

    # start up a new test window
    my $test_model = Model::CoreTestQA->new(
	sitting_id => $sitting_id,
	test_id    => $test_id,
    );

    my $win = GUI::CoreTestWindow->new(
	id => $sitting_id,
	model_obj => $test_model,
	context => $context,
	toplevel => 0,
	uri_base => 'file:///home/dec/JLPT_Study/core_6000/',
	close_hook => sub {
	    # signal update of the parent GUI when window closes
	    #warn "Got window $win_id closure callback\n";
	    $context->update_object_attr_widgets("gui_main.test_list");
	    $self->dereg_test_window($win_id);
	}
    );
    $self->register_test_window($win_id, $win);
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
		    set  => "core2k",
		    mode => "kanji",
		    type => "range",
		    items => 20,
		    first => 0,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add kanji 6k test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    set  => "core6k",
		    mode => "kanji",
		    type => "range",
		    items => 20,
		    first => 0,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add sound 2k test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    set  => "core2k",
		    mode => "sound",
		    type => "range",
		    items => 20,
		    first => 0,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add sound 6k test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    set  => "core6k",
		    mode => "sound",
		    type => "range",
		    items => 20,
		    first => 0,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
	Gtk2::Ex::FormFactory::Button->new(
	    label => 'Add kanji 2k random test',
	    clicked_hook => sub {
		my $test_list = $context->get_object("tests");
		$test_list -> new_item(
		    set  => "core2k",
		    mode => "kanji",
		    type => "random",
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
		    set  => "core2k",
		    mode => "sound",
		    type => "random",
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
		    set  => "core6k",
		    mode => "kanji",
		    type => "random",
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
		    set  => "core6k",
		    mode => "sound",
		    type => "random",
		    items => 20,
		);
		$context->update_object_attr_widgets("gui_main.test_list");
	    }
	),
    )
}

1;
