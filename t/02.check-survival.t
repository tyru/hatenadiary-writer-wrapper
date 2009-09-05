use strict;
use warnings;

use Test::More;
use Test::Exception;

use HWWrapper;
my $wrapper = HWWrapper->new;


use File::Spec;


open STDERR, '>', File::Spec->devnull or plan 'skip' => "can't open null device";

my @tests = (
    sub {
        dies_ok { $wrapper->arg_error };
    },
    sub {
        dies_ok { HWW->arg_error };
    },
    sub {
        dies_ok { $wrapper->error("error!") };
    },
);
plan tests => scalar @tests;


$_->() for @tests;
