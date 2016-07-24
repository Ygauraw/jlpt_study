#!/usr/bin/perl

use Gtk2 qw/-init/;

use Gtk2::Ex::FormFactory;


my $worksheet = worksheet->new;
my $context = Gtk2::Ex::FormFactory::Context->new;
$context->add_object( name   => "worksheet",
		      object => $worksheet);

print $worksheet->get_title . "\n";

#if(0) {

my $ff = Gtk2::Ex::FormFactory->new (
    context => $context,
    content => [
	Gtk2::Ex::FormFactory::Window->new(
	    title   => "Preferences",
	    content => [
		Gtk2::Ex::FormFactory::Notebook->new (
		    attr    => "worksheet.selected_page",
		    content => [
			Gtk2::Ex::FormFactory::VBox->new (
			    title   => "Filesystem",
			    content => [
				Gtk2::Ex::FormFactory::Form->new (
				    content => [
					Gtk2::Ex::FormFactory::Entry->new (
					    attr   => "worksheet.data_dir",
					    label  => "Data Directory",
					    tip    => "This directory takes all your files.",
					    rules  => "writable-directory",
					),
				    ],
				),
			    ],
			),
		    ],
		),
		Gtk2::Ex::FormFactory::DialogButtons->new
	    ],
	),
    ],
    );


if (0) {
my $ff = Gtk2::Ex::FormFactory->new (
           context      => $context,
#           layouter     => $layouter,
 #          rule_checker => $rule_checker,
           content      => [
             Gtk2::Ex::FormFactory::Window->new (
               title   => "Worksheet Editor",
               content => [
                 Gtk2::Ex::FormFactory::Form->new (
                   title   => "Main data",
                   content => [
                     Gtk2::Ex::FormFactory::Entry->new (
			 label => "Worksheet title",
			 #object => "worksheet",
                       attr  => "worksheet.title",
                       tip   => "Title of this worksheet",
                     ),
                     #-- More widgets...
                   ],
                 ),
                 Gtk2::Ex::FormFactory::DialogButtons->new,
               ],
             ),
           ],
         );
}

$ff->open;    # actually build the GUI and open the window
print "got here\n";
$ff->update;  # fill in the values from $config_object

Gtk2->main;

package worksheet;

sub new { return bless {}, "worksheet" };

sub get_data_dir {"/tmp" }
sub get_selected_page { 0 }
sub set_data_dir {}
sub set_selected_page {}

sub get_title {"foo"}
sub set_title {}

#sub get_worksheet_title {"foo"}
#sub set_worksheet_title {}

