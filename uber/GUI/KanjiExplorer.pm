package GUI::KanjiExplorer;

use strict;
use warnings;

use utf8;

use Util::JA_Script qw(has_kanji has_hira strip_non_kanji);
use GUI::KanjiDetails;
use Carp;

use Glib qw/TRUE FALSE/; 
use YAML::Any qw(LoadFile);

# Name the columns in the two vocabulary-related lists
use constant {
    COL_GRADE      => 0,
    COL_VOCAB_ID   => 1,	# not displayed
    COL_VOCAB      => 2,
    COL_VOCAB_KANA => 3,
    COL_YOMI_ID    => 4, 	# matched list, not displayed
    COL_YOMI_KANJI => 5,
    COL_YOMI_KANA  => 6,
    COL_STATUS_ID  => 7,	# numeric status value, not displayed
    COL_STATUS     => 8,	# textual status value
};
# Same for the tally table
use constant {
    TAL_KANJI      => 0,
    TAL_COUNT      => 1,
    TAL_YOMI_ID    => 2,
    TAL_YOMI_TYPE  => 3,
    TAL_YOMI_KANA  => 4,
    TAL_VOCAB_ID   => 5,
    TAL_EXEMPLAR   => 6,
    TAL_STATUS     => 7,
};


our ($AUTOLOAD, %get_set_attr, $DEBUG, $kanjivg_dir, $rtkinfo, 
     %kanji_windows, %vocab_windows);
