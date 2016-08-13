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

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# apparently ARGV doesn't automatically have UTF8 flag...
@ARGV = map { decode_utf8($_, 1) } @ARGV;

my $ja = Util::JA_Script->new; $ja->load_db;

die "A kanji argument (or '--makedb') is required\n" unless (@ARGV);

my $kanji = shift @ARGV;
if ($kanji ne "--makedb") {
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
if ($kanji eq "--makedb") {
    print "About to add to db tables; ^C if you don't want this\n";
    <STDIN>;

    # I've changed AutoCommit to 1 by default in the KanjiReadings
    # class, but it's really slow. So turn it off for the duration of
    # these updates:
    KanjiReadings::DBI->begin_work;

    #my $kanji_list = [qw/降 雨/];	# small test set
    my $kanji_list = get_jouyou_list();
    for my $kanji (@$kanji_list) {
	%vocab_dict = ();	# must clear for each new kanji
	load_vocab($kanji);

	my $result = search_single($kanji);
	summarise_readings($result) if $verbose;
	save_readings($result);
    }
    KanjiReadings::DBI->end_work;
    # Explicit commits below shouldn't be needed now:
    #	KanjiReadings::Summary->dbi_commit;
    #	KanjiReadings::ReadingTally->dbi_commit;
    #	KanjiReadings::VocabReading->dbi_commit;
} else {
    %vocab_dict = ();
    load_vocab($kanji);
    my $result = search_single($kanji);
    summarise_readings($result);
}

$web_data_db->disconnect;
$core_26k_db->disconnect;

exit(0);

# The rest is just subs
my $heisig6_seq = 0;
sub save_readings {
    my $result = shift;

    # OK, not using dbh since I have Class::DBI
    my $kanji          = $result->{kanji};
    my $reading_counts = $result->{reading_counts};
    my $failed         = $result->{failed};
    my $num_failed     = 0 + @$failed;
    my $num_parsed     = 0 + keys %$reading_counts;
    
    my $fields = {
	kanji         => $kanji,
	heisig6_seq   => ++$heisig6_seq,
	num_readings  => $num_parsed + $num_failed,
	adj_readings  => $num_parsed + $num_failed,
	num_vocab     => $result->{matched_count},
	num_failed    => $num_failed,
	adj_failed    => $num_failed,
    };

    my $Summary = KanjiReadings::Summary->insert($fields);
    die unless ref($Summary);
    $Summary->update;

    # Insert tally records
    for my $syn (sort {$a cmp $b} keys %$reading_counts) {
	my $fields = {
	    kanji => $kanji,
	};
	die "Expected reading counts like hira => (on|kun):<kana>\n" unless
	    $syn =~ /^(on|kun):(.*)/;
	$fields->{read_type}   = $1;
	$fields->{kana}        = $2;
	$fields->{hiragana}    = kata_to_hira($2); # hira->hira ok
	$fields->{raw_tally}   =
	$fields->{adj_tally}   = $reading_counts->{$syn};

	KanjiReadings::ReadingTally->insert($fields);
    }

    # Insert vocab reading records. Since we add both matched and
    # failed, I'll move the actual work into a separate sub
    for my $vocab (@{$result->{matched_list}}) {
	save_vocab_reading($kanji, $vocab);
    }
    for my $vocab (@{$result->{failed}}) {
	save_vocab_reading($kanji, $vocab);
    }
}

sub save_vocab_reading {
    my $kanji = shift;
    my $item  = shift;
    die unless ref($item) eq "HASH";

    KanjiReadings::VocabReading->insert({
	kanji        => $kanji,
	vocab_kanji  => $item->{vocab},
	vocab_kana   => $item->{reading},
	jlpt_grade   => $item->{grade},
	reading_hira => $item->{kanji_hira} || '',
	reading_type => $item->{kanji_type} || '',
	reading_kana => $item->{kanji_kana} || '',
	adj_hira     => $item->{kanji_hira} || '',
	adj_type     => $item->{kanji_type} || '',
	adj_kana     => $item->{kanji_kana} || '',
	ignore_flag  => 0,
    });;

}

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

