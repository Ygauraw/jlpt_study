#!/usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(LoadFile);
use Data::Dumper;
use Data::Dump qw(dump dumpf);

use utf8;

binmode STDOUT, ":utf8";

my $dict = LoadFile("JMdict.yaml");

# We need a lookup for sequence number since there are gaps in the
# numbering

print "Dictionary loaded\n";
print "\$dict: " . ref($dict) . "\n";
print "\$dict keys: " . (join ", ", keys %{$dict}) . "\n";
print "\$dict->{entry} is a " . ref($dict->{entry}) . "\n";

# We need a lookup for sequence number since there are gaps in the
# numbering
my %seq_to_entry = ();
my $ent_base = $dict->{entry};
my $ent_index= 0;
foreach my $ent (@{$ent_base}) {
    die unless exists $ent->{ent_seq};
    $seq_to_entry{$ent->{ent_seq}} = $ent;
    $ent_index++;		# not used right now
}

sub delete_non_eng_glosses {
    my $ent = shift;
    my $glosses;
    # promote sense => hash to sense => [ hash ... ];
    
    die unless exists($ent->{sense});
    
    my $senses = $ent->{sense};
    $senses = [ $senses] unless ref($senses) eq 'ARRAY';

    for my $sense (@$senses) {
	die unless exists($sense->{gloss});
	$glosses = $sense->{gloss};
	$glosses = [ $glosses] unless ref($glosses) eq "ARRAY";
	my $new_list = [];
	for my $g (@$glosses) {
	    die unless exists $g->{"xml:lang"};
	    push @$new_list, $g if ($g->{"xml:lang"} eq "eng");
	}
	# demote list of glosses to single item
	$new_list = $new_list->[0] if @$new_list == 1;
	$sense->{gloss}=$new_list;
    }
}

# Data::Dump is great, but it converts strings to Unicode escapes and
# is overly-verbose.
sub filter_dumped {
    my ($ctx, $object_ref) = @_;
    if ($ctx->is_scalar) {
	return { dump => "'" . $$object_ref . "'" }; # needs $$!
    } elsif($ctx->is_hash) {
	return { hide_keys => ['xml:lang'] };
    } else {
	return undef;
    }
    return undef;
}

my $ent;
while (my $line = <STDIN>) {

    chomp $line;
    
    next unless $line =~ /^\d+$/;

    unless (exists($seq_to_entry{$line})) {
	warn "No entry $line\n";
	next;
    }

    $ent = $seq_to_entry{$line};
    delete_non_eng_glosses($ent);
    #print Dumper($ent);
    print dumpf($ent, \&filter_dumped);
    print "\n";
}
