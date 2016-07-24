#!/usr/bin/perl

use strict;
use warnings;

use Glib qw/TRUE FALSE/;
use Gtk2 -init;
use Gtk2::WebKit;


use utf8;

use DBI;

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=core_2k_6k.sqlite", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );
my ($sth, $rc);
die unless ref($dbh);


# The first thing I want to sort out here is checking how to get audio
# working. I believe it can be done with Webkit:
#
# Upload a page with an audio tag and appropriate options to make it work
# like a playlist with play controls and such
#
# Inject JavaScript that tells the object to load items into the
# playlist.
#
# Trap requests to load the media files and serve them ourselves from
# the Gtk callback handler. Something to do with trapping the
# navigation-policy-decision-requested callback.
#
# https://webkitgtk.org/reference/webkitgtk/stable/webkitgtk-webkitwebview.html#WebKitWebView-navigation-policy-decision-requested
#
# Also, in webkitgtk-webkitdownload.html
# 
#   WebKitDownload carries information about a download request,
#   including a WebKitNetworkRequest object. The application may use
#   this object to control the download process, or to simply figure
#   out what is to be downloaded, and do it itself.
#
#
# I could also use a custom URI scheme. See:
#
# http://stackoverflow.com/questions/3238483/how-to-handle-a-custom-url-scheme-in-webkit-gtk
# https://webkitgtk.org/reference/webkit2gtk/stable/WebKitWebContext.html#webkit-web-context-register-uri-scheme
#
# OK, my version of webkit doesn't seem to have the stuff for
# registering custom URI schemes.
#
# resource-request-starting
#
# I can test the second part (the callback handler) by starting off
# sending an image.
#

# After some experiments, it seems that I could just forget about
# callbacks since I don't need to pull files out of a database. All I
# need to worry about is enforcing the proper security policy.

my $mw = Gtk2::Window->new('toplevel');
$mw->set_default_size(600,400);
$mw->signal_connect ("delete_event", sub { Gtk2->main_quit; });

my $vbox = Gtk2::VBox->new(0,10);
$mw->add($vbox);

my $webview = UI::WebView->new;
$vbox->add($webview->gtk);

my $quit = Gtk2::Button->new("Quit");
$quit->signal_connect ("clicked", sub { Gtk2->main_quit; });

    
$vbox->add($quit);

$mw->show_all;
Gtk2->main;

package UI::WebView;

use Glib qw/TRUE FALSE/;
use Gtk2::WebKit;

# simple accessors
sub gtk {    shift -> {gtk};  }

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;

    my $wv = $self->{gtk} = Gtk2::WebKit::WebView->new;
#    $wv->set_size(600,400);

    # Ignore this part; jump straight to accessing local files without
    # using custom callbacks
    if (0) {
	$wv->load_html_string(
	    'Please click on <a href="custom://foo">me</a>',
	    'file://');
	$wv->signal_connect("resource-request-starting", 
			    sub { $self->load_file_callback(@_) });
    }

    # OK, we get "Not allowed to load local resource: ..." for the below
    #my $settings = $wv->get_settings;
    my $settings = Gtk2::WebKit::WebSettings->new;
    $settings->set("enable-file-access-from-file-uris",TRUE);
    $settings->set("enable-universal-access-from-file-uris",TRUE);
    $wv->set_settings($settings);

    $wv->load_html_string(
	'An image:<p><a href="core_6000/assets0/assets/legacy/images/02/5231321.jpg">
           <img src="core_6000/assets0/assets/legacy/images/02/5231321.jpg">
         </a>' . 
	'<p> <audio autoplay id="audio" preload="auto" tabindex="0" controls="" >
          <source src="file:///home/dec/JW03182A.mp3"" type="audio/mp3">
          Your browser does not support the audio element.
         </audio> '
,
	'file:///home/dec/JLPT_Study/');

    
    return $self;
}

# failed attempt: ...
sub load_file_callback {

    my $self = shift or die;

    my ($view, $frame, $resource, $net_req) = @_;
    
    warn "got here ($self)\n";
    print "Got args:\n" . join "\n", (map { ref($_) } @_);

    my $new_resource = Gtk2::WebKit::WebResource->new(
	"New page", "custom://foo", "text/html", "UTF-8", $frame->get_name);

    # crash with infinite loop
    # $frame->load_uri("custom://foo");

    #    $resource->set_data("data", "New Page");

    return 1;
}
