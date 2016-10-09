# package for kanji window

package GUI::KanjiDetails;

use FormFactory::KanjiVG;
use Model::KanjiReadings;
use Model::Learnable;
use Model::BreenKanji;

use strict;
use warnings;

our $format = <<'_END';
+->-------+-+->--------------+->---------+---------+
^ Image   | ' RTKOfficial    ' MyRTK     ' TagHead |
|         | |                |           |         |
|         | +->--------------+-----------+---------+
|         | ^ RTKStory                   ^ TagList |
|         | |                            |         |
+---------+ |                            +---------+
' JLPT    | |                            ' NewTag  |
+---------+ +----->----------------------+---------+
' Jouyou  | ' OtherEnglish                         |
+---------+ +--------------------------------------+
' OldStat | | NoteHead                             |
+---------+ +->------------------------------------+
' NewStat | ^ Notes                                |
+---------+ |                                      |
'         | |                                      |
|         | |                                      |
|         | |                                      |
+---------+-+--------------------------------------+
_END
our $kanjivg_dir = '/home/dec/JLPT_Study/kanjivg/kanjivg-r20160426/kanji';

sub new {
    my $class = shift;
    my %opts = (
	context => undef,
	kanji   => undef,
	death_hook => undef,
	toplevel => 0,
	@_,
    );

    my $kanji   = $opts{kanji}   or die "KanjiWindow needs kanji => char option\n";

    # Rethinking how FF works. Why not have a separate context for
    # each KanjiDetails window? 

    die "Don't supply us with a context" if defined $opts{context};
    
    #    my $context = $opts{context} or die "KanjiWindow needs context => ref option\n";
    my $context = Gtk2::Ex::FormFactory::Context->new;

    # Use a unique object name for attributes in this window
    my $basename = "gui_kanji_$kanji";

    my $self = bless { context => $context, kanji => $kanji,
		       toplevel => $opts{toplevel},
		       basename => $basename,
		       death_hook => $opts{death_hook},
		       _kanji => KanjiReadings::Kanji->retrieve($kanji) };

    # GUI attributes; won't use depends since FF won't be synchronous
    $context->add_object(
	name => $basename,
	object => $self,
    );

    $self->build_window;
    $self->{ff}->open;
    $self->{ff}->update_all;

    return $self;
}

sub build_window {

    my $self = shift;
    my $context = $self->{context};
    my $basename = $self->{basename};

    $context->add_object(
	name => "$basename.notes",
	object => $self
    );
#    $context->add_object(
#	name => "$basename.newstatus",
#	object => $self
#    );
    
    # I don't want every keystroke in a notes-type box to trigger a
    # database write, so I'll try setting sync to false on the
    # top-level FormFactory. That way I hope to be able to persist all
    # changes automatically at the same time once the window closes.
    # Since there aren't many interdependent widgets, this shouldn't
    # cause too many problems.

    $self->{ff} = Gtk2::Ex::FormFactory->new(
	sync    => 0,
	context => $context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new(
		title => "Editing Kanji $self->{kanji}",
		height => 400,
		width => 600,
		content => [
		    $self->build_table,
		],
		closed_hook => sub {
		    $self->{ff}->ok();
		    if (defined $self->{death_hook}) {
			$self->{death_hook}->();
		    }
		    # No need to clean up since we use a local context:
		    # $self->{context}->remove_object($self->{basename});
		}
	    )
	]
    );
}

sub get_story {
    "Default story value"
}
sub set_story {
    my $self = shift;
    warn "Setting story to $_[0]\n";
    $self->{story} = $_[0];
}

sub get_note {
    my $self = shift;
    Learnable::Kanji->get_note(kanji => $self->{kanji});
}
sub set_note {
    my $self = shift;
    my $note = shift;
    warn "Setting notes to $note\n";
    Learnable::Kanji->set_update_note($note, kanji => $self->{kanji});
}

sub build_table {
    my $self = shift;
    my $kanji = $self->{kanji};
    my $basename = $self->{basename};
    warn "Basename is $basename\n";
    Gtk2::Ex::FormFactory::Table->new(
	expand => 1,
	layout => $format,
	content => [
	    $self->build_kanjivg_image,
	    Gtk2::Ex::FormFactory::Label->new(label => "RTK Official"),
	    Gtk2::Ex::FormFactory::Label->new(label => "My RTK"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Tags"),
	    Gtk2::Ex::FormFactory::TextView->new(attr => "$basename.story"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Tag List"),
	    Gtk2::Ex::FormFactory::Label->new(label => "JLPT"),
	    Gtk2::Ex::FormFactory::Label->new(label => "New Tag"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Jouyou"),
	    Gtk2::Ex::FormFactory::Label->new(attr  => "$basename.other_english",
					      inactive => 'insensitive',
					      active_cond => sub {1},
	    ),
	    Gtk2::Ex::FormFactory::Label->new(label => "Current Status:  \n  " .
					      Learnable::Kanji->status_text( 
					      Learnable::Kanji->get_status(
						  kanji => $kanji))),
	    Gtk2::Ex::FormFactory::Label->new(label => "Enter kanji notes below"),
	    Gtk2::Ex::FormFactory::Popup->new(attr => "$basename.newstatus",
			      items => Model::Learnable->get_statuses_2d
	    ),
	    Gtk2::Ex::FormFactory::TextView->new(attr => "$basename.note"),
	]
    );
}

sub get_other_english {
    my $self = shift;
    my $kanji = $self->{kanji};
    my @en_means = ();
    my $iter = BreenKanji::EngMeaning->search(literal => $kanji);
    while (my $line = $iter->next) { push @en_means, $line->english }
    return "English Meaning(s): " . join ", ", @en_means;
}

#sub get_newstatus_list {
#    my $self = shift;
#    my $kanji = $self->{kanji};
#    return Model::Learnable->get_statuses_hash
#}
sub get_newstatus {
    my $self = shift;
    my $kanji = $self->{kanji};
    Learnable::Kanji->get_status(kanji => $kanji);
}
sub set_newstatus {
    my $self = shift;
    my $value = shift;
    my $kanji = $self->{kanji};
    warn "Asked to set status for kanji $kanji to $value\n";
    Learnable::Kanji->set_update_status($value, kanji => $kanji);
}

sub get_kanji_file {
    my $self = shift;
    my $kanji = $self->{kanji};
    warn "Asked to get image file, kanji is $kanji\n";
    my $unicode = sprintf("%05x", ord $kanji);

    my $filename = "$kanjivg_dir/$unicode.svg";
    return $filename;
}

sub build_kanjivg_image {
    my $self = shift;
    my $basename = $self->{basename};
    Gtk2::Ex::FormFactory::Image->new(
	attr => "$basename.kanji_file",
	bgcolor => "#ffffff",
	scale_to_fit => 1,
    );
}
