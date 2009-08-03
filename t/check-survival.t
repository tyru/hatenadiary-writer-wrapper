use strict;
use warnings;

use Test::More;
use Test::Exception;


use HWWrapper;
my $wrapper = HWWrapper->new;



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
    sub {
        lives_ok {
            HWWrapper::UtilSub->import('dump');
            dump("dumping...");
        };
    },
);
plan tests => scalar @tests;


$_->() for @tests;
