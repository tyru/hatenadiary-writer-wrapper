#!perl
use strict;
use warnings;

use Test::More;
eval "use Test::Pod";
plan skip_all => "Test::Pod required for testing POD:$@" if $@;


all_pod_files_ok(all_pod_files(qw(lib-hww)));
