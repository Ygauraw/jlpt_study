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

# Class data: player script that will be the same for all instances
our $player_script = <<'END';

var audio;
var len;
var trackno   = 0;

function init() {
  audio     = document.getElementById("audio");
  trackno   = 0;
  len       = playlist.length;

  // Can't use the following to introduce a delay because the timeout
  // is created at the time this statement is executed rather than
  // when the event triggers:
  //
  // audio.onended = setTimeout(advance, delay);

  console.log("In init()");

  // apparently audio.onended = ... is not supported:
  //  audio.onended = function() {
  //      console.log("In onended callback"); 
  //      after(); 
  //  };

  // Instead use addEventListener
  audio.addEventListener("ended", after);

  load_audio(audio, trackno);  
  if (auto_play) {
    console.log("auto_play variable on, auto-playing");

    // it appears that autoplay is needed on the <audio> element. Its
    // purpose is to auto-play when the media file actually loads.
    // Without the autoplay attribute, the following does nothing,
    // presumably because the file hasn't been loaded yet. An
    // alternative way to fix this would probably be to add an onload
    // event trigger
    play();
  }
}
function after() {
  console.log ("Got to after()");
  if (!auto_advance) { return };
  wait_timer = setTimeout(advance, delay);
}
function advance() {
  console.log ("Got to advance()");
  // remove event listener (we'll add later if needed)
  audio.removeEventListener("ended",after);
  trackno = (trackno + 1) % len;
  if (trackno == 0) {
      if (!loop) {
         console.log("Rolled over, but not looping");
         return;
      }
  }
  load_audio(audio, trackno);
  // add event listener back in
  audio.addEventListener("ended", after);
  audio.play();
}
function play() {
  audio.play ;
}
function load_audio(player, trackno) {
  player.src = playlist[trackno];
}
END


# Accessors. These are for the Perl side, which only deals with
# initial construction of the webkit + html + script bundle. To get
# access to the state of the WebKit object, we need different sub.
sub get_track_delay_ms          { shift->{track_delay_ms}               }
sub get_uri_base                { shift->{uri_base}                     }
sub get_auto_play               { shift->{auto_play}                    }
sub get_playlist                { shift->{playlist}                     }
sub get_loop                    { shift->{loop}                         }
sub get_allow_file_uri          { shift->{allow_file_uri}               }
sub get_auto_advance            { shift->{auto_advance}                 }
sub get_text                    { shift->{text}                         }

sub set_track_delay_ms          { shift->{track_delay_ms}       = $_[1] }
sub set_uri_base                { shift->{uri_base}             = $_[1] }
sub set_auto_play               { shift->{auto_play}            = $_[1] }
sub set_loop                    { shift->{loop}                 = $_[1] }
sub set_allow_file_uri          { shift->{allow_file_uri}       = $_[1] }
sub set_auto_advance            { shift->{auto_advance}         = $_[1] }

sub quotify_text {
    local($_) = shift;
    s/\"/\\\"/g;
    s/^(.*)$/\"$1\"/;
    $_;
}
# set_text and set_playlist call for some JS injection as well as
# updating local structures
sub set_text {
    my $self = shift;
    my $text = shift;
    warn "text was " .     $self->{text};
    $self->{text} = $text;

    warn "in set_text, webview object is a " . ref($self->get_gtk_webkit_webview());
    $self->get_gtk_webkit_webview()->execute_script(
	'document.getElementById("textarea").' .
	'innerHTML = ' . quotify_text("$text") . ";"
	)	
}
sub set_playlist {
    my $self = shift;
    my $playlist = shift;
    $self->{playlist} = $playlist;    
}


# stash the gtk widget(s)
sub get_gtk_vbox                { shift->{gtk_vbox}                     }
sub get_gtk_webkit_webview      { shift->{gtk_webkit_webview}           }
sub set_gtk_vbox                { shift->{gtk_vbox}             = $_[1] }
sub set_gtk_webkit_webview      { shift->{gtk_webkit_webview}   = $_[1] }

