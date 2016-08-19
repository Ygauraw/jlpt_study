#!/usr/bin/perl                       --  -*- Perl -*-

# Take a kanji and use JA_Script to count up occurrences of each
# reading of vocab stored in database.

use strict;
use warnings;
use utf8;
use Encode qw(decode_utf8);
use Data::Dump qw(dump dumpf);

my $verbose = 0;

use DBI;

# Script-related utils
use Util::JA_Script qw(hira_to_kata kata_to_hira has_hira
                       has_kata has_kanji get_jouyou_list);

# Class::DBI model for insertion into new kanji_readings db
use Model::KanjiReadings;
use Model::BreenKanji;		# for Jouyou data

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# apparently ARGV doesn't automatically have UTF8 flag...
@ARGV = map { decode_utf8($_, 1) } @ARGV;

my $ja = Util::JA_Script->new; $ja->load_db;

die "A kanji argument (or '--makedb') is required\n" unless (@ARGV);

my $kanji = shift @ARGV;
if ($kanji eq "--fromdb") {
    # check later
} elsif ($kanji eq "--makedb") {
    # no extra args needed
} else {	
    die "Arg $kanji doesn't have kanji!\n" 
	unless has_kanji($kanji);
}

# Vocabulary databases:
my $web_data_db = DBI->connect(
    "dbi:SQLite:dbname=web_data.sqlite", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );
my $core_26k_db = DBI->connect(
    "dbi:SQLite:dbname=/home/dec/JLPT_Study/core_6000/core_2k_6k.sqlite", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        AutoCommit     => 0,
    }
    );
die unless defined($web_data_db) and defined($core_26k_db);

# Global: per-kanji vocab dictionary
my %vocab_dict = ();

# Choice of making Jouyou kanji db or showing info for a single kanji


if ($kanji eq "--fromdb") {
    # Display from db created with --makedb
    $kanji = shift @ARGV or die "--fromdb needs more args";

    my $lookup = "kanji";
    if ($kanji eq "-k") {
	$lookup = "kanji";
	$kanji = shift @ARGV or die "--fromdb needs more args";
    } elsif ($kanji eq "-v") {
	$lookup = "vocab";
	$kanji = shift @ARGV or die "--fromdb needs more args";
    }

    my $krec = KanjiReadings::Kanji->retrieve($kanji)
	or die "No kanji matchs '$kanji'\n";
    my @failed = ();

    foreach my $kv_link ($krec->kv_link) {
	my $vid = $kv_link->vocab_id;
	my $vocab = "N" . $vid->jlpt_grade . " " . $vid->vocab_ja . 
	    " => " . $vid->vocab_kana;
	my $yomi;
	if ($kv_link->yomi_id != 0) {
	    $yomi = " reading $kanji as " . $kv_link->yomi_id->yomi_type .
		":" . $kv_link->yomi_id->yomi_kana . " (" .
		$kv_link->yomi_id->yomi_hira . ")";
	    print "$vocab$yomi\n";
	} else {
	    $yomi = '';
	    push @failed, "  $vocab\n";
	}
    }

    print "Summary of readings for kanji $kanji:\n";
    print "Total vocab readings: " . (0 + ($krec->kv_link)) . ", of which ";
    my $failed_count;
    if (1) {
	# Fails if we do:
	#    my $failed_count = grep { 0 == $_->yomi_count } $tallies;
	# OR:
	#    my $tallies = $krec->tallies;
	#    foreach my $tally ($tallies) { ... }
	# I guess it does wantarray

	foreach my $tally ($krec->tallies) {
	    #	    print ref($tally);
	    #	    print $tally -> 
	}
	# a bit awkward, but it works
	grep { $failed_count = $_->yomi_count if 0 == $_->yomi_id } $krec->tallies;
	print "$failed_count had no match\n";
    } else {
	print 0 + @failed . " had no match\n";
    }

    print "Summary of readings:\n";
    for my $tally ($krec->tallies) {
	next if 0 == $tally->yomi_id;
	printf("  %02d time(s)  %s:%s\n", $tally->yomi_count,
	       $tally->yomi_id->yomi_type,
	       $tally->yomi_id->yomi_kana);
    }

    print "Non-matching:\n" . (join '', @failed);
    
} elsif ($kanji eq "--makedb") {

    # Make updates a lot faster by turning off auto-commit:
    KanjiReadings::DBI->begin_work;

    #my $kanji_list = [qw/降 雨 行/];	# small test set
    my $kanji_list = get_jouyou_list();
    for my $kanji (@$kanji_list) {
	%vocab_dict = ();	# must clear for each new kanji
	load_vocab($kanji);

	my $result = search_single($kanji);
	summarise_readings($result) if $verbose;
	save_readings($result);
    }
    KanjiReadings::DBI->end_work;

} else {
    # display from source db
    %vocab_dict = ();
    load_vocab($kanji);
    my $result = search_single($kanji);
    summarise_readings($result);
}

