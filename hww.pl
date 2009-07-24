#!/usr/bin/env perl
package hww_main;    # For safety. package 'main' is in hw.pl

use strict;
use warnings;
use utf8;

use FindBin;
our $HWW_LIB;
BEGIN {
    $HWW_LIB = "$FindBin::Bin/hwwlib";
}
use lib $HWW_LIB;

use HWW;


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
    local @ARGV = @{ shift() };
    my $opt = shift;

    GetOptions(%$opt) or do {
        warning "arguments error";
        sleep 1;
        usage;
    };
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
});

usage   if $show_help;
version if $show_version;
usage   unless defined $subcmd;

HWW->dispatch($subcmd, $subcmd_args);

