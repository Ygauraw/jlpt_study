#!/usr/bin/perl

use utf8;

my $test_string = '
<div style="font-size:60px">
<ruby>
    漢<rt> かん</rt>
    字<rt> じ </rt>
</ruby><!--<br/>-->
<ruby>
    漢字<rt> かんじ</rt>
</ruby>
</div> <div><button id="0001">Foo</button>
';
use Gtk2 -init;
use Gtk2::WebKit;

my $window = Gtk2::Window->new;
$window->set_default_size(600,400);

my $vbox   = Gtk2::VBox->new(0);
my $sw     = Gtk2::ScrolledWindow->new;
my $view   = Gtk2::WebKit::WebView->new;

$sw->add($view);

$view->signal_connect("selection-changed", sub { print "Event ". join ", ", @_ } );

$vbox->add($sw);
my $ok_button = Gtk2::Button->new("Quit");
$vbox->add($ok_button);
$window->add($vbox);

#$view->open('http://perldition.org');
$view->load_html_string($test_string,"");
$view->load_html_string($test_string,"");

$window->signal_connect ("delete_event", do_quit);
$ok_button->signal_connect ("clicked", do_quit);

sub do_quit {
    Gtk2->main_quit;
}

$window->show_all;
Gtk2->main;