# mandatory for subclassing from Gtk2::Ex::FormFactory::Widget
sub get_type { 'audio_player' }

sub new {
    my $class = shift;
    my %o = (
        track_delay_ms => 600,	# default args
	playlist       => undef,
	auto_play      => 1,
	auto_advance   => 1,
	loop           => 0,
	uri_base       => '',
	allow_file_uri => 0,
	initial_text   => 'Initial WebKit text',
        @_,			# user args

	width          => 400,	# parent class args
        height         => 60,
    );

    my $self = $class->SUPER::new(%o);

    # stash options (using hash slice to pull out option keys)
    my ($track_delay_ms, $auto_play, $auto_advance, $uri_base, $playlist, 
	$allow_file_uri, $loop) =
	@o{qw/track_delay_ms auto_play auto_advance uri_base playlist
              allow_file_uri loop/};

    $self->set_track_delay_ms($track_delay_ms);
    $self->set_auto_play($auto_play);
    $self->set_auto_advance($auto_advance);
    $self->set_uri_base($uri_base);
    $self->set_playlist($playlist);
    $self->set_loop($loop);
    $self->set_allow_file_uri($allow_file_uri);

    # Don't call $self->set_text until widget is built...
    $self->{text} = $o{initial_text};
    
    return $self;
}

sub build_html {
    my $self = shift;

    my $auto_play    = $self->get_auto_play;
    my $auto_advance = $self->get_auto_advance;
    my $delay        = $self->get_track_delay_ms;
    my $loop         = $self->get_loop;
    my $text         = $self->get_text;

    # for setting the attribute to the HTML <audio> tag
    my $autoplay = $auto_play ? "autoplay" : "";
    
    # Might as well make this somewhat well-formed so that I can put
    # scripts in the document head section
    my $html = "<html><head>";

    # Convert URIs in playlist into a Javascript array 'playlist[]'
    my $playlist = $self->get_playlist;
    my $js_playlist = '';
    if (defined $playlist) {
	# playlist items will be just URIs. We could have specified
	# content type, too, but I think it will work fine if we stick
	# with just a filename for now and omit the content-type 
	foreach my $uri (@$playlist) {
	    $js_playlist .= "'$uri',"; # don't need source/src
	}
	$js_playlist=~s/,$//;
    }
    $html.="<script>\n";
    $html.="var playlist     = [ $js_playlist ];\n";
    $html.="var auto_play    = $auto_play;\n";
    $html.="var auto_advance = $auto_advance;\n";
    $html.="var loop         = $loop;\n";
    $html.="var delay        = $delay;\n";

    # Now add our other script functions
    $html.=$player_script;    
    
    $html.="</script>\n";

    # Note that body has an 'onload' event associated with it
    $html.="</head><body onload=\"init()\">";
    $html.="<audio $autoplay id=\"audio\" preload=\"auto\" tabindex=\"0\">";
    $html.="Your browser does not support the audio element.\n</audio>\n";

    $html.="<div id=\"textarea\">$text</div>\n";
    $html.="</body></html>";

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

    #die "in build_widget, wv is a " . ref($wv);
    
    $self->set_gtk_vbox($vbox);
    $self->set_gtk_webkit_webview($wv);

    # Normally you get "Not allowed to load local resource: ..." if
    # you try to access a file URI without setting the base_uri to
    # file:///something.... The base_uri method is preferable to
    # turning this option on...
    my $settings = Gtk2::WebKit::WebSettings->new;
    $settings->set("enable-file-access-from-file-uris", 
		   $self->get_allow_file_uri);
    # $settings->set("enable-universal-access-from-file-uris",$allow_file_uri);
    $wv->set_settings($settings);

    $self->build_html;
    
    $vbox->add($wv);

    # Maybe it hasn't loaded yet?
#    warn "before";
#    $self->set_text($self->{text});
#    warn "after";
   
    # Call super to tell it which Gtk widget to place
    $self->set_gtk_widget($vbox);
    
    1;

}

1;


__END__
    
