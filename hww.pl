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

my $wrapper = HWWrapper->new;
my ($cmd, $cmd_args) = $wrapper->parse_opt(@ARGV);
$wrapper->dispatch($cmd => $cmd_args);


__END__

=head1 NAME

    hww.pl - Hatena Diary Writer Wrapper


=head1 SYNOPSIS

    $ perl hww.pl [OPTIONS] COMMAND [ARGS]


=head1 OPTIONS

    these options for 'hww.pl'.
    if you see the help of command options, do it.
    $ perl hww.pl help <command>

=over

=item --help

show this help text.

=item --version

show version.

=item -d, --debug

debug mode.

=item -C, --no-cookie

don't use cookie.
(don't call hw.pl with '-c' option)

=back


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
