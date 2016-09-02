package Gtk2::Ex::FormFactory::KanjiVG;

# A small wrapper around FF::Image to display a KanjiVG graphic for a kanji

use parent Gtk2::Ex::FormFactory::Image;

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

    
};

# "Public interface" is through setting the kanji attribute
sub 

sub get_image_file {
    my $self = shift;
    my $kanji = $self->kanji;
    warn "Asked to get image file, kanji is $kanji\n";
    my $unicode = sprintf("%05x", ord $kanji);

    my $filename = "$kanjivg_dir/$unicode.svg";
    return $filename;
}
