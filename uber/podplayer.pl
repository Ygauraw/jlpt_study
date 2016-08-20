#!/usr/bin/perl

#
# Interface for playing podcasts from JapanesePod101
#
# Initially, this will play local files that I've downloaded and
# collated, but later I will may add external URL capability.

use strict;
use warnings;

use Gtk2 qw/-init/;

use Gtk2::Ex::FormFactory;
use FormFactory::AudioPlayer;
use Model::JPod;

use File::Slurp;
use Encode qw(decode_utf8);	# readdir needs this

# For populating db. Keep distinct Japanese vocab in memory during
# population
my $topdir = '/home/dec/jpod';
my %vocab_ids = ();
my $vocab_seq = 1;

if (@ARGV and $ARGV[0] eq "--populate") {

    warn "This will nuke the tables! Hit enter to continue\n";
    <STDIN>;
    populate();

} else {
    # Main program creates the context and starts the top-level GUI
    my $context = Gtk2::Ex::FormFactory::Context->new;

    my $player_window = GUI::PlayerWindow->new(
	context  => $context,
	filename => 'Newbie/05_New_Year_Greetings/0_NB5_010107_jpod101_review.mp3',
	toplevel => 1,
    );

    Gtk2->main;
}

exit 0;


## Populate the database. 

sub nuke_tables {
    # drop table is easier/faster, but then I have to reload sql
    Model::JPod->begin_work;
    foreach (Model::JPod->Tables) {
	$_->retrieve_all->delete_all;
    }
    Model::JPod->commit;
}


