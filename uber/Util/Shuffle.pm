package Util::Shuffle;

require Exporter;
@ISA = qw(Exporter);
@EXPORT    = qw(fisher_yates_shuffle);
@EXPORT_OK = qw(fisher_yates_shuffle);

our $pkg = __PACKAGE__;

use strict;
use warnings;

sub fisher_yates_shuffle {	# (loosely) based on recipe 4.18 from
				# the Perl Cookbook
    my $array = shift;		# let next die catch missing array
    my $rng   = shift or die;
    # Change recipe to allow picking a certain number of elements
    my $picks = shift;		# allow it to be undef, as seen below

    $picks=scalar(@$array) unless
	defined($picks) and $picks >=0 and $picks<scalar(@$array);

    my ($i, $j) = (scalar(@$array),undef);
    while (--$i >= scalar(@$array) - $picks) {
	$j=$rng->randint ($i);	# random int from [0,$i]
	# next if $i==$j;       # don't swap element with itself
	@$array[$i,$j]=@$array[$j,$i]
    }

    # Return the last $picks elements from the end of the array
    return splice @$array, -$picks;
}

