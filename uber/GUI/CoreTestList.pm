package GUI::CoreTestList;

use Model::CoreTestList;

# basic accessors
sub get_context                 { shift->{context}                      }
sub get_form_factory            { shift->{form_factory}                 }

sub set_context                 { shift->{context}              = $_[1] }
sub set_form_factory            { shift->{form_factory}         = $_[1] }

sub get_selected_test_id        { shift->{selected_test_id}             }
sub set_selected_test_id        { shift->{selected_test_id}     = $_[1] }

sub new {
    my $class = shift;
    bless { }, $class;
}

sub create_context {
    my $self = shift;
    $self->{context} = my $context = Gtk2::Ex::FormFactory::Context->new;

    # Add all objects
    $context -> add_object(
	name   => "tests",
	object => Model::CoreTestList->new,
	);

    $context -> add_object(
	name   => "gui",
	object => $self,
	);

    return $context;
}

# A list of available tests
sub build_test_list {
    return Gtk2::Ex::FormFactory::List->new (
	name    => "test_list",
	attr    => "tests.list",
	columns => [ qw/time Created Type Mode %Complete/ ],
	visible => [ 0, 1,1,1 ],
	scrollbars         => [ "never", "automatic" ],
	height  => 400,
	expand_h => 1,
	selection_mode     => "single",
	attr_select        => "gui.selected_test_id",
	attr_select_column => 0,
	signal_connect_after => {
	    row_activated => sub { warn "Row was activated\n"; }, 
	},
	);
}

# Testing of a single test selection
sub build_test_window {


}

sub build_main_window {
    
    my $self = shift;
    my $context = $self->create_context;

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
		    Gtk2::Ex::FormFactory::VBox->new(
			content => [
			    build_test_list,
			    Gtk2::Ex::FormFactory::Button->new(
				label => 'Add kanji 2k test',
				clicked_hook => sub {
				    my $test_list = $context->get_object("tests");
				    $test_list -> new_item(
					mode => "kanji",
					type => "test2k",
					items => 20,
					);
				    $context->update_object_widgets("tests");
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
				    $context->update_object_widgets("tests");
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
				    $context->update_object_widgets("tests");
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
				    $context->update_object_widgets("tests");
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
				    $context->update_object_widgets("tests");
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
				    $context->update_object_widgets("tests");
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
				    $context->update_object_widgets("tests");
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
				    $context->update_object_widgets("tests");
				}
			    ),
			],
		    ),
		],
	    ),
	],
	);

    $ff->open;
    $ff->update;

}

1;
