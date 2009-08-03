use strict;
use warnings;

use Test::More;
use Test::Exception;
plan 'skip_all' => "HWWrapper::UtilSub depends on HW 's variables...";

use HWWrapper::UtilSub;


my @tests = (
    sub {
        dies_ok { error() };
    },
    sub {
        dies_ok { error("going to die!!") };
    },
    sub {
        lives_ok { warnings("warn") };
    },
);
plan tests => scalar @tests;


$_->() for @tests;