$web_data_db->disconnect;
$core_26k_db->disconnect;

exit(0);

# Reimplement save_readings and save_vocab_readings
#
# Helper functions below cache anything that is to be added to the db

my ($heisig6_seq, $yomi_rec_seq, $vocab_rec_seq, $link_rec_seq, @junk) = (0) x 10;
my %yomi_records = ();
sub yomi_record {
    my ($type, $kana, $hira, @o) = @_;
    die "bad type '$type'" unless $type eq 'on' or $type eq 'kun';
    die unless $hira;
    die if @o;

    my $key = "$type:$kana";
    return $yomi_records{$key}
	if exists $yomi_records{$key};
    $yomi_records{$key} = ++$yomi_rec_seq;
    KanjiReadings::Yomi->insert(
	{
	    yomi_id    => $yomi_rec_seq,
	    yomi_type  => $type,
	    yomi_kana  => $kana,
	    yomi_hira  => $hira
	}
    );
    return $yomi_rec_seq;
}

my %vocab_records = ();
sub vocab_record {
    my ($ja, $kana, $en, $jlpt, @o) = @_;
    die if @o;
    die unless $ja;
    die unless $kana;
    $jlpt = 0 unless $jlpt;
    $en = '' unless $en;

    my $key = "$ja:$kana";
    return $vocab_records{$key} if exists $vocab_records{$key};
    $vocab_records{$key} = ++$vocab_rec_seq;
    KanjiReadings::Vocabulary->insert(
	{
	    vocab_id  => $vocab_rec_seq,
	    vocab_ja  => $ja,
	    vocab_kana => $kana,
	    vocab_en  => $en,
	    jlpt_grade => $jlpt,
	}
    );
    return $vocab_rec_seq;
}
my %kanji_records = ();
sub kanji_record {
    my ($kanji, $frame, $keyword, $jlpt, $jouyou, @o) = @_;
    die if @o;
    die unless $kanji;
    $frame = 0 unless $frame;
    $keyword = '' unless $keyword;
    $jouyou = 0 unless $jouyou;

    return $kanji if exists $kanji_records{$kanji};
    KanjiReadings::Kanji->insert(
	{
	    kanji => $kanji,
	    rtk_frame => $frame,
	    rtk_keyword => $keyword,
	    jlpt_grade => $jlpt,
	    jouyou_grade => $jouyou,
	}
    );
    return $kanji;
}
my %link_records = ();
sub link_record {
    my ($kanji, $yomi_id, $adj_yomi_id, $adj_reason, $vocab_id, @o) = @_;
    die if @o;
    die unless $kanji and $vocab_id and defined($yomi_id);
    $adj_yomi_id = '' unless $adj_yomi_id;
    $adj_reason = '' unless $adj_reason;

    my $key = "$kanji:$vocab_id";
    return $link_records{$key} if exists $link_records{$key};
    $link_records{$key} = ++$link_rec_seq;
    KanjiReadings::KanjiVocabLink->insert(
	{
	    kv_link_id => $link_rec_seq,
	    kanji => $kanji,
	    yomi_id => $yomi_id,
	    adj_yomi_id => $adj_yomi_id,
	    adj_reason => $adj_reason,
	    vocab_id => $vocab_id,
	}
    );
    return $link_rec_seq;
 }
my %yomi_tally_records=();
sub yomi_tally_record { 
    my ($kanji, $yomi_id, $yomi_count, $adj_count, $eg, @o) = @_;
    die if @o;
    die unless $kanji;
    $yomi_id = 0 unless $yomi_id;
    $yomi_count = 0 unless $yomi_count;
    $adj_count = 0 unless $adj_count;
    $eg = 0 unless $eg;
    my $key = "$kanji:$yomi_id";
    die if exists $yomi_tally_records{$key};
    $yomi_tally_records{$key} = "something";
    KanjiReadings::KanjiYomiTally->insert(
	{
	    kanji => $kanji,
	    yomi_id => $yomi_id,
	    yomi_count => $yomi_count,
	    adj_count => $adj_count,
	    exemplary_vocab_id => $eg,
	}
    );
    return "something";    
}

