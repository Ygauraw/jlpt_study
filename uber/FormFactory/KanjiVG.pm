package Gtk2::Ex::FormFactory::KanjiVG;

# Widget for displaying a KanjiVG graphic for a kanji
#
# Originally, I was inheriting from FormFactory::Image, but what I
# want from this widget is to give a kanji and have the internal
# workings that map that kanji onto a filename hidden. The FF::Image
# implementation doesn't really allow that since the context object
# that the widget is bound to has to be the filename. Therefore, I'm
# inheriting from Widget instead and copying a load of code from the
# official FF::Image source.

# Thinking about this again, I'll also have to write code for the
# "Layout" (build_TYPE($widget)), or implement a build_widget routine
# here. I'm also thinking of whether it's possible to get better
# rendering of the SVG, perhaps by avoiding scaling per se and simply
# reloading the file at the desired resolution.
#
# So, actually, there's a bit more work here than I expected, so I'll
# put it off for now.

use base Gtk2::Ex::FormFactory::Widget;

use Glib qw/TRUE FALSE/;
use Gtk2::WebKit;

use strict;
use warnings;

our $kanjivg_dir = '/home/dec/JLPT_Study/kanjivg/kanjivg-r20160426/kanji';

sub get_type { "kanji_vg" }
sub new {
    my $class = shift;
    my %opts  = (
	context  => undef,
	kanji    => 0,
	attr     => undef,
	@_
    );

    my $self = $class->SUPER::new(@_);
    die unless ref($self);

    my $context = $self->{context};
    die unless ref($context);

    $context->add_object(
	
    );


    $self;
};

# "Public interface" is through setting the kanji attribute
sub get_kanji { shift -> {kanji} }
sub get_image_file {
    my $self = shift;
    my $kanji = $self->kanji;
    warn "Asked to get image file, kanji is $kanji\n";
    my $unicode = sprintf("%05x", ord $kanji);

    my $filename = "$kanjivg_dir/$unicode.svg";
    return $filename;
}

1;
