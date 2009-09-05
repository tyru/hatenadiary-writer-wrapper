use strict;
use warnings;

use Test::More;
use Test::Exception;


use File::Spec;

use HWWrapper;
my $wrapper = HWWrapper->new;


my @tests = (
    sub {
        return map {
            my $cmd = $_;
            sub {
                ok $wrapper->is_command($cmd), "$cmd is hww command";
            }
        } keys %HWWrapper::Commands::HWW_COMMAND;
    }->(),
);
plan tests => scalar @tests;


$_->() for @tests;
