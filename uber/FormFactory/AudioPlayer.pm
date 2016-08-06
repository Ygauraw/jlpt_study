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

# Class data: player script that will be the same for all instances.
# I'll write my local (Perl) accessors so that they each call JS
# routines below. That helps to keep most of the complexity in one
# place.
our $player_script = <<'END';

var audio;
var len;
var trackno    = 0;

// Replace the implementation with something that's more "eventy" than
// what I had before. The point is to make it easier to see the
// underlying state machine event points as well as to make a
// play/pause feature easier to code.

function init() {

  audio     = document.getElementById("audio");
  trackno   = 0;
  len       = playlist.length;

  if (debug) {  console.log("In init()"); }

  // set up event listeners
  audio.addEventListener("ended",      onend_trigger);
  audio.addEventListener("loadeddata", onload_trigger);
  // delay trigger is queued during onend_trigger

  // start the cycle
  load_audio(audio, trackno);

}

// These triggers will keep going round and round if both loop and
// auto_play are set. If the chain stops it should be restartable
// again by calling audio.play, which in turn will go through the
// state triggers in the following order:
//
// onload_trigger -> onend_trigger -> delay_trigger -> onload_trigger -> ...


function onload_trigger() {
  if (debug) { console.log ("In onload_trigger()"); }
  if (auto_play) { 
    if (debug) { console.log("onload_trigger(): auto-playing"); }
    if (play_state != "pause") { audio.play(); }
  }
}

function onend_trigger() {
  if (debug) { console.log ("In onend_trigger()"); }
  setTimeout(delay_trigger, delay);
}

function delay_trigger() {
  if (debug) { console.log ("In delay_trigger()"); }
  trackno = (trackno + 1) % len;
  load_audio(audio, trackno);
  if (trackno == 0) {
      if (!loop) {
         if (debug) { console.log("delay_trigger: Rolled over, but not looping"); }
         play_state = "pause";
         return;
      }
  }
}


// called when body has finished loading
function init_old() {
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
  if (debug) { console.log ("in play(); play_state is " + play_state) }
  if (play_state == "play") { return }
  play_state = "play";
  audio.play() ;
}
function load_audio(player, trackno) {
  player.src = playlist[trackno];
  player.load();
}
function pause() {
  if (debug) { console.log ("in pause(); play_state is " + play_state) }
  play_state = "pause";
  audio.pause() ;
}
function clear_playlist() {
  audio.pause ;
  playlist = [];
  trackno  = 0;
  len      = 0;
}
function set_auto_play(newvalue) {
  auto_play = newvalue;
}
function add_playlist_item (item) {
  playlist.push(item);
  len = playlist.length;
}
function set_delay(ms) {
  delay = ms;
}
function set_loop(newvalue) {
  loop = newvalue;
}
function set_auto_advance(newvalue) {
  auto_advance = newvalue;
}
END


# Accessors. These are for the Perl side, which only deals with
# initial construction of the webkit + html + script bundle. To get
# access to the state of the WebKit object, we need different sub.
sub get_track_delay_ms          { shift->{track_delay_ms}               }
sub get_uri_base                { shift->{uri_base}                     }
sub get_auto_play               { shift->{auto_play}                    }
sub get_playlist                { shift->{playlist}                     }
sub get_play_state              { shift->{play_state}                   }
sub get_loop                    { shift->{loop}                         }
sub get_debug                   { shift->{debug}                        }
sub get_allow_file_uri          { shift->{allow_file_uri}               }
sub get_auto_advance            { shift->{auto_advance}                 }
sub get_text                    { shift->{text}                         }

sub set_track_delay_ms          { shift->{track_delay_ms}       = $_[1] }
sub set_uri_base                { shift->{uri_base}             = $_[1] }
sub set_auto_play               { shift->{auto_play}            = $_[1] }
sub set_play_state              { shift->{play_state}           = $_[1] }
sub set_loop                    { shift->{loop}                 = $_[1] }
sub set_debug                   { shift->{debug}                = $_[1] }
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
    my $playlist  = shift;
    my $auto_play = shift;
    $self->{playlist} = $playlist;
    
}
sub set_autoplay {
    my $self = shift;
    my $ap   = shift;
    # I think that we should always have the autoplay tag set:
    #    $self->get_gtk_webkit_webview()->execute_script(
    #	'document.getElementById("audio").' .
    #	"autoplay = $ap;"
    #	)	;

    # So instead, use our auto_play variable
    $self->get_gtk_webkit_webview()->execute_script("auto_play = $ap");
}

sub play {
    my $self = shift;
    $self->set_play_state("play");
    $self->get_gtk_webkit_webview()->execute_script('play();');
}

sub pause {
    my $self = shift;
    $self->set_play_state("pause");
    $self->get_gtk_webkit_webview()->execute_script('pause();');
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
	debug          => 1,
	initial_text   => 'Initial WebKit text',
        @_,			# user args

	width          => 400,	# parent class args
        height         => 60,
    );

    my $self = $class->SUPER::new(%o);

    # stash options (using hash slice to pull out option keys)
    my ($track_delay_ms, $auto_play, $auto_advance, $uri_base, $playlist, 
	$allow_file_uri, $loop, $debug) =
	@o{qw/track_delay_ms auto_play auto_advance uri_base playlist
              allow_file_uri loop debug/};

    $self->set_track_delay_ms($track_delay_ms);
    $self->set_auto_play($auto_play);
    $self->set_auto_advance($auto_advance);
    $self->set_uri_base($uri_base);
    $self->set_playlist($playlist);
    $self->set_loop($loop);
    $self->set_debug($debug);
    $self->set_allow_file_uri($allow_file_uri);

    $self->set_play_state("play");

    # Don't call $self->set_text until widget is built...
    $self->{text} = $o{initial_text};
    
    return $self;
}

sub build_html {
    my $self = shift;

    my $auto_play    = $self->get_auto_play;
    my $play_state   = $self->get_play_state;
    my $auto_advance = $self->get_auto_advance;
    my $delay        = $self->get_track_delay_ms;
    my $debug        = $self->get_debug;
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
    $html.="var play_state   = \"$play_state\";\n";
    $html.="var auto_advance = $auto_advance;\n";
    $html.="var loop         = $loop;\n";
    $html.="var delay        = $delay;\n";
    $html.="var debug        = $debug;\n";

    # Now add our other script functions
    $html.=$player_script;    
    
    $html.="</script>\n";

    # Note that body has an 'onload' event associated with it
    # Also, I'm keeping autoplay on in the audio element
    $html.="</head><body onload=\"init()\">";
    $html.="<audio id=\"audio\" preload=\"auto\" tabindex=\"0\">";
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
    
