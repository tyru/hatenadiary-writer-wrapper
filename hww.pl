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
    $HWW_LIB  = File::Spec->catfile($Bin, 'lib-hww');
}
use lib $HWW_LIB;

use HWWrapper;



### sub ###
sub usage () {
    HWWrapper->dispatch('help');
    exit -1;
}

sub version () {
    HWWrapper->version(@_);
    exit -1;
}



### main ###
usage() unless @ARGV;

HWWrapper->new->dispatch_with_args;
# my $wrapper = HWWrapper->new;
# my ($cmd, $cmd_args) = $wrapper->parse_opt(@ARGV);
# $wrapper->dispatch($cmd => $cmd_args);


__END__

=head1 NAME

    hww.pl - Hatena Diary Writer Wrapper


=head1 SYNOPSIS

    $ perl hww.pl [--help] [--version] [-d | --debug] [-D | --debug-stderr] [-C | --no-cookie] COMMAND [ARGS]


=head1 AUTHOR

    tyru <tyru.exe@gmail.com>
