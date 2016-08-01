##
## Use a Gtk2::WebKit::WebView object for its <audio> tag support.
## Wrap this up as a new Widget type in FormFactory.
##

package Gtk2::Ex::FormFactory::AudioPlayer;

use base Gtk2::Ex::FormFactory::Widget;

use Glib qw/TRUE FALSE/;
use Gtk2::WebKit;

use strict;
use warnings;

# accessors 
sub get_track_delay_ms          { shift->{track_delay_ms}               }
sub get_uri_base                { shift->{uri_base}                     }
sub get_auto_play               { shift->{auto_play}                    }
sub get_playlist                { shift->{playlist}                     }
sub get_allow_file_uri          { shift->{playlist}                     }

sub set_track_delay_ms          { shift->{track_delay_ms}       = $_[1] }
sub set_uri_base                { shift->{uri_base}             = $_[1] }
sub set_auto_play               { shift->{auto_play}            = $_[1] }
sub set_playlist                { shift->{playlist}             = $_[1] }
sub set_allow_file_uri          { shift->{allow_file_uri}       = $_[1] }

# stash the gtk widget(s)
sub get_gtk_vbox                { shift->{gtk_vbox}                     }
sub get_gtk_webkit_webview      { shift->{gtk_webkit_webview}           }
sub set_gtk_vbox                { shift->{gtk_vbox}             = $_[1] }
sub set_gtk_webkit_webview      { shift->{gtk_webkit_webview}   = $_[1] }

# mandatory for subclassing from Gtk2::Ex::FormFactory::Widget
sub get_type { 'audio_player' }

sub new {
    my $class = shift;
    my %o = (			# default args
	track_delay_ms => 600,
	auto_play      => 1,
	uri_base       => '',
	playlist       => undef,
	allow_file_uri => 1,
	@_,			# user args
	width          => 0,	# parent class args
	height         => 0,
     );

    my $self = $class->SUPER::new(%o);

    # stash options (using hash slice to pull out option keys)
    my ($track_delay_ms, $auto_play, $uri_base, $playlist, $allow_file_uri) =
	@o{qw/track_delay_ms auto_play uri_base playlist allow_file_uri/};

    $self->set_track_delay_ms($track_delay_ms);
    $self->set_auto_play($auto_play);
    $self->set_uri_base($uri_base);
    $self->set_playlist($playlist);
    $self->set_allow_file_uri($allow_file_uri);

    return $self;
}

sub build_html {
    my $self = shift;

    my $auto_play = $self->get_auto_play;
    my $autoplay = $auto_play ? "autoplay" : ""; # HTML tag

    my $html = "<audio $autoplay id=\"audio\" preload=\"auto\" tabindex=\"0\">";

    my $playlist = $self->get_playlist;

    # The following will be replaced with JS code later
    
    if (defined $playlist) {
	# playlist items will be just URIs. We could have specified
	# content type, too, but I think it will work fine if we stick
	# with just a filename for now and omit the content-type 
	foreach my $uri (@$playlist) {
	    $html .= "<source src=\"$uri\">\n";  #  type="audio/mp3">
	}
    }

    $html.="Your browser does not support the audio element.\n</audio>";

    warn $html;
    
    my $wv   = $self->get_gtk_webkit_webview;
    my $base = $self->get_uri_base;
    $wv->load_html_string($html, $base);

}

sub build_widget {

    my $self = shift;

    # Build up in terms of basic GTK widgets

    my $vbox = Gtk2::VBox->new(0,10);
    my $wv   = Gtk2::WebKit::WebView->new;

    $self->set_gtk_vbox($vbox);
    $self->set_gtk_webkit_webview($wv);

    $self->build_html;
    
    $vbox->add($wv);

    # Call super to tell it which Gtk widget we are
    $self->set_gtk_widget($vbox);
    
    1;

}

1;


__END__
    
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

    # $wv->hide; # doesn't seem to do anything

    $wv->load_html_string(
	'An image:<p><a href="core_6000/assets0/assets/legacy/images/02/5231321.jpg">
           <img src="core_6000/assets0/assets/legacy/images/02/5231321.jpg">
         </a>' . 
	'<p> <audio autoplay id="audio" preload="auto" tabindex="0"  >
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
