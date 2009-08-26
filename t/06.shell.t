use strict;
use warnings;

use Test::More;
# plan 'skip_all' => "HWWrapper::UtilSub depends on HW 's variables...";

use File::Spec;

use HWWrapper;
use HWWrapper::Functions;

my $wrapper = HWWrapper->new;


my @tests = (

    ### shell_eval_str ###

    sub {
        my @args = $wrapper->shell_eval_str('cmd');    # cmd
        is @args, 1;
    },
    sub {
        my ($args) = $wrapper->shell_eval_str('cmd');    # cmd
        is $args->[0], 'cmd';
    },

    # quotes
    sub {
        my ($args) = $wrapper->shell_eval_str('"cmd"');    # "cmd"
        is $args->[0], 'cmd';
    },
    sub {
        my @args = $wrapper->shell_eval_str('"cmd notargs"');    # "cmd notargs"
        is @args, 1;
    },
    sub {
        my @args = $wrapper->shell_eval_str(q('cmd'));    # cmd
        is @args, 1;
    },
    sub {
        my ($args) = $wrapper->shell_eval_str(q('cmd'));    # cmd
        is $args->[0], 'cmd';
    },

    sub {
        my ($args) = $wrapper->shell_eval_str('cmd args');    # cmd args
        is @$args, 2;
    },
    sub {
        my ($args) = $wrapper->shell_eval_str('cmd args');    # cmd args
        is $args->[0], 'cmd';
    },
    sub {
        my ($args) = $wrapper->shell_eval_str('cmd args');    # cmd args
        is $args->[1], 'args';
    },

    # double quote in double quotes
    sub {
        my @args = $wrapper->shell_eval_str(q("foo\\"bar"));    # "foo\"bar"
        is @args, 1;
    },
    sub {
        my ($args) = $wrapper->shell_eval_str(q("foo\\"bar"));    # "foo\"bar"
        is $args->[0], 'foo"bar';
    },
    sub {
        my ($args) = $wrapper->shell_eval_str(q("foo\\"bar\\"baz"));    # "foo\"bar\"baz"
        is $args->[0], 'foo"bar"baz';
    },

    # newline
    sub {
        my ($args) = $wrapper->shell_eval_str(q("foo\\nbar"));    # "foo\nbar"
        is $args->[0], "foo\nbar";
    },
    sub {
        my ($args) = $wrapper->shell_eval_str(q("foo\\nbar"));    # "foo\nbar"
        is $args->[0], "foo\nbar";
    },

    # backslash
    sub {
        my ($args) = $wrapper->shell_eval_str(q("\\\\"));    # "\\"
        is $args->[0], "\\";
    },
    sub {
        my ($args) = $wrapper->shell_eval_str(q('\\\\'));    # '\\'
        is $args->[0], "\\" x 2;
    },
    sub {
        my ($args) = $wrapper->shell_eval_str(q(\\\\));    # \\
        is $args->[0], "\\";
    },

    # empty string
    sub {
        my @args = $wrapper->shell_eval_str(q(""));    # ""
        is @args, 1;
    },
    sub {
        my ($args) = $wrapper->shell_eval_str(q(""));    # ""
        is $args->[0], '';
    },
);
plan tests => scalar @tests;


$_->() for @tests;