sub traverse_episodes {
    my ($sdir, $sid) = @_;
    my $cdir = "$topdir/$sdir";	# compound dir
    
    my $dh;
    opendir($dh, $cdir) or die "$cdir isn't readable: $!\n";
    my @edirs = sort { # sort numerically on start of string
	my $l = ($a =~ m|^(\d+)| ? $1 : 0);
	my $r = ($b =~ m|^(\d+)| ? $1 : 0);
	$l <=> $r
    } 
    grep { -d "$cdir/$_" and !/^\./ } readdir($dh);
    closedir $dh;

    # Give each episode a sequence number (1...) within the dir. The
    # actual lesson numbers can have gaps.
    my $ep_seq = 1;

    foreach my $edir (@edirs) {
	$edir = decode_utf8($edir);
	my $ep_text = $edir;
	$ep_text =~ tr/_/ /;

	my %mp3_files;
	opendir($dh, "$cdir/$edir") or die "$cdir/$edir isn't readable: $!\n";
	for my $mp3file (grep {/\.mp3$/ } readdir($dh)) {
	    if      ($mp3file =~ /jpod101(_1)?.mp3$/) {
		$mp3_files{main} = $mp3file;
	    } elsif ($mp3file =~ /jpod101_[2-9]+.mp3$/) {
		$mp3_files{other} = $mp3file;
	    } elsif ($mp3file =~ /dialog.mp3$/) {
		$mp3_files{dialogue} = $mp3file;
	    } elsif ($mp3file =~ /review.mp3$/) {
		$mp3_files{review} = $mp3file;
	    } elsif ($mp3file =~ /grammar.mp3$/) {
		$mp3_files{grammar} = $mp3file;
	    } elsif ($mp3file =~ /bonus.mp3$/) {
		$mp3_files{bonus} = $mp3file;
		# the following added just to make sorting through files easier
	    } elsif ($mp3file =~ /kanji.mp3$/) {
		$mp3_files{kanji} = $mp3file;
	    } elsif ($mp3file =~ /informal.mp3$/) {
		$mp3_files{informal} = $mp3file;
	    } elsif ($mp3file =~ /intro.mp3$/) {
		$mp3_files{intro} = $mp3file;
	    } elsif ($mp3file =~ /combo.mp3$/) {
		$mp3_files{combo} = $mp3file;
	    } elsif ($mp3file =~ /bonus.?2.mp3$/) {
		$mp3_files{bonus_2} = $mp3file;
	    } elsif ($mp3file =~ /bonus.?3.mp3$/) {
		$mp3_files{bonus_3} = $mp3file;
	    } else {
		# catch-all for any other files
		if (exists $mp3_files{other}) {
		    die "Episode $cdir/$edir has extra mp3 files\n";
		} else {
		    $mp3_files{other} = $mp3file;
		}
	    }
	}
	closedir $dh;

	# Main episode record
	my $episode = JPod::Episode->insert(
	    {
		series_id     => $sid,
		episode_seq   => $ep_seq++,
		episode_dir   => $edir,
		episode_desc  => $ep_text,
		main_audio    => $mp3_files{main},
	    });
	my $eid = $episode->id;

	# Other audio files
	delete $mp3_files{main} if exists $mp3_files{main};
	foreach (sort { $a cmp $b } keys %mp3_files) {
	    JPod::EpisodeOtherAudio->insert(
		{
		    episode_id  => $eid,
		    audio_type  => ucfirst $_,
		    audio_file  => $mp3_files{$_},
		}
	    );
	}

	# Text files
	opendir($dh, "$cdir/$edir") or die "$cdir/$edir isn't readable: $!\n";
	for my $txtfile (grep {/\.txt$/ } readdir($dh)) {
	    my ($title, $contents)  = ('')x2;
	    
	    if      ($txtfile =~ /^dialogue_transcript/) {
		$title = "Transcript";
	    } elsif ($txtfile =~ /^formal_english/) {
		$title = "Formal Eng.";
	    } elsif ($txtfile =~ /^formal_kana/) {
		$title = "Formal Kana";
	    } elsif ($txtfile =~ /^formal_romaji/) {
		$title = "Formal Romaji";
	    } elsif ($txtfile =~ /^formal.txt/) {
		$title = "Formal";
	    } elsif ($txtfile =~ /^informal_english/) {
		$title = "Informal Eng.";
	    } elsif ($txtfile =~ /^informal_voweled/) {
		$title = "Informal Voweled";
	    } elsif ($txtfile =~ /^informal_romaji/) {
		$title = "Informal Romaji";
	    } elsif ($txtfile =~ /^informal.txt/) {
		$title = "Informal";
	    } elsif ($txtfile =~ /^vocabulary_phrases.txt/) {
		$title = "Vocabulary";
	    } else {
		die "Unknown text file $txtfile\n";
	    }

	    # slurp file
	    $contents = read_file("$cdir/$edir/$txtfile", binmode => ':utf8') 
		or die "Failed to slurp file $!\n";

	    JPod::EpisodeTextFile->insert( {
		episode_id  => $eid,
		file        => $txtfile,
		title       => $title,
		contents    => $contents,
            } );

	    next unless $title eq "Vocabulary";
	    foreach (split /\n/, $contents) {
		next if /^\s*$/;
		my @fields = split /\s+\.\.\.\s+/;

		# I was expecting 3 fields and there were only two
		# exceptions:
		#
		# すぎる ... too ... ;auxiliary verb  ... sugiru
		# カメラ ... camera
		if      (4 == @fields) {
		    @fields = ($fields[0], "$fields[1]$fields[2]", $fields[3]);
		} elsif (2 == @fields) {
		    push @fields, $fields[0];
		}

		my ($ja, $en, $romaji, $vocab_id) = @fields;
		if (exists $vocab_ids{$ja}) {
		    $vocab_id = $vocab_ids{$ja}
		} else {
		    # make a new vocab record
		    $vocab_id = $vocab_seq++;
		    $vocab_ids{$ja} = $vocab_id;
		    JPod::VocabJA->insert({
			vocab_id  => $vocab_id,
			japanese  => $ja
		    });
		}

		# create link record
		JPod::EpisodeVocabLink->insert({
		    episode_id => $eid,
		    vocab_id   => $vocab_id
                });

		# reading
		JPod::VocabReading->insert({
		    vocab_id   => $vocab_id,
		    english    => $en,
		    romaji     => $romaji,
		    # I could probably use Util::JA_Script
		    # to check if we have kana instead of romaji
		    kana       => ''
		});
	    }
	}
	closedir $dh;
    }
}


sub traverse_series {

    my $dh;
    opendir($dh, $topdir) or die "$topdir isn't readable: $!\n";
    my @sdirs = sort { $a cmp $b} 
                grep { -d "$topdir/$_" and !/^\./ and !/qwajibo|tmp/ }
                readdir($dh);
    closedir $dh;

    foreach my $sdir (@sdirs) {
	$sdir = decode_utf8($sdir);
	#warn "$sdir\n";
	my $series_text = $sdir;
	$series_text =~ tr/_/ /;
	my $series = JPod::Series->insert(
	    {
		series_dir => $sdir,
		series_text => $series_text,
	    });
	traverse_episodes($sdir, $series->id);
    }
}

