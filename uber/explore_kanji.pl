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
use YAML::Any qw(LoadFile);

our ($AUTOLOAD, %get_set_attr, $DEBUG, $kanjivg_dir, $rtkinfo);
BEGIN {
    $DEBUG=1;
    %get_set_attr = (
	    map { ($_ => undef) } 
	    qw(selected_kanji search_term search_term_presets
    ));
    $kanjivg_dir = '/home/dec/JLPT_Study/kanjivg/kanjivg-r20160426/kanji';
    $rtkinfo = LoadFile("./rtk_kanji.yaml") or die;
    
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

    $self->{search_term_presets} = ['雨', 'rain'];
    
    $context->add_object(
	name => "gui",
	object => $self,
	attr_depends_href => {
	    search_term => "gui.selected_kanji", # works OK when we update history
	}
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
		#warn "failed: $self->{kanji}; self is of type " . ref($self);
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
	    get_image_file => sub {
		my $self = shift;
		my $kanji = $self->kanji;
		warn "Asked to get image file, kanji is $kanji\n";
		my $unicode = sprintf("%05x", ord $kanji);
		# Unfortunately, my Gtk2::Gdk::Pixbuf is saying it
		# doesn't recognise the svg file ...
		# https://bugs.launchpad.net/ubuntu/+source/gdk-pixbuf/+bug/926019
		# If I delete the comment, it works...
		my $filename = "$kanjivg_dir/$unicode.svg";
		return $filename;

		# OK, can't use filename#id notation as below...
		# my $filename = "/home/dec/JLPT_Study/kanjivg/kanjivg-20160426.xml";
		# warn "No file $filename" unless -f $filename;
		# return "$filename#kvg:kanji_$unicode";
		
		# There seems to be a bug in gdk-pixbuf. It's supposed
		# to look through the first 4,096 characters of the
		# file to find the starting tag for the svg, but it
		# doesn't work. I've tried messing with patterns in
		# loaders.cache but it didn't work. As a workaround,
		# I'm stripping out all the comments:
		#
		# perl -i.bak -nle 'print unless m|^<!--| .. m|-->$|' *.svg

		
	    },
	},
	attr_depends_href => {
	    matched     => "gui.selected_kanji",
	    summary     => "gui.selected_kanji",
	    failed      => "gui.selected_kanji",
	    tallies     => "gui.selected_kanji",
	    image_file  => "gui.selected_kanji",
	},
	aggregated_by => "gui.selected_kanji",
	);

    $context->add_object(
	name  => "image",
	
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
                        +->>----------------+-+-->------+
                        ^ Pixbuf            |           |
                        +-------------------+ Matched   |
                        |          Tallies  |           |
                        +-------------------------------+
                        ^          Failed               |
                        +-------------------------------+
END
			content => [
			    $self->build_search,
			    $self->build_go,
			    $self->build_pixbuf,
#			    $self->build_summary,
			    $self->build_matched,
			    $self->build_tallies,
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
	# later implement history feature
    )
}

# jump_to_kanji was initially handled in the go button handler, but
# I'm breaking it out here to reuse when I add a right-click menu to
# table elements to allow jumping to other kanji found within compound
# words. The optional term argument could be a keyword or frame
# number, which is what I'll actually store in the history rather than
# necessarily converting it.
sub jump_to_kanji {
    my $self = shift;
    my $kanji = shift or die;
    my $term  = shift || $kanji;

    my $context = $self->{context};

    # Handle history
    my $history = $self->{search_term_presets};
    if ($term ne $history->[0]) {
	unshift @$history, $term;
	shift   @$history if @$history > 40;
	#warn "New history is " . join ", ",  @$history;
    }

    $context->set_object_attr("gui.selected_kanji",
			      KanjiReadings::Summary->retrieve($kanji));
}

sub build_go {
    my $self = shift;
    Gtk2::Ex::FormFactory::Button->new(
	label        => 'Search',
	attr         => 'gui.selected_kanji',
	clicked_hook => sub {
	    my $term = $self->get_search_term;
	    my $kanji;
	    unless ($term) {
		warn "Blank search\n"; return 
	    }

	    # Look up Heisig/RTK keywords or frame numbers
	    if ($term =~ /(\d+)/) {
		warn "Looking up number in RTK index\n";
		$kanji = $rtkinfo->{by_frame}->[$term = $1]->{kanji}
	    } elsif (!has_kanji($term)) {
		warn "No kanji characters, looking up as RTK keyword\n";
		$kanji = $rtkinfo->{by_keyword}->{$term}->{kanji}
	    }
	    
	    $self->jump_to_kanji($kanji,$term);
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

sub build_pixbuf {
    my $self = shift;
    my $kanji = $self->{kanji};

    Gtk2::Ex::FormFactory::Image->new(
	attr => "kanji.image_file",
	bgcolor => "#ffffff",
	# height => 400, # does nothing!
	scale_to_fit => 1, 
	# scale => 1.25,
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
		#		expand => 1,
		# hook that selects all matching vocab in readings panel
		signal_connect_after => {
		    row_activated => sub  {
			# Passed values are of the types:
			# Gtk2::SimpleList
			# Gtk2::TreePath
			# Gtk2::TreeViewColumn
			# from Gtk2::SimpleList pod:
			my ($sl, $path, $column) = @_;
			my $row_ref = $sl->get_row_data_from_path ($path);

		    }
		},
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
		label   => "Unmatched Vocab",
	    ),
	    Gtk2::Ex::FormFactory::List->new(
		attr    => "kanji.failed",
		columns => ["JLPT", "Vocab", "Reading"],
		height  => 140,
		scrollbars => ["never", "automatic"],
		expand => 1,

	    )
	]
    )
}

1;
