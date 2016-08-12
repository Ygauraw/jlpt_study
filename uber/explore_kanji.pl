#!/usr/bin/perl

use strict;
use warnings;

use Model::KanjiReadings;

use Gtk2 qw(-init);
use Gtk2::Ex::FormFactory;

use utf8;
#require GUI::KanjiExplorer;

binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";

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

use Carp;

use Glib qw/TRUE FALSE/; 

our ($AUTOLOAD, %get_set_attr, $DEBUG);
BEGIN {
    $DEBUG=1;
    %get_set_attr = (
	    map { ($_ => undef) } 
	    qw(selected_kanji search_term
    ));
}
sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    if ($attr =~ s/^.*::get_//) {
	warn "GUI: get_$attr\n" if $DEBUG;
        croak "Method get_$attr not registered for autoloading"
            unless exists $get_set_attr{$attr};
        return $self->{$attr};
    }
    if ($attr =~ s/^.*::set_//) {
	warn "GUI: set_$attr($_[0])\n" if $DEBUG;
        croak "Method set_$attr not registered for autoloading"
            unless exists $get_set_attr{$attr};
        return $self->{$attr}=shift;
    }

    croak "Method $attr does not exist";
}


sub new {
    my $class = shift;
    my $context = shift || Gtk2::Ex::FormFactory::Context->new;
    
    my $self = bless { context => $context };

    $context->add_object(
	name => "gui",
	object => $self,
    );
    
    $context->add_object(
	name => "kanji",
	attr_accessors_href => {
	    get_summary => sub {
		warn "Asked to get summary\n";
		my $self = shift;
		"Summary: $self->{kanji}; self is of type " . ref($self);
	    },
	    get_failed => sub {
		warn "Asked to get failed\n";
		my $self = shift;
		warn "failed: $self->{kanji}; self is of type " . ref($self);
		my @outlist = ();
		foreach my $vocab ($self->vocab_readings) {
		    next if $vocab->reading_type;
		    push @outlist, [
			"N" . $vocab->jlpt_grade,
			$vocab ->vocab_kanji,
			$vocab ->vocab_kana,]
		}
		\@outlist;
	    },
	    get_matched => sub {
		my $self = shift;
		warn "Asked to get matched, kanji is " . $self->kanji . "\n";
		my @outlist = ();
		foreach my $vocab ($self->vocab_readings) {
		    #warn "Type: " . $vocab->reading_type . "\n";
		    next unless $vocab->reading_type;
		    push @outlist, [
			"N" . $vocab->jlpt_grade,
			$vocab ->vocab_kanji,
			$vocab ->vocab_kana,
			$vocab ->reading_type,
			$vocab ->reading_kana,
		    ]
		}
		\@outlist;
	    },
	    get_tallies => sub {
		my $self = shift;
		warn "Asked to get tallies, kanji is " . $self->kanji . "\n";
		my @outlist = ();
		foreach my $tally ($self->tallies) {
		    #warn "Type: " . $vocab->reading_type . "\n";
		    next unless $tally->read_type;
		    push @outlist, [
			$tally ->adj_tally || $tally->raw_tally,
			$tally->read_type,
			$tally->kana,
		    ]
		}
		\@outlist;
	    },
	},
	attr_depends_href => {
	    matched     => "gui.selected_kanji",
	    summary     => "gui.selected_kanji",
	    failed      => "gui.selected_kanji",
	    tallies     => "gui.selected_kanji",
	},
	aggregated_by => "gui.selected_kanji",
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
		expand => 1,
		#		height => 600,
		
		width  => 600,
		content => [
		    Gtk2::Ex::FormFactory::Table->new(
			expand => 1,
			layout => <<'END',
                        +---->----------------+---------+
                        '     Search Box      '  Go     |
                        +---------------------+---------+
                        |          Summary              |
                        +-------------------------------+
                        ^          Tallies              |
                        +-------------------------------+
                        ^          Matched              |
                        +-------------------------------+
                        ^          Failed               |
                        +-------------------------------+
END
			content => [
			    $self->build_search,
			    $self->build_go,
			    $self->build_summary,
			    $self->build_tallies,
			    $self->build_matched,
			    $self->build_failed,
			],
		    ),
		    Gtk2::Ex::FormFactory::Button->new(
			label => 'Reload Program',
			clicked_hook => sub { exec $0, @ARGV or die },
		    ),
		],
	    ),
	]
	);

    $self->{ff} = $ff;
    $ff->open;
    $ff->update_all;

}

sub build_search {
    my $self = shift;
    Gtk2::Ex::FormFactory::Combo->new(
	label   => "Enter a kanji or an RTK frame number/keyword",
	attr    => "gui.search_term",
	presets => ['雨', 'rain'],
	# later implement history feature
    )
}

sub build_go {
    my $self = shift;
    Gtk2::Ex::FormFactory::Button->new(
	label        => 'Search',
	attr         => 'gui.selected_kanji',
	clicked_hook => sub {
	    my $context = $self->{context};
	    my $kanji   = $self->get_search_term;
	    unless ($kanji) {
		warn "Blank search\n"; return 
	    }
	    # Add stuff here to convert keyword/frame number to kanji
	    $context->set_object_attr("gui.selected_kanji",
				      KanjiReadings::Summary->retrieve($kanji));
	}
    )
}

sub build_summary {
    my $self = shift;
    Gtk2::Ex::FormFactory::Form->new(
	content => [
	    Gtk2::Ex::FormFactory::Label->new(
		label   => "Summary of readings",
		attr => "kanji.summary",
	    ),
#	    Gtk2::Ex::FormFactory::List->new(
#		attr => "kanji.summary",
#		columns => ["JLPT", "Vocab", "Reading", "Type", "Kana"],
#	    )
	],
    );
}

sub build_tallies {
    my $self = shift;
    Gtk2::Ex::FormFactory::Form->new(
#	height  => 120,
	expand  => 1,
	content => [
	    Gtk2::Ex::FormFactory::Label->new(
		label   => "Reading Tallies",
	    ),
	    Gtk2::Ex::FormFactory::List->new(
		attr => "kanji.tallies",
		columns => ["Count", "Type", "Reading", ],
		height  => 120,
		scrollbars => ["never", "automatic"],
		expand => 1,
	    )
	],
    );
}

sub build_matched {
    my $self = shift;
    Gtk2::Ex::FormFactory::Form->new(
#	height  => 400,
	expand  => 1,
	content => [
	    Gtk2::Ex::FormFactory::Label->new(
		label   => "Vocab with matching readings",
	    ),
	    Gtk2::Ex::FormFactory::List->new(
		attr    => "kanji.matched",
		columns => ["JLPT", "Vocab", "Reading", "Type", "Kana"],
		height  => 320,
		scrollbars => ["never", "automatic"],
		expand => 1,
	    )
	]
    )
}

sub build_failed {
    my $self = shift;
    Gtk2::Ex::FormFactory::Form->new(
#	height  => 200,
	expand  => 1,
	content => [
	    Gtk2::Ex::FormFactory::Label->new(
		label   => "Vocab with no matching readings",
	    ),
	    Gtk2::Ex::FormFactory::List->new(
		attr    => "kanji.failed",
		columns => ["JLPT", "Vocab", "Reading"],
		height  => 200,
		scrollbars => ["never", "automatic"],
		expand => 1,

	    )
	]
    )
}

1;
