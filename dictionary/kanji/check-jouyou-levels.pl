#!/usr/bin/perl

# Check JLPT level data from database against other sources
#

use DBI;
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=kanjidic2.sqlite", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 1,
    }
    ) or die;

use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use YAML::XS qw(Load DumpFile LoadFile);

# load in basic RTK plus Jouyou levels files
my $rtk_index = LoadFile("../../uber/rtk_kanji.yaml") or die "failed to load RTK";

print "Loaded RTK. Last kanji is " . $rtk_index->{by_frame}->[2200]->{kanji} . "\n";

## Create a jouyou kanji table from RTK data
my $rtk_by_kanji = $rtk_index->{by_kanji};
my %jouyou = map { $_ => undef } keys %$rtk_by_kanji;
print "RTK->Jouyou index has " . (0 + (keys %jouyou)) . " entries\n";
for my $c ('私', '一', '巳') {
    print "Checking $c: " . (exists $jouyou{$c} ? "ok" : "not ok") . "\n";
}

my $jouyou_levels = LoadFile("../../uber/jouyou_levels.yaml") or die;
my %jouyou_levels = %$jouyou_levels;

# copied from crunch-web-files; use source of "jmdict" here
my $overrides = 0;		# extra code to note of overrides
sub register_level {
    my ($kanji, $source, $level) = @_;
    return unless exists $jouyou{$kanji}; # only store info for Jouyou kanji
    #warn "[$kanji,$source,$level]\n";

    push @{$jouyou_levels{$kanji}->{found_in}->{$source}}, $level;
    # The following stores the easiest level that the kanji was found
    # at among all lists
    if ($level > $jouyou_levels{$kanji}->{notional_level}) {
	++$overrides;
	warn "Overriding $kanji to notional level $level\n";
	$jouyou_levels{$kanji}->{notional_level} = $level;
    }

}

for my $level (1..5) {
    my $statement = "select literal,jlpt from entries_by_literal where jlpt = '$level'";
    print "$statement;\n";
    my $sth = $dbh->prepare($statement);
    die unless defined $sth;
    my $rv = $sth->execute;
    print "RV from select: $rv\n"; # confusing!!
    my $nrows = $sth->rows;	   # confusing!!
    print "Got back $nrows rows from query\n";
    my @row;
    while (@row = ($sth->fetchrow_array)) {
	# despite confusion above, we do get here
	# warn "got here\n";
	die unless 2 == @row;
	my ($literal, $db_jlpt) = @row;
	register_level($literal, "jmdict", $db_jlpt);
    }
}

print "JMDICT overrode $overrides entries\n";
$dbh->disconnect;

# So the long and short of this is that the edict files only add a
# handful of kanji (8) to the N1 list. This means that the YAML file
# with the notional levels is fine for me doing N2. 

