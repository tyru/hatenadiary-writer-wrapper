use strict;
use warnings;

use Test::More;
use Test::Exception;

unless (exists $ENV{HWW_TEST_INTERACTIVE}) {
    plan skip_all => "env 'HWW_TEST_INTERACTIVE' is not set";
}


use File::Spec;

use HWWrapper;
my $wrapper = HWWrapper->new;


my @tests = (
    sub {
    },
);
plan tests => scalar @tests;


$_->() for @tests;
