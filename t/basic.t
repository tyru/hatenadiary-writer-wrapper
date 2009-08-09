use strict;
use warnings;

use Test::More;
plan 'no_plan';

use Scalar::Util qw(blessed);

use HWWrapper;
my $wrapper = HWWrapper->new(args => \@ARGV);


ok blessed($wrapper), '$wrapper is blessed reference';

ok $wrapper->isa('HW');
