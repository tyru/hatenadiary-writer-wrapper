use strict;
use warnings;

use Test::More;
use Test::Exception;

use HWWrapper::Hook::BuiltinFunc;
use HWWrapper;
my $wrapper = HWWrapper->new(args => \@ARGV);


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
    sub {
        lives_ok {
            dump("dumping...");
        }, "dump() is exported correctly";
    },
);
plan tests => scalar @tests;


$_->() for @tests;
