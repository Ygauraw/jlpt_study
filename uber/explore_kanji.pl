#!/usr/bin/perl

use strict;
use warnings;

use Model::KanjiReadings;

use Gtk2 qw(-init);
use Gtk2::Ex::FormFactory;

use utf8;

GUI::KanjiExplorer->new->build_window;

Gtk2->main;

# Until I figure out how to control auto-commit from with the program,
# I'll have to do it manually on program exit
print "Exiting; writing data to database\n";
KanjiReadings::DBI->dbi_commit;


package GUI::KanjiExplorer;

use strict;
use warnings;
use Util::JA_Script qw(has_kanji has_hira);

sub new {
    my $class = shift;
    my $context = shift || Gtk2::Ex::FormFactory::Context->new;
    
    my $self = bless { context => $context };

    $context->add_object(
	name => "gui",
	object => $self,
	);

    $context->add_object(
	name          => "summary",
	aggregated_by => "gui.selected_kanji",
	attr_accessors_href => {
	    get_echo => sub {
		warn "Asked to get_echo\n";
		$self->get_selected_kanji },
	},
	attr_depends_href => {
#	    echo => "gui.selected_kanji",  
	},

	);
    $context->add_object(
	name          => "matched",
	#aggregated_by => "gui.selected_kanji",
	);
    $context->add_object(
	name          => "failed",
	#aggregated_by => "gui.selected_kanji",
	);

    return $self;
      
}

sub build_window {

    my $self = shift;
    my $context = $self->{context};

    my $ff = Gtk2::Ex::FormFactory->new(
	context => $context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new(
		quit_on_close => 1,
		content => [
		    Gtk2::Ex::FormFactory::Table->new(
			expand => 1,
			layout => <<'END',
                        +---->----------------+---------+
                        ^     Search Box      |  Go     |
                        +---->----------------+---------+
                        ^          Summary              |
                        +-------------------------------+
                        |          Matched              |
                        +-------------------------------+
                        |          Failed               |
                        +-------------------------------+
END
			content => [
			    $self->build_search,
			    $self->build_go,
			    $self->build_summary,
			    $self->build_matched,
			    $self->build_failed,
			],
		    )
		],
	    )
	]
	);

    $ff->open;
    $ff->update_all;
    $self->{ff} = $ff;

}

sub get_search_term { $_[0]->{search_term} }
sub set_search_term { $_[0]->{search_term} = $_[1] || ''}
sub build_search {
    my $self = shift;
    Gtk2::Ex::FormFactory::Combo->new(
	label   => "Enter a kanji or an RTK frame number/keyword",
	attr    => "gui.search_term",
	presets => ['雨', 'rain'],
	# later implement history feature
	)
}

sub get_selected_kanji { $_[0]->{selected_kanji} }
sub set_selected_kanji { $_[0]->{selected_kanji} = $_[1] || ''}
sub build_go {
    my $self = shift;
    Gtk2::Ex::FormFactory::Button->new(
	label        => 'Search',
	clicked_hook => sub {
	    my $context = $self->{context};
	    my $kanji   = $self->get_search_term;
	    unless ($kanji) {
		warn "Blank search\n"; return 
	    }
	    # Add stuff here to convert keyword/frame number to kanji
	    $context->set_object_attr("gui.selected_kanji", $kanji);
	    warn "gui.selected_kanji is now " . $self->get_selected_kanji;
	}
	)
}

sub build_summary {
    my $self = shift;
    Gtk2::Ex::FormFactory::Label->new(
	attr => "summary.echo",
	label => "change me",
	inactive => 'insensitive',
	);
}

sub build_matched {
    my $self = shift;
    Gtk2::Ex::FormFactory::Label->new(
	label => "matched",
	)
}

sub build_failed {
    my $self = shift;
    Gtk2::Ex::FormFactory::Label->new(
	label => "failed",
	)
}


1;
