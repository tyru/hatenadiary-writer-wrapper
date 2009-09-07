use strict;
use warnings;

use Test::More;
use Test::Exception;

use List::Util qw(first);


use HWWrapper;
my $wrapper = HWWrapper->new;

my %alias = (
    foo => 'bar',
);
while (my ($k, $v) = each %alias) {
    $wrapper->{config}{alias}{$k} = $v;
}


my @tests = (
    sub {
        ok ! $wrapper->is_command('update'), "'update' is not command";
    },
    sub {
        ok $wrapper->is_alias('update'), "'update' is alias";
    },
    sub {
        ok ! $wrapper->is_command('foo'), "'foo' is not command";
    },
    sub {
        ok $wrapper->is_alias('foo'), "'foo' is alias";
    },
    sub {
        ok $wrapper->expand_alias('foo') == 1, "'foo' is alias of 'bar'";
    },
    sub {
        is(
            ${[ $wrapper->expand_alias('foo') ]}[0],
            'bar',
            "'foo' is alias of 'bar'"
        );
    },
);
plan tests => scalar @tests;


$_->() for @tests;
