#!/usr/bin/perl

use strict;
use warnings;
use utf8;

# My recent attempts with Glade and Gtk2::Ex::FormFactory haven't gone
# well, so I'm building a simple "bare-metal" Gtk2 app here. I will
# attempt to use some OO encapsulation, though.

use Glib qw/TRUE FALSE/;
use Gtk2 -init;

my $mw = UI::MainWindow->new;
print ref($mw) . "\n";


# Create some sample lists
my @lists = (
    "Kanji Readings #1",
    [ 
      [ '一', 'いち' ],
      [ '二', 'に' ],
      [ '三', 'さん' ],
      [ '四', 'し' ],
      [ '五', 'ご' ],
    ],
    "Kanji Readings #2",
    [ 
      [ '犬', 'いぬ' ],
      [ '竃', 'かま' ],
      [ '猫', 'ねこ' ],
      [ '鳥', 'とり' ],
      [ '牛', 'うし' ],
    ],
    );

# Create a couple of list window objects
my $list1 = UI::BrowseWindow->new($lists[0],$lists[1]);
my $list2 = UI::BrowseWindow->new($lists[2],$lists[3]);

# Now add buttons to main window that will show these
$mw->add_launcher($lists[0], $list1);
$mw->add_launcher($lists[2], $list2);

# Ready to show main window
$mw->gtk->show_all;
Gtk2->main;


package UI::MainWindow;
use Glib qw/TRUE FALSE/;

# simple accessors
sub gtk {    shift -> {gtk};  }

# constructor
sub new {
    my $class = shift;
    my $self  = {};
   
    bless $self, $class;

    my $window = Gtk2::Window->new ('toplevel');
    $window->signal_connect(delete_event => sub { Gtk2->main_quit;});
    $self->{gtk} = $window;

    # Build a simple launching interface
    my $vbox = Gtk2::VBox->new(1, 5); # homo, spacing
    $window->add($vbox);

    $vbox->add(Gtk2::Label->new("Select list to browse"));

    # save ref to vbox so we can add more later
    $self->{vbox} = $vbox;

    
    return $self;
}

sub add_launcher {
    my $self = shift;
    my $vbox = $self->{vbox};
    my $text = shift or die;
    my $owin = shift or die;

    my $hbox = Gtk2::HBox->new;
    $hbox->add(Gtk2::Label->new($text));

    my $but = Gtk2::Button->new("Launch");
    $but->signal_connect(clicked => sub { $owin->gtk->show_all });

    $hbox->add($but);
    $vbox->add($hbox);
}
1;

package UI::BrowseWindow;

use Glib qw/TRUE FALSE/;

# simple accessors
sub gtk {    shift -> {gtk};  }

# constructor
sub new {
    my $class = shift;
    my $self  = {};
   
    bless $self, $class;

    # We will take a name and a list of lists to iterate over
    my $listname = shift or die;
    my $lol      = shift or die; # [[item, desc], ...]

    $self->{listname} = $listname;
    $self->{lol}      = $lol;
    $self->{items}    = 0 + @$lol;
    $self->{item}     = 0;	# which item to display

    # Now GTK stuff
    my $win = Gtk2::Window->new('toplevel');
    # hide the window when it's closed rather than destroying
    $win->signal_connect(delete_event => \&Gtk2::Widget::hide_on_delete);
    $self->{gtk} = $win;

    my $vbox = Gtk2::VBox->new;
    $self->{vbox} = $vbox;

    # three label widgets
    my $info  = $self->{info} = Gtk2::Label->new;
    my $lhs   = $self->{lhs}  = Gtk2::Label->new;
    my $rhs   = $self->{rhs}  = Gtk2::Label->new;

    # OO-ish; use stored state to set/update text
    $self->update_info_text;
    $self->update_lhs_text;
    $self->update_rhs_text;

    # pack these widgets
    $vbox->add($info);
    my $hbox = Gtk2::HBox->new;
    $hbox->add($lhs);
    $hbox->add($rhs);
    $vbox->add($hbox);

    # add buttons ...
    $hbox = Gtk2::HBox->new;
    my $prev = Gtk2::Button->new("Prev");
    my $next = Gtk2::Button->new("Next");
    $hbox->add($prev);
    $hbox->add($next);
    $vbox->add($hbox);

    # set up button callbacks
    $prev->signal_connect(clicked => sub {
	my $item  = $self->{item};
	my $items = $self->{items};
	if    ($item == 0)  { die }
	elsif ($item == 1)  { $prev->set_state("insensitive"); }
	if    ($items >= 2) { $next->sensitive(1); $next->set_state("normal"); }
	$self->{item}--;
	$self->update_info_text;
	$self->update_lhs_text;
	$self->update_rhs_text;
			  });
			  
    $next->signal_connect(clicked => sub {
	my $item  = $self->{item};
	my $items = $self->{items};
	if    ($item >= $items - 1) { die }
	elsif ($item == $items - 2) { $next->set_state("insensitive");  }
	if    ($items >= 2)         { $prev->sensitive(1); $prev->set_state("normal");  }
	$self->{item}++;
	$self->update_info_text;
	$self->update_lhs_text;
	$self->update_rhs_text;
			  });
			  
    # Want to deactivate button if we're at start/end of range
    $prev->set_state("insensitive");
    $next->set_state("insensitive") if ($self->{items} <= 1);

    $win->add($vbox);
    return $self;
}

sub update_info_text {
    my $self  = shift;
    my ($info,$items,$item,$listname) = 
	@$self{qw(info items item listname)};

    ++$item;
    $info->set_text("Viewing item $item/$items of '$listname'");
}

sub update_lhs_text {
    my $self  = shift;
    my ($lhs,$lol,$item) = @$self{qw(lhs lol item)};
#    warn "LHS: $item, @$lol\n";
    $lhs->set_text($lol->[$item]->[0]);
}

sub update_rhs_text {
    my $self  = shift;
    my ($rhs,$lol,$item) = @$self{qw(rhs lol item)};
    $rhs->set_text($lol->[$item]->[1]);
}

