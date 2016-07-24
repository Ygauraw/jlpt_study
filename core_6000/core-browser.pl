#!/usr/bin/perl

# A simple app to present core lists. Also to check that my database
# is correct.

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

print "Loading core 2k database\n";
my @core_2k_rows = ();

$sth = $dbh->prepare(
    "select A.id, ja_vocab, ja_vocab_kana, en_vocab, ja_text, en_text
     from core_2k A, sentences B where A.main_sentence_id == B.id");

die unless defined($sth);
$rc = $sth->execute;
my @row;
while (@row = ($sth->fetchrow_array)) {
    die unless 6 == @row;
    push @core_2k_rows, [@row];
}
print "Done loading database\n";


# make a top-level window
my $mw = Gtk2::Window->new('toplevel');
$mw->set_default_size(700,500);
$mw->signal_connect ("delete_event", sub { Gtk2->main_quit; });

my $core_table = UI::Core2kList->new(data => \@core_2k_rows);

$mw->add($core_table->{gtk});

$mw->show_all;
Gtk2->main;

$dbh->disconnect;

package UI::Core2kList;

use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Simple::List;

# simple accessors
sub gtk {    shift -> {gtk};  }

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;

    my $opts = {
	data => [],
	@_
    };
	
    # make a scrolled window as the outer container
    my $gtk = $self->{gtk} = Gtk2::ScrolledWindow->new();
    
    my $biglist = $self->{biglist} =
	Gtk2::Ex::Simple::List->new(
	    "#"             => 'text', # want 4 digits
	    "Kanji"         => 'text',
	    "Reading"       => 'text',
	    "English"       => 'text',
	    "文章"           => 'markup',
	    "Sentence"      => 'text',
	    "T1"            => 'bool', # toggle; decide what it does later
	);

    # I'm going to try to do two things:
    # 1. cut down on the number of visible fields, using hover to display them
    # 2. change the way each cell (column) is rendered
    #
    # I didn't manage to find out how to do hover/tooltip. Maybe not
    # possible. See:
    # http://www.kksou.com/php-gtk2/sample-codes/display-tooltips-in-GtkTreeView-Part-1.php
    #
    # Probably the best thing to do is to allow double-click of an
    # item, and probably have a linked pane that shows details.

    # Add column types
    Gtk2::Ex::Simple::List->add_column_type ('Kanji',
	 type      => 'Glib::Scalar',
	 renderer  => 'Gtk2::CellRendererText',
	 attr      => sub {
	     my ($treecol, $cell, $model, $iter, $col_num) = @_;
	     my $info = $model->get ($iter, $col_num);
	     # "size" doesn't work:
	     $cell->set ("size-points" => 20);
	     $cell->set (text => $info);
	 } ) or die;

    Gtk2::Ex::Simple::List->add_column_type ('文章',
	 type      => 'Glib::Scalar',
	 renderer  => 'Gtk2::CellRendererText',
	 attr      => sub {
	     my ($treecol, $cell, $model, $iter, $col_num) = @_;
	     my $info = $model->get ($iter, $col_num);
	     $cell->set ("size-points" => 20);
	     $cell->set (markup => $info);
	 } );

    # Use the above definitions to add custom fields
    my $small_list = $self->{small_list} =
	Gtk2::Ex::Simple::List->new(
	    "#"             => 'text', # want 4 digits
	    "Kanji"         => 'Kanji',
	    "文章"           => '文章',
	    "T1"            => 'bool', # toggle; decide what it does later
	) or die;


    # break the 6-item list up into separate lists
    my $summary_list  = $self->{summary_list}  = [];
    my $vocab_list    = $self->{vocab_list}    = [];
    my $sentence_list = $self->{sentence_list} = [];
    foreach my $rowref (@{$opts->{data}}) {
	push @$summary_list,  [$rowref->[0], $rowref->[1], $rowref->[4]];
	push @$vocab_list,    [$rowref->[2], $rowref->[3]];
	push @$sentence_list, [$rowref->[5]];
	#	print "$rowref->[1]\n"
    }

    print "added " . (0 + @$summary_list) . " elements to summary list\n";

    
    # program crashes unless we restrict size
    $gtk->set_size_request(600, 400);

    if (0) {
	$gtk->add($biglist);
	@{$biglist->{data}} = @{$opts->{data}};
    } else {
	$gtk->add($small_list);
	@{$small_list->{data}} = @$summary_list;
    
    }

    return $self;
}
 
