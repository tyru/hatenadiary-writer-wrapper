use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output qw(output_from);
# plan 'skip_all' => "HWWrapper::UtilSub depends on HW 's variables...";

use HWWrapper;
use HWWrapper::UtilSub::Functions;

my $wrapper = HWWrapper->new(args => []);


my @tests = (
    sub {
        dies_ok { error() };
    },
    sub {
        dies_ok { error("going to die!!") }, "error() dies ok";
    },
    sub {
        lives_ok {
            # trap STDOUT and STDERR
            # (but can't stop warning() from dying)
            output_from { warning("warn") }
        }, "warning() won't die";
    },

    sub {
        use File::Basename;
        ok(
            defined($wrapper->get_entrydate("1990-08-16-path including \n and white space.txt")),
            "path including whitespaces are allowed"
        );
    },
    sub {
        is $wrapper->find_headlines(<<EOB), 1;
*headline*
body
EOB
    },
    sub {
        is $wrapper->find_headlines(<<EOB), 0;
  *not headline*
body
EOB
    },
    sub {
        is $wrapper->find_headlines(<<EOB), 1;
*headline**not headline*
body
EOB
    },
    sub {
        is $wrapper->find_headlines(<<EOB), 1;
*headline* *not headline*
body
EOB
    },
    sub {
        is $wrapper->find_headlines(<<EOB), 1;
*headline*
body
** not headline
EOB
    },

    sub {
        is \&HWWrapper::UtilSub::dump, \&dump, 'dump() was exported';
    },
    sub {
        is \&HWWrapper::UtilSub::dump, \&CORE::GLOBAL::dump, 'dump() was exported';
    },

    ### shell_eval_string ###
    # TODO separate this into another file
    sub {
        my @args = $wrapper->shell_eval_string('cmd');    # cmd
        is @args, 1;
    },
    sub {
        my ($args) = $wrapper->shell_eval_string('cmd');    # cmd
        is $args->[0], 'cmd';
    },

    # quotes
    sub {
        my ($args) = $wrapper->shell_eval_string('"cmd"');    # "cmd"
        is $args->[0], 'cmd';
    },
    sub {
        my @args = $wrapper->shell_eval_string('"cmd notargs"');    # "cmd notargs"
        is @args, 1;
    },
    sub {
        my @args = $wrapper->shell_eval_string(q('cmd'));    # cmd
        is @args, 1;
    },
    sub {
        my ($args) = $wrapper->shell_eval_string(q('cmd'));    # cmd
        is $args->[0], 'cmd';
    },

    sub {
        my ($args) = $wrapper->shell_eval_string('cmd args');    # cmd args
        is @$args, 2;
    },
    sub {
        my ($args) = $wrapper->shell_eval_string('cmd args');    # cmd args
        is $args->[0], 'cmd';
    },
    sub {
        my ($args) = $wrapper->shell_eval_string('cmd args');    # cmd args
        is $args->[1], 'args';
    },

    # double quote in double quotes
    sub {
        my @args = $wrapper->shell_eval_string(q("foo\\"bar"));    # "foo\"bar"
        is @args, 1;
    },
    sub {
        my ($args) = $wrapper->shell_eval_string(q("foo\\"bar"));    # "foo\"bar"
        is $args->[0], 'foo"bar';
    },
    sub {
        my ($args) = $wrapper->shell_eval_string(q("foo\\"bar\\"baz"));    # "foo\"bar\"baz"
        is $args->[0], 'foo"bar"baz';
    },

    # newline
    sub {
        my ($args) = $wrapper->shell_eval_string(q("foo\\nbar"));    # "foo\nbar"
        is $args->[0], "foo\nbar";
    },
    sub {
        my ($args) = $wrapper->shell_eval_string(q("foo\\nbar"));    # "foo\nbar"
        is $args->[0], "foo\nbar";
    },

    # backslash
    sub {
        my ($args) = $wrapper->shell_eval_string(q("\\\\"));    # "\\"
        is $args->[0], "\\";
    },
    sub {
        my ($args) = $wrapper->shell_eval_string(q('\\\\'));    # '\\'
        is $args->[0], "\\" x 2;
    },
    sub {
        my ($args) = $wrapper->shell_eval_string(q(\\\\));    # \\
        is $args->[0], "\\";
    },

    # empty string
    sub {
        my @args = $wrapper->shell_eval_string(q(""));    # ""
        is @args, 1;
    },
    sub {
        my ($args) = $wrapper->shell_eval_string(q(""));    # ""
        is $args->[0], '';
    },
);
plan tests => scalar @tests;


$_->() for @tests;
