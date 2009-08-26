use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output qw(output_from);
# plan 'skip_all' => "HWWrapper::UtilSub depends on HW 's variables...";

use File::Spec;

use HWWrapper;
use HWWrapper::Functions;

my $wrapper = HWWrapper->new;


my @tests = (
    sub {
        dies_ok { $wrapper->error() }, "error() dies ok";
    },
    sub {
        dies_ok { $wrapper->error("going to die!!") }, "error() dies ok";
    },
    sub {
        lives_ok {
            # trap STDOUT and STDERR
            # (but can't stop warning() from dying)
            output_from { $wrapper->warning("warn") }
        }, "warning() won't die";
    },

    sub {
        use File::Basename;
        ok(
            defined($wrapper->get_entrydate("1990-08-16-path including \n and white space.txt")),
            "path including whitespaces are allowed"
        ); },
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
);
plan tests => scalar @tests;


$_->() for @tests;
