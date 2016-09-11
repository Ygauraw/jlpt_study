# package for kanji window

package GUI::KanjiDetails;

use FormFactory::KanjiVG;
use Model::KanjiReadings;


our $format = <<'_END';
+---------+-+----------------+-----------+---------+
^ Image   | | RTKOfficial    | MyRTK     | TagHead |
|         | +----------------+-----------+---------+
|         | | RTKStory                   | TagList |
|         | |                            |         |
+---------+ |                            +---------+
^ JLPT    | |                            | NewTag  |
+---------+ +----------------------------+---------+
^ Jouyou  | | OtherEnglish                         |
+---------+ +--------------------------------------+
^ RTK     | | NoteHead                             |
+---------+ +--------------------------------------+
| Status  | | Notes                                |
|         | |                                      |
|         | |                                      |
+---------+-+--------------------------------------+
_END


sub new {
    my $class = shift;
    my %opts = (
	context => undef,
	kanji   => undef,
	toplevel => 0,
	@_,
    );

    my $kanji   = $opts{kanji}   or die "KanjiWindow needs kanji => char option\n";
    my $context = $opts{context} or die "KanjiWindow needs context => ref option\n";

    my $self = bless { context => $context, kanji => $kanji,
		       toplevel => $opts{toplevel},
		       _kanji => KanjiReadings::Kanji->retrieve($kanji) };

    # GUI-related
    $context->add_object(
	name => "gui_kanji_$kanji",
	object => $self,
	attr_depends_href => {
	    x => "y",
	}
    );

    $self->build_window;
    $self->{ff}->open;
    $self->{ff}->update_all;

    return $self;
}

sub build_window {

    my $self = shift;
    my $context = $self->{context};

    $self->{ff} = Gtk2::Ex::FormFactory->new(
	content => [
	    Gtk2::Ex::FormFactory::Window->new(
		label => "Editing Kanji . $self->{kanji}",
		context => $context,
		content => [
		    $self->build_table,
		]
	    )
	]
    )
}


sub build_table {
    my $self = shift;
    my $kanji = $self->{kanji};
    Gtk2::Ex::FormFactory::Table->new(
	expand => 1,
	layout => $format,
	content => [
	    Gtk2::Ex::FormFactory::Label->new(label => "Image"),
	    Gtk2::Ex::FormFactory::Label->new(label => "RTK Official"),
	    Gtk2::Ex::FormFactory::Label->new(label => "My RTK"),
	    Gtk2::Ex::FormFactory::Label->new(label => "TagHead"),
	    Gtk2::Ex::FormFactory::Label->new(label => "RTK Story"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Tag List"),
	    Gtk2::Ex::FormFactory::Label->new(label => "JLPT"),
	    Gtk2::Ex::FormFactory::Label->new(label => "New Tag"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Jouyou"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Other English"),
	    Gtk2::Ex::FormFactory::Label->new(label => "RTK"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Note Heading"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Status"),
	    Gtk2::Ex::FormFactory::Label->new(label => "Notes"),
	]
    );
    
}

sub build_kanjivg_image {
    Gtk2::Ex::FormFactory::Image->new(
	attr => "kanji.image_file",
	bgcolor => "#ffffff",
	scale_to_fit => 1, 
    );
}
