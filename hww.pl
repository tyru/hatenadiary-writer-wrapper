#!/usr/bin/env perl
package hww_main;    # For safety. package 'main' is in hw.pl

use strict;
use warnings;
use utf8;

use FindBin;
our $BASE_DIR;
our $HWW_LIB;
our $TEXT_DIR;
BEGIN {
    $BASE_DIR = $FindBin::Bin;
    $HWW_LIB  = "$FindBin::Bin/hwwlib";
    $TEXT_DIR = "$FindBin::Bin/text";
}
use lib $HWW_LIB;

use HWW;

# for using subroutine which manipulates
# API without module.
require 'hw.pl';


use Getopt::Long;
use File::Spec;





### sub ###
sub usage () {
    HWW->dispatch('help');
}

sub version () {
    HWW->version(@_);
}


sub warning {
    warn "warning: ", @_, "\n"
}

sub error {
    die "error: ", @_, "\n";
}


sub parse_opt {
    my @hww_opt;
    my $subcmd;
    my @subcmd_opt;

    for my $a (@_) {
        if (defined $subcmd) {
            push @subcmd_opt, $a;
        } else {
            if ($a =~ /^-/) {
                push @hww_opt, $a;
            } else {
                $subcmd = $a;
            }
        }
    }

    return (\@hww_opt, $subcmd, \@subcmd_opt);
}

sub getopt {
    my ($argv, $opt) = @_;

    local @ARGV = @$argv;
    my $result = GetOptions(%$opt);

    $argv = [@ARGV];
    return $result;
}


### main ###
my ($hww_args, $subcmd, $subcmd_args) = parse_opt(@ARGV);

my $show_help;
my $show_version;
our $debug;    # HWW::debug() see this.
getopt($hww_args, {
    help => \$show_help,
    version => \$show_version,
    debug => \$debug,
}) or do {
    warning "arguments error";
    sleep 1;
    usage;
};

usage   if $show_help;
version if $show_version;
usage   unless defined $subcmd;

HWW->dispatch($subcmd, $subcmd_args);

