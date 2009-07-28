#!/usr/bin/env perl
package hww_main;    # For safety. package 'main' is in hw.pl

use strict;
use warnings;
use utf8;

use FindBin;
our $BASE_DIR;
our $HWW_LIB;
BEGIN {
    $BASE_DIR = $FindBin::Bin;
    $HWW_LIB  = "$FindBin::Bin/lib-hww";
}
use lib $HWW_LIB;

use HWW;
use HWW::UtilSub;

# for using subroutine which manipulates
# API without module.
require 'hw.pl';


# gnu_compat: --opt="..." is allowed.
# no_bundling: single character option is not bundled.
# no_ignore_case: no ignore case on long option.
use Getopt::Long qw(:config gnu_compat no_bundling no_ignore_case);
use File::Spec;





### sub ###
sub usage () {
    HWW->dispatch('help');
}

sub version () {
    HWW->version(@_);
}


# separate options into hww.pl's options and hw.pl's options.
# (like git)
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
                $subcmd = $a;    # found command
            }
        }
    }

    return (\@hww_opt, $subcmd, \@subcmd_opt);
}

sub getopt {
    my ($argv, $opt) = @_;

    local @ARGV = @$argv;
    my $result = GetOptions(%$opt);

    # update arguments. delete all processed options.
    $argv = [@ARGV];
    return $result;
}


### main ###
my ($hww_args, $subcmd, $subcmd_args) = parse_opt(@ARGV);

my $show_help;
my $show_version;
our $debug;
our $no_cookie;
# our $trivial;
# our $username;
# our $password;
# our $agent;
# our $timeout;
# our $group;
# our $entry_file;
# our $config_file;
# our $no_timestamp;

# do not change $hww_args.
my %hww_opt = (
    help => \$show_help,
    version => \$show_version,
    debug => \$debug,

    C => \$no_cookie,
    'no-cookie' => \$no_cookie,

    # t => \$trivial,
    # trivial => \$trivial,
    # 
    # u => \$username,
    # username => \$username,
    # 
    # p => \$password,
    # password => \$password,
    # 
    # a => \$agent,
    # agent => \$agent,
    # 
    # T => \$timeout,
    # 
    # g => \$group,
    # group => \$group,
    # 
    # f => \$entry_file,
    # file => \$entry_file,
    # 
    # M => \$no_timestamp,
    # 
    # n => \$config_file,
    # 
    # S => \$ssl,
    # ssl => \$ssl,
);

getopt($hww_args, \%hww_opt) or do {
    warning "arguments error";
    sleep 1;
    usage;
};

usage   if $show_help;
version if $show_version;
usage   unless defined $subcmd;

HWW->dispatch($subcmd, $subcmd_args);


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

=item -h,--help

show this help text.

=item -v,--version

show version.

=item -d, --debug

debug mode.

=item -C, --no-cookie

don't use cookie.
(don't call hw.pl with '-c' option)

=back


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