sub save_readings {

    # copy-pasta from older code shows what we're getting
    my $result = shift or die;
    my $kanji          = $result->{kanji};
    my $reading_counts = $result->{reading_counts};
    my $failed_list    = $result->{failed};
    my $matched_list   = $result->{matched_list};
    my $num_failed     = 0 + @$failed_list;
    my $num_parsed     = 0 + keys %$reading_counts;

    my %syn_yomi_id    = ();	# same keys as in reading_counts
    
    # We must store kanji and vocab first
    ++$heisig6_seq;

    # Get jouyou grade from Jim Breen's kanji dictionary
    my $jouyou = BreenKanji::Entry->retrieve($kanji)->jouyou;

    kanji_record($kanji, $heisig6_seq, '', 0, $jouyou);

    foreach my $item (@$matched_list, @$failed_list) {
	my $vocab_id = vocab_record(
	    $item->{vocab},
	    $item->{reading},
	    '',			# en
	    $item->{grade},
	);
	# stash vocab_id in case it's needed later
	$item->{vocab_id} = $vocab_id;
    }

    # Then the yomi (stashing yomi id as we go; hence scan failed too)
    foreach my $item (@$matched_list, @$failed_list) {
	unless ($item->{kanji_type}) {
	    $item->{yomi_id} = 0;
	    next;
	}
	my $yomi_id = yomi_record(
	    $item->{kanji_type},
	    $item->{kanji_kana},
	    $item->{kanji_hira},
	);
	$item->{yomi_id} = $yomi_id;
	# stash in reading_counts too?
	my $syn = "$item->{kanji_type}:$item->{kanji_kana}";
	die "Added yomi with synthetic key '$syn' not in reading counts"
	    unless exists $reading_counts->{$syn};
	$syn_yomi_id{$syn} = $yomi_id;
    }

    # Then the link table

    # This loop handles one kanji to many vocab, but thanks to stashing
    # vocab_id globally in vocab_record(), we will also handle the
    # reverse map if the same vocab comes up again.
    foreach my $item (@$matched_list, @$failed_list) {
	my $link_id = link_record(
	    $kanji,
	    $item->{yomi_id},
	    '',
	    '',
	    $item->{vocab_id}
	);
    }

    # Finally, the tallies
    # Tally non-matched first
    yomi_tally_record($kanji, 0, $num_failed, 0, '');
    for my $syn (sort {$a cmp $b} keys %$reading_counts) {
	die "Expected reading counts like hira => (on|kun):<kana>\n" unless
	    $syn =~ /^(on|kun):(.*)/;
	my $yomi_id = $syn_yomi_id{$syn} or die;
	yomi_tally_record(
	    $kanji,
	    $yomi_id,
	    $reading_counts->{$syn},
	    0,
	    ''
	);
    }

}

