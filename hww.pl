#!/usr/bin/env perl
package hww_main;    # For safety. package 'main' is in hw.pl

use strict;
use warnings;
use utf8;

use File::Spec;

use FindBin qw($Bin);
our $BASE_DIR;
our $HWW_LIB;
BEGIN {
    $BASE_DIR = $Bin;
    $HWW_LIB = "$Bin/lib-hww";
}
use lib $HWW_LIB;

use HWWrapper;
my $wrapper = HWWrapper->new;



### sub ###
sub usage () {
    $wrapper->dispatch('help');
    exit -1;
}

sub version () {
    $wrapper->dispatch('version');
    exit -1;
}



### main ###
usage() unless @ARGV;
$wrapper->dispatch_with_args(@ARGV);


__END__

=head1 NAME

    hww.pl - Hatena Diary Writer Wrapper


=head1 SYNOPSIS

    $ perl hww.pl [--help] [--version] [-d | --debug] [-D | --debug-stderr] [-C | --no-cookie] COMMAND [ARGS]


=head1 AUTHOR

    tyru <tyru.exe@gmail.com>

