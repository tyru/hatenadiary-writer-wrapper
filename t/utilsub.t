use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output qw(output_from);
# plan 'skip_all' => "HWWrapper::UtilSub depends on HW 's variables...";

use HWWrapper::UtilSub;


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
            defined(get_entrydate("1990-08-16-path including \n and white space.txt")),
            "path including whitespaces are allowed"
        );
    },
    sub {
        ok find_headlines(<<EOB) == 1;
*headline*
body
EOB
    },
    sub {
        ok find_headlines(<<EOB) == 0;
  *not headline*
body
EOB
    },
    sub {
        ok find_headlines(<<EOB) == 1;
*headline**not headline*
body
EOB
    },
    sub {
        ok find_headlines(<<EOB) == 1;
*headline* *not headline*
body
EOB
    },
    sub {
        ok find_headlines(<<EOB) == 1;
*headline*
body
** not headline
EOB
    },

    sub {
        ok \&HWWrapper::UtilSub::dump == \&dump, 'dump() was exported';
    },
    sub {
        ok \&HWWrapper::UtilSub::dump == \&CORE::GLOBAL::dump, 'dump() was exported';
    },

    sub {
        ok ! loaded_hw(), "loaded_hw() is false";
    },
    sub {
        require HW;
        ok loaded_hw(), "loaded_hw() is true";
    },
);
plan tests => scalar @tests;


$_->() for @tests;