# The rest is just subs
sub recreate_tables {
    my $dbh = shift;

    # Actually, don't bother. Keep the schema definition in a separate
    # file in the Model directory and pass it to sqlite.
    #
    # Likewise, use Class::DBI instead of raw SQL for this particular
    # DB.    
}
# Load vocab with matching kanji from both sources and merge into a
# single dictionary.  I could try updating this to store the source
# and/or English text but it's not worth the hassle.
sub load_vocab {
    my $kanji = shift;
    # Prepare query for web_data_db and update the dictionary
    my $sth = $web_data_db->prepare(
	"select ja_regular, ja_kana, jlpt_level 
     from vocab_by_jlpt_grade 
     where ja_regular like ?");
    my $rc = $sth->execute("\%$kanji\%") or die;
    die unless defined $sth;
    update_dict($sth);
    warn "Read in tanos/jlptstudy/tagaini data\n" if $verbose;

    # Prepare query for core_26k_db and update the dictionary
    $sth = $core_26k_db->prepare(
	"select ja_vocab, ja_vocab_kana, 0
     from core_6k 
     where ja_vocab like ?");
    die unless defined $sth;
    $rc = $sth->execute("\%$kanji\%") or die;
    update_dict($sth);
    warn "Read in Core data\n" if $verbose;
}

# print a failed or matched vocab item
sub print_vocab_item {
    my $item = shift;
    print shift || '';
    print "N$item->{grade} $item->{vocab} => $item->{reading}\n";
    # Uncomment to check kanji reading detail fields:
    # print "[$item->{kanji_hira}:$item->{kanji_type}:$item->{kanji_kana}]\n";
}
sub search_single {
    # Structures for doing summary analysis of reading frequency and
    # failed parses
    my $kanji = shift or die;
    my @failed = ();
    my %reading_counts = ();
    my $matched_count = 0;
    my $matched_list  = [];
    my ($vocab, $kana, $grade, $reading);

    my $unstripped = $kanji;
    $kanji = $ja->strip_non_kanji($kanji);

    foreach my $vocab (sort {$a cmp $b} keys %vocab_dict) {

	$grade = $vocab_dict{$vocab}->{grade};
	my $readlist = $vocab_dict{$vocab}->{readings};

	foreach $reading (@$readlist) {
	    #warn "Reading: $reading\n";
	    my $vocab_item = {
		grade   => $grade,
		# The following two are vocab kanji/kana
		vocab   => $vocab,
		reading => $reading,
		# Also want to record specifics of kanji reading
		kanji_hira => '',
		kanji_type => '', # on/kun
		kanji_kana => '', # on->katakana, kun->hiragana		
	    };

	    # check vocab reading
	    my $listref = $ja->kanji_reading($vocab,$reading);
	    unless(defined $listref) {
		#warn "No match for $vocab => $reading\n";
		push @failed, $vocab_item;

	    } else {
		# The below will now appear in returned result
		#print "Matched N$grade $vocab => $reading\n";
		#dumpf($listref, \&filter_dumped);
		push @$matched_list, $vocab_item;
		++$matched_count;

		# Scan through the list to find just the kanji we're
		# interested in.
		my $pos = 0;
		while ($pos < @$listref) {
		    next unless $listref->[$pos] eq $kanji;
		    my $hira  = $listref->[$pos+1];
		    my $dlist = $listref->[$pos+2];
		    # Just take the first matching reading? Scan them all
		    my $rtype = undef;
		    foreach (@$dlist) {
			die unless /^(.*):(.*):(.*)$/;
			# apparently we can have kanji like 訓 that has
			# both on-yomi and kun-yomi that map to the same
			# sound... I had a die in here but I'll just
			# change it to just pick the first match.
			$rtype = "$1:$2";
			# Save kanji reading to result hash
			$vocab_item->{kanji_hira}=$hira;
			$vocab_item->{kanji_type}=$1;
			$vocab_item->{kanji_kana}=$2;
			last;
			# don't die below
			die "$rtype ne $1:$2" 
			    if defined($rtype) and $rtype ne "$1:$2";
			$rtype = "$1:$2";
		    }

		    $reading_counts{$rtype} = 0 
			unless defined $reading_counts{$rtype};
		    $reading_counts{$rtype}++;
		    last;
		} continue {
		    $pos += 3;
		}
	    }
	}
    }
    return {
	kanji => $kanji,
	matched_count => $matched_count,
	matched_list  => $matched_list,
	reading_counts => \%reading_counts,
	failed => \@failed,
	failed_count => scalar (@failed),
    };
}

sub summarise_readings {
    my $rhash = shift or die;
    # unpack hash elements
    my $kanji          = $rhash->{kanji};
    my $matched_count  = $rhash->{matched_count};
    my $reading_counts = $rhash->{reading_counts};
    my $failed         = $rhash->{failed};
    my $failed_count   = $rhash->{failed_count};
    my $matched_list   = $rhash->{matched_list};

    foreach my $item (@$matched_list) {
	print_vocab_item($item, "Matched ");
    }

    print "Summary of readings for kanji $kanji:\n";
    print "Total vocab readings: " . ($matched_count + @$failed) .
	", of which " .
	(0 + @$failed) . " had no match\n";
    print "Summary of readings:\n";
    for (sort {$a cmp $b} keys %$reading_counts) { 
	printf("  %02d time(s)  %-16s \n", $reading_counts->{$_}, $_)  
    };
    print "Non-matching:\n";
        foreach my $item (@$failed) {
	print_vocab_item($item, "  ");
    }
}

sub new_dict {
    {
	vocab => shift,
	grade => shift,
	readings => [],
	stoplist => {},		# prevent adding duplicate readings
    }
}

sub update_dict {		# wrap up to reuse for both queries
    my $sth = shift;
    my ($vocab, $kana, $grade, $reading);
    while (($vocab, $kana, $grade) = $sth->fetchrow_array) {
	next unless has_kanji($vocab);
	# Found some odd entries with kana [kanji]. They cause an
	# infinite loop somewhere: skip them
	next if $vocab =~ tr|[]|[]|;
	$vocab =~ s/(.)々/$1$1/;
	$vocab_dict{$vocab} = new_dict($vocab,$grade)
	    unless exists $vocab_dict{$vocab};
	foreach $reading (split /\s*[,\/]\s*/, $kana) {
	    next if exists $vocab_dict{$vocab}->{stoplist}->{$reading};
	    $vocab_dict{$vocab}->{stoplist}->{$reading} = undef;
	    push @{$vocab_dict{$vocab}->{readings}}, $reading;
	}
    }
}

sub filter_dumped {
    my ($ctx, $object_ref) = @_;
    if ($ctx->reftype eq "SCALAR") {
        return { dump => "'" . $$object_ref . "'" }; # needs $$!
    } elsif($ctx->is_hash) {
        return { hide_keys => ['xml:lang'] };
    } else {
        return undef;
    }
    return undef;
}

