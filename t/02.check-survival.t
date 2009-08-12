use strict;
use warnings;

use Test::More;
use Test::Exception;


use File::Spec;
use HWWrapper;
my $wrapper = HWWrapper->new(args => \@ARGV);


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
    sub {
        lives_ok {
            require HWWrapper::Functions;
            HWWrapper::Functions->import('dump');
            dump("dumping...");
        };
    },
);
plan tests => scalar @tests;


$_->() for @tests;