sub populate {
    nuke_tables;
    
    Model::JPod->begin_work;
    traverse_series;
    Model::JPod->commit;
}

sub delete_tables {
    
}

package GUI::Base;

# Small package that all other GUI objects will derive from. Its
# purpose is to provide handling/stashing of common parameters such as
# Context.

sub new {
    my $class = shift;
    my %opt = ( context => 0, toplevel => 0, @_ );
    my ($context)  = $opt{context};
    my ($toplevel) = $opt{toplevel};

    die "Objects deriving from GUI::Base must have context => ... \n"
	unless $context;
    
    return bless {
	context  => $context,
	toplevel => $toplevel,
    }, $class;
}

sub get_context { shift->{context} }
sub set_context { shift->{context} = $_[1] }
sub get_ff { shift->{ff} }
sub set_ff { shift->{ff} = $_[1] }

# Don't know if I'll need this:
sub get_context_object { $_[0]->{context}->get_object($_[1]) }

# Generic message for missing methods in subclasses
our $AUTOLOAD;
sub AUTOLOAD {
    my $class  = shift;
    my $method = $AUTOLOAD;
    die "Class $class does not define a method $method()\n";
};


package GUI::PlayerWindow;

use base 'GUI::Base';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %opts  = (
	filename => undef,
	uri_base => 'file:///home/dec/jpod/',
	debug_audio => 0,
	@_
    );
    my ($filename, $toplevel, $uri_base, $debug_audio) = 
	@opts{qw/filename toplevel uri_base debug_audio/};

    unless (defined $filename) {
	warn "GUI::PlayerWindow needs a filename option\n";
	return undef;
    }
    $self->{filename} = $filename;
    $self->{uri_base} = $uri_base;
    $self->{debug_audio} = $debug_audio;

    $self->build;

    # Move audio widget down so that I can change volume! (persists after exit)
    #$self->{ap_object}->set_text("<br><br><br>");
    
    $self->{ff}->open;
    $self->{ff}->update;
    $self;
}

sub build {
    my $self = shift;
    $self->{ff} = my $ff = Gtk2::Ex::FormFactory->new(
	context => $self->get_context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new(
		title => 'Podcast Player',
		height => 400,
		width  => 400,
		quit_on_close => $self->{toplevel},
		content => [
		    $self->player_widgets(),
		],
	    ),
	],
    );
}

sub player_widgets {
    my $self = shift;
    (
     ($self->{ap_object} =
     Gtk2::Ex::FormFactory::AudioPlayer->new(
	 debug          => $self->{debug_audio},
	 track_delay_ms => 600,
	 auto_advance   => 0,
	 play_state     => "play",
	 uri_base       => $self->{uri_base},
	 playlist       => [$self->{filename}],
	 user_controls  => 1, # HTML5 play/pause/transport ui
     )),
     Gtk2::Ex::FormFactory::Button->new(
	 label => 'Play',
	 clicked_hook => sub { $self->{ap_object}->play; },
     ),		
     Gtk2::Ex::FormFactory::Button->new(
	 label => 'Pause',
	 clicked_hook => sub { $self->{ap_object}->pause; },
     ),
     Gtk2::Ex::FormFactory::Button->new(
	 label => 'Reload Program',
	 clicked_hook => sub { exec $0, @ARGV or die },
     ),
    )
};

package GUI::MainWindow;
use base 'GUI::Base';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %opts  = (
	foo => 'bar',
	@_
    );

    $self;
};

sub build {
    my $self = shift;
    $self->{ff} = my $ff = Gtk2::Ex::FormFactory->new(
	context => $self->get_context,
	content => [
	    Gtk2::Ex::FormFactory::Window->new(
		title => 'JPod101 Podcasts',
		height => 400,
		width  => 400,
		quit_on_close => $self->{toplevel},
		content => [
		    $self->build_menu(),
		],
	    ),
	],
    );
}

sub build_menu {

    

}

package GUI::EpisodeList;
use base 'GUI::Base';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %opts  = (
	foo => 'bar',
	@_
    );

    $self;
};

package GUI::SeriesList;
use base 'GUI::Base';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %opts  = (
	foo => 'bar',
	@_
    );

    $self;
};