BEGIN {
    $DEBUG=1;
    %get_set_attr = (
	    map { ($_ => undef) } 
	    qw(selected_kanji search_term search_term_presets
    ));
    $kanjivg_dir = '/home/dec/JLPT_Study/kanjivg/kanjivg-r20160426/kanji';
    $rtkinfo = LoadFile("./rtk_kanji.yaml") or die;
    %kanji_windows = ();
    %vocab_windows = ();
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
		warn "failed: $self->{kanji}; self is of type " . ref($self);
		my @outlist = ();
		if ("new" ) {
		    # !! Change later when Summary -> Kanji
		    my @failed = grep { 1 == $_->yomi_id } $self->kv_link;
		    foreach my $link (@failed) {
			my $v = $link->vocab_id;
			my $status = Learnable::KanjiVocab
			    ->get_status(vocab_id => $v->vocab_id);
			push @outlist, [
			    "N" . $v->jlpt_grade,
			    # Hidden field containing vocab_id
			    "" . $v->vocab_id,
			    $v->vocab_ja,
			    $v->vocab_kana,
			    $status,
			    Model::Learnable->status_text($status),
			]
		    }
		}
		\@outlist;
	    },
	    get_matched => sub {
		my $self = shift;
		warn "Asked to get matched, kanji is " . $self->kanji . "\n";
		my @outlist = ();
		if ("new") {
		    # !! Change later when Summary -> Kanji
		    foreach my $link ($self->kv_link) {
			next if 1 == $link->yomi_id;
			my $v = $link->vocab_id;
			my $y = $link->yomi_id;
			my $status = Learnable::KanjiVocab
			    ->get_status(vocab_id => $v->vocab_id);
			push @outlist, [
			    "N" . $v->jlpt_grade,
			    # Hidden field containing vocab_id
			    "" . $v->vocab_id,
			    $v->vocab_ja,
			    $v->vocab_kana,
			    "$y", # stringified yomi_id 
			    $y->yomi_type,
			    $y->yomi_kana,
			    $status,
			    Model::Learnable->status_text($status),
			]
		    }
		}
		\@outlist;
	    },
	    get_rtk_info => sub {
		my $self  = shift;
		my $kanji = $self->kanji;

		my $rtk;
		if (exists($rtkinfo->{by_kanji}->{$kanji})) {
		    $rtk = $rtkinfo->{by_kanji}->{$kanji};
		} else {
		    $rtk = {
			frame  => "n/a",
			keyword => "n/a",
		    }
		}
		return "#" . $rtk->{frame} . ": " . $rtk->{keyword};
	    },
	    get_jlpt => sub {
		my $self  = shift;
		"N" . $self->jlpt_grade . ", ";
	    },
	    get_jouyou => sub {
		my $self  = shift;
		"J" . $self->jouyou_grade;
	    },
	    get_tallies => sub {
		my $self = shift;
		warn "Asked to get tallies, kanji is " . $self->kanji . "\n";
		my @outlist = ();
		my ($has_failed, $eg_failed, $eg_failed_id, $failed_status) = (0,'',0,0);

		foreach my $tally ($self->tallies) {
		    my $y = $tally->yomi_id;
		    my $status = Learnable::KanjiExemplar->get_status(
			kanji => $self->kanji,
			yomi_id => "$y",
		    );
		    $status = Model::Learnable->status_text($status);
		    if (1 == $y) {
			$has_failed += $tally->adj_count || $tally->yomi_count;
			$eg_failed_id = $tally->exemplary_vocab_id;
			$eg_failed = '';
			$eg_failed = $eg_failed_id->vocab_ja if $eg_failed_id;
			$failed_status = $status;
			next;
		    };
		    my @vocab = (0, '');
		    my $vocab_id = $tally->exemplary_vocab_id;
		    @vocab = ("$vocab_id", $vocab_id->vocab_ja) if ($vocab_id);
		    push @outlist, [
			$self->kanji,
			$tally->adj_count || $tally->yomi_count,
			"$y",	# yomi_id, stringified
			$y->yomi_type,
			$y->yomi_kana,
			@vocab,
			$status,
			]
		}
		# put failed at the end, but only if at least one exists
		if ($has_failed) {
		    push @outlist, [
			$self->kanji,
			$has_failed,
			1,
			"*",
			"*",
			"$eg_failed_id",
			$eg_failed,
			$failed_status,
		    ];
		}
		\@outlist;
	    },
	    get_image_file => sub {
		my $self = shift;
		my $kanji = $self->kanji;
		#warn "Asked to get image file, kanji is $kanji\n";
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
	    rtk_info    => "gui.selected_kanji",
	    jouyou      => "gui.selected_kanji",
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
		
		width  => 800,
		content => [
		    Gtk2::Ex::FormFactory::Table->new(
			expand => 1,
			layout => <<'END',
                        +---->-------------------+---------+
                        '     Search Box         '  Go     |
                        +->>-------------------+>+---------+
                        ^ Pixbuf               | Matched   |
                        +-[----+---->-+------]-+           |
                        | JLPT |Jouyou|   RTK  |           |
                        +->----+------+--------+           |
                        | Tallies              |           |
                        +----------------------+-----------+
                        ^          Failed                  |
                        +----------------------------------+
END
			content => [
			    $self->build_search,
			    $self->build_go,
			    $self->build_pixbuf,
			    $self->build_matched,
			    $self->build_jlpt,
			    $self->build_jouyou,
			    $self->build_rtk,
			    $self->build_tallies,
			    $self->build_failed,
#			    $self->build_summary,
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
	tip     =>
	"Enter a single kanji, RTK frame #, RTK keyword or \"r\" for a random Jouyou kanji",
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
	pop     @$history if @$history > 40;
	#warn "New history is " . join ", ",  @$history;
    }

    warn "jump_to_kanji: kanji is $kanji\n";
    $self->{kanji} = $kanji;

    $context->set_object_attr("gui.search_term",'');
    $context->set_object_attr("gui.selected_kanji",
			      KanjiReadings::Kanji->retrieve($kanji));
}

sub build_go {
    my $self = shift;
    Gtk2::Ex::FormFactory::Button->new(
	label        => 'Search',
	attr         => 'gui.selected_kanji',
	clicked_hook => sub {
	    my $term  = $self->get_search_term;
	    my $kanji = $term;
	    unless ($term) {
		warn "Blank search\n"; return 
	    }

	    if ($term eq "r") {
		# pick a random frame number and convert it to a kanji
		$term = int (rand (2200)) + 1;
		$term = $kanji = $rtkinfo->{by_frame}->[$term]->{kanji};
	    } elsif ($term =~ /(\d+)/) {
		# Look up Heisig/RTK keywords or frame numbers
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

sub build_pixbuf {
    my $self  = shift;
    my $kanji = $self->{kanji};

    Gtk2::Ex::FormFactory::Image->new(
	attr => "kanji.image_file",
	bgcolor => "#ffffff",
	# height => 400, # does nothing!
	scale_to_fit => 1, 
	# scale => 1.25,
	signal_connect => {
	    button_press_event => sub {
		warn "Image was activated\n";
		my ($widget,$event) = @_;
		if  ($event->type eq '2button-press') {
		    warn "double-click\n";
		    $self->launch_kanji_window;
		} else {
		    warn "Non-double-click event\n";
		}
		return 1;
	    }
	}
    );
}


sub build_rtk {
    my $self  = shift;

    Gtk2::Ex::FormFactory::Label->new(
	attr => "kanji.rtk_info",
    );
}

sub build_jouyou {
    my $self  = shift;
    Gtk2::Ex::FormFactory::Label->new(
	attr => "kanji.jouyou",
    );
}

sub build_jlpt {
    my $self  = shift;
    Gtk2::Ex::FormFactory::Label->new(
	attr => "kanji.jlpt",
    );
}

sub tally_panel_popup_menu {
    my ($self, $sl, $event) = @_;
    return 0 if ($event->button != 3);

    warn "Got right-click on tallies table\n";
    # Find out where the click went
    my ($path, $col, $cell_x, $cell_y)
	= $sl->get_path_at_pos ($event->x, $event->y);
    # Find row based on the TreeView path
    my $row_ref = $sl->get_row_data_from_path ($path);
    warn "row_ref is of type " . ref($row_ref);
    warn "This row contains " . (join ", ", @$row_ref) . "\n";

    # Build a popup menu with option to copy text
    my $copy_text = $row_ref->[TAL_YOMI_KANA];
    my $menu = Gtk2::Menu->new();
    my $menu_item = Gtk2::MenuItem->new("Copy $copy_text");
    $menu_item->signal_connect(
	activate => sub {
	    Gtk2::Clipboard->get(Gtk2::Gdk->SELECTION_CLIPBOARD)
		->set_text($copy_text);
	}
    );
    $menu_item->show;
    $menu->append($menu_item);

    # option to clear exemplar, if it's set
    if ($row_ref->[TAL_VOCAB_ID]) {
	menu_separator($menu);
	$menu_item = Gtk2::MenuItem->new("Clear Exemplar");
	my $yomi_id = $row_ref->[TAL_YOMI_ID];
	$menu_item->signal_connect(
	    activate => sub {
		my $kanji   = $row_ref->[TAL_KANJI];
		my $yomi_tally =
		    KanjiReadings::KanjiYomiTally->retrieve(
			kanji   => $kanji,
			yomi_id => $yomi_id);
		$yomi_tally->exemplary_vocab_id(0);
		# Also unset learning status
		Learnable::KanjiExemplar->set_update_status(0,
                    kanji   => $kanji,
                    yomi_id => $yomi_id);
		$self->{ff_tally}->update;
	    }
	);
	$menu_item->show;
	$menu->append($menu_item);
    }

    $menu->popup(undef,undef,undef,undef,$event->button, $event->time);

    return 1;
}

sub build_tallies {
    my $self = shift;
    Gtk2::Ex::FormFactory::Form->new(
	expand  => 1,
	content => [
	    Gtk2::Ex::FormFactory::Label->new(
		label   => "Reading Tallies",
	    ),
	    $self->{ff_tally} = Gtk2::Ex::FormFactory::List->new(
		attr => "kanji.tallies",
		columns => [qw/kanji Count yomi_id Type Reading vocab_id Exemplar Status/],
		visible => [0,1,0,1,1,0,1,1],
		height  => 120,
		scrollbars => ["never", "automatic"],
		#		expand => 1,
		signal_connect => {
		    # Double-clicking will allow selection of all
		    # vocab with the selected reading
		    row_activated => sub  {
			# Passed values are of the types:
			# Gtk2::SimpleList
			# Gtk2::TreePath
			# Gtk2::TreeViewColumn
			# from Gtk2::SimpleList pod:
			my ($sl, $path, $column) = @_;
			my $row_ref = $sl->get_row_data_from_path ($path);
			my $kana = $row_ref->[TAL_YOMI_KANA];

			# Talk to the underlying Gtk2::Ex::Simple::List
			my $list = $self->{ff_matched};
			my $gtk  = $list->get_gtk_widget;
			$gtk->get_selection->unselect_all;
			my $i = 0;
			for my $row (@{$list->get_data}) {
			    $gtk->select($i) if ($row->[COL_YOMI_KANA] eq $kana);
			    ++$i;
			}
		    },
		    button_press_event => sub {
			my ($sl,$event) = @_;
			# Need to consume right mouse button press or
			# else GTK will consider it to be a selection
			return ($event->button == 3);
		    },
		    button_release_event => sub {
			$self->tally_panel_popup_menu(@_);
		    }
		},
	    )
	],
    );
}

sub set_exemplary {
    my ($self, $kanji, $yomi_id, $vocab_id, $panel) = @_;

    warn "in set_exemplary\n";
    warn "self is a " . ref($self) . "\n";
    my $confirmed = 0;

    warn "set_exemplary: args are $kanji, $yomi_id, $vocab_id\n";
    # stash in KanjiReadings::KanjiYomiTally
    my $yomi_tally = 
	KanjiReadings::KanjiYomiTally->retrieve(
	    kanji   => $kanji,
	    yomi_id => $yomi_id);
    if (0 != $yomi_tally->exemplary_vocab_id) {
	# do a pop-up window to confirm overwrite
	warn "would confirm here\n";
	#return;
    }

    warn "Updating exemplary vocab_id to $vocab_id\n";
    $yomi_tally->exemplary_vocab_id($vocab_id);
    warn "Got here";
    $yomi_tally->update;

    # Make a note of learnable kanji exemplar
    my $oldstatus = Learnable::KanjiExemplar->get_status(
	    kanji => $kanji,
	    yomi_id => $yomi_id,
    );
    if ($oldstatus < 1) {
	Learnable::KanjiExemplar->set_update_status(1,
	    kanji => $kanji,
	    yomi_id => $yomi_id,
	);
    }

    # And also of learnable vocab
    $oldstatus = Learnable::KanjiVocab->get_status(vocab_id => $vocab_id);
    if ($oldstatus < 1) {
	Learnable::KanjiVocab->set_update_status(1, vocab_id => $vocab_id);
    }

    # And kanji
    $oldstatus = Learnable::Kanji->get_status(kanji => $kanji);
    if ($oldstatus < 1) {
	Learnable::Kanji->set_update_status(1, kanji => $kanji);
    }

    # Manually update the affected panels (matched/failed plus tally)
    $self->{"ff_$panel"}->update;
    $self->{ff_tally}->update;
}

# Build a menu that can be used on either the matched or failed
# panels. Meant to be called from a button_press_event handler.
sub menu_separator {
    my $menu = shift or die;
    my $menu_item = Gtk2::SeparatorMenuItem->new;
    $menu_item->show;
    $menu->append($menu_item);
}
sub vocab_panel_popup_menu {
    my ($self, $sl, $event, $panel) = @_;
    return 0 if ($event->button != 3);

    warn "Got right-click on $panel table\n";

    # Find out where the click went
    my ($path, $col, $cell_x, $cell_y)
	= $sl->get_path_at_pos ($event->x, $event->y);
    return 0 unless defined $path; # didn't click on a row

    # Find row index and data based on the TreeView path
    my ($row_idx) = $path->get_indices;
    my $row_ref   = $sl->get_row_data_from_path ($path);
    warn "row index is $row_idx\n";
    warn "row_ref is of type " . ref($row_ref);
    warn "This row contains " . (join ", ", @$row_ref) . "\n";

    # when giving option to search for kanji, ignore the
    # currently-selected one
    my $kanji = $self->{kanji};
    warn "kanji is '$kanji'\n";

    # Will add options to search for other kanji in vocab
    my %other_kanji = ();
    my @selected_rows = $sl->get_selected_indices;
    @selected_rows = ($row_idx) if @selected_rows < 2;
    warn "Selected rows are: " . (join ", ", @selected_rows) . "\n";

    # Scan selected rows to pull out other kanji
    my $lol = $sl->{data};
    foreach my $i (@selected_rows) {
	my $vocab = strip_non_kanji($lol->[$i]->[COL_VOCAB]);
	foreach my $char (split "", $vocab) {
	    next if $char eq $kanji;
	    $other_kanji{$char} = undef;
	}
    }
    #warn join ", ", keys %other_kanji;

    my $menu = Gtk2::Menu->new();
    my $menu_item;
    my $menu_items = 0;

    for my $char (sort { $a cmp $b } keys %other_kanji) {
	$menu_item = Gtk2::MenuItem->new("Jump to $char");
	$menu_item->signal_connect(activate => sub { $self->jump_to_kanji($char) } );
	$menu_items++;
	$menu_item->show;
	$menu->append($menu_item);
    }

    # Add menu item for copying either vocab or reading
    if (@selected_rows == 1) {
	menu_separator($menu) if ($menu_items);
	for my $col (2,3) {
	    my $copy_text = $row_ref->[$col];
	    $menu_item = Gtk2::MenuItem->new("Copy $copy_text");
	    $menu_item->signal_connect(
		activate => sub { 
		    Gtk2::Clipboard->get(Gtk2::Gdk->SELECTION_CLIPBOARD)
			->set_text($copy_text)
		} );
	    $menu_item->show;
	    $menu->append($menu_item);
	}
    }

    # Add menu item for setting exemplary vocab
    if (@selected_rows == 1) {
	menu_separator($menu);
	# need vocab_id for this to work; it must be a non-displayed
	# field in the row_ref above.
	my $vocab_id = $row_ref->[COL_VOCAB_ID];
	my $vocrec = KanjiReadings::Vocabulary->retrieve($vocab_id);
	$menu_item = Gtk2::MenuItem->new("Exemplar " . $vocrec->vocab_ja);
	$menu_item->signal_connect(
	    activate => sub {
		# I should really use a popup if there's already an
		# exemplary vocab id set.
		warn "Will set exemplar for $panel kanji $kanji to vocab id $vocab_id";
		my $yomi_id = $panel eq "failed" ? 1 : $row_ref->[COL_YOMI_ID];
		$self->set_exemplary($kanji, $yomi_id, $vocab_id, $panel);
	    }
	);
	$menu_item->show;
	$menu->append($menu_item);
    }

    # Add SRS-like actions
    if (@selected_rows == 1) {	# don't include with multiple selections
	menu_separator($menu);
	# These names are a bit "meh"
	my @srs_names = ("Bury Forever", "Bury Long Time", "Bury Medium Time",
			 "Bury Short Time", "Clear Status", "Learning", "Reviewing",
			 "SRS 1 (Near)", "SRS 2", "SRS 3", "SRS 4 (Far)");
	foreach my $status (-4 .. 6) {
	    my $name = $srs_names[$status + 4];
	    my $vocab_id = $row_ref->[COL_VOCAB_ID];
	    $menu_item = Gtk2::MenuItem->new($name);
	    $menu_item->signal_connect(
		activate => sub {
		    warn "Will set status for $panel kanji $kanji to $name";
		    Learnable::KanjiVocab->set_update_status($status,
							     vocab_id => $vocab_id);
		    $self->{"ff_$panel"}->update;
		}
	    );
	    $menu_item->show;
	    $menu->append($menu_item);
	    
	}
    }    

    $menu->popup(undef,undef,undef,undef,$event->button, $event->time);
    
    return 1;			# indicates we consumed the event
}

sub build_matched {
    my $self = shift;
    Gtk2::Ex::FormFactory::Form->new(
	expand  => 1,
	content => [
	    Gtk2::Ex::FormFactory::Label->new(
		label   => "Vocab with matching readings",
	    ),
	    $self->{ff_matched} =
	    Gtk2::Ex::FormFactory::List->new(
		attr    => "kanji.matched",
		columns => ["JLPT", "Vocab_id", "Vocab", "Reading", "Yomi_id", "Type", "Kana", "Status#", "Status"],
		visible => [1,0,1,1,0,1,1,0,1], # don't display vocab/yomi id
		height  => 400,
		scrollbars => ["never", "automatic"],
		expand => 1,
		selection_mode => "multiple",
		signal_connect => {
		    button_press_event => sub {
			my ($sl,$event) = @_;
			return ($event->button == 3);
		    },
		    button_release_event => sub {
			$self->vocab_panel_popup_menu(@_, "matched");
		    }
		},		
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
	    $self->{ff_failed} = Gtk2::Ex::FormFactory::List->new(
		attr    => "kanji.failed",
		columns => ["JLPT", "Vocab_id", "Vocab", "Reading", "Status#", "Status"],
		visible => [1,0,1,1,0,1],
		height  => 140,
		scrollbars => ["never", "automatic"],
		expand => 1,
		selection_mode => "multiple",
		signal_connect => {
		    button_press_event => sub {
			my ($sl,$event) = @_;
			return ($event->button == 3);
		    },
		    button_release_event => sub {
			$self->vocab_panel_popup_menu(@_, "failed");
		    }
		},
	    )
	]
    )
}

sub launch_kanji_window {
    my $self = shift;
    my $kanji = $self->{kanji};

    return if exists $kanji_windows{$kanji};

    my $win = new GUI::KanjiDetails(
	kanji => $kanji,
	death_hook => sub {
	    warn "In death callback for Kanji window $kanji\n";
	    delete $kanji_windows{$kanji};
	}
    );
    die "Failed to launch kanji window '$kanji'\n" unless ref($win);
    $kanji_windows{$kanji} = $win;
}

1;
