use strict;
use warnings;

use Test::More;


use HWWrapper;
my $wrapper = HWWrapper->new;


my @tests = (
    # $self->{config}
    sub {
        map {
            my $ac = $_;
            sub {
                ok $wrapper->can($ac), "\$wrapper can $ac";
            }
        } keys %{ $wrapper->{config} };
    }->(),
    # $self->{config}
    sub {
        map {
            my $ac = $_;
            sub {
                eval {
                    $wrapper->$ac = 1;
                };
                ok ! $@, "$ac is lvalue";
                # like $@, qr/Can't modify non-lvalue subrountine call/, "Can't modify non-lvalue subrountine call";
            }
        } keys %{ $wrapper->{config} };
    }->(),
);
plan tests => scalar @tests;


$_->() for @tests;
