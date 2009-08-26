use strict;
use warnings;

use Test::More;
use Test::Exception;
# plan 'skip_all' => "HWWrapper::UtilSub depends on HW 's variables...";

use File::Spec;

use HWWrapper;
my $wrapper = HWWrapper->new;


my @tests = (
    # get_entrydate
    sub {
        ok defined $wrapper->get_entrydate("2009-01-01.txt");
    },
    sub {
        ok defined $wrapper->get_entrydate("text/2009-01-01.txt");
    },
    sub {
        ok not defined $wrapper->get_entrydate("text/2009-01-1.txt");
    },
    sub {
        ok not defined $wrapper->get_entrydate("text/2009-1-01.txt");
    },
    sub {
        ok $wrapper->get_entrydate("text/2009-01-01.txt")->{year} == 2009;
    },
    sub {
        ok $wrapper->get_entrydate("text/2009-09-01.txt")->{month} == 9;
    },
    sub {
        ok $wrapper->get_entrydate("text/2009-09-09.txt")->{day} == 9;
    },
    sub {
        ok $wrapper->get_entrydate("text/2009-09-09-foo_bar_baz.txt")->{rest} eq '-foo_bar_baz';
    },
    sub {
        ok $wrapper->get_entrydate("text/2009-09-09-foo_bar_baz.txt")->{rest} eq '-foo_bar_baz';
    },

    # split_date
    sub {
        lives_ok { $wrapper->split_date("2009-01-01") };
    },
    sub {
        dies_ok { $wrapper->split_date("2009-1-1") };
    },
    sub {
        dies_ok { $wrapper->split_date("2009-01-1") };
    },
    sub {
        dies_ok { $wrapper->split_date("2009-1-01") };
    },

    # cat_date
    sub {
        is $wrapper->cat_date(2009, 1, 1), "2009-01-01";
    },
    sub {
        is $wrapper->cat_date(2009, 1, 1, "foo_bar_baz"), "2009-01-01-foo_bar_baz";
    },
    sub {
        is $wrapper->cat_date(2009, 1, 1, qw(foo bar)), "2009-01-01-foo-bar";
    },
    sub {
        is $wrapper->cat_date(2009, 1, 1, qw(foo bar baz)), "2009-01-01-foo-bar-baz";
    },
);
plan tests => scalar @tests;


$_->() for @tests;
