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



### sub ###
sub usage () {
    HWW->dispatch('help');
}

sub version () {
    HWW->version(@_);
}

sub restore_args {
    my %opt = @_;
    my @argv;

    while (my ($k, $v) = each %opt) {
        # deref.
        $v = $$v;
        # option was not given.
        next    unless defined $v;

        if ($k =~ s/(.*)=s$/$1/) {
            debug("restore: option -$k => $v");
            push @argv, "-$k", $v;
        } else {
            debug("restore: option -$k");
            push @argv, "-$k";
        }
    }

    return @argv;
}



### main ###
my ($hww_args, $subcmd, $subcmd_args) = split_opt(@ARGV);

my $show_help;
my $show_version;
our $debug;
our $no_cookie;
# hw.pl's options.
our %hw_opt = (
    t => \my $t,
    # trivial => \$trivial,

    'u=s' => \my $u,
    # 'username=s' => \$username,

    'p=s' => \my $p,
    # 'password=s' => \$password,

    'a=s' => \my $a,
    # 'agent=s' => \$agent,

    'T=s' => \my $T,
    # 'timeout=s' => \$timeout,

    'g=s' => \my $g,
    # 'group=s' => \$group,

    'f=s' => \my $f,
    # 'file=s' => \$entry_file,

    M => \my $M,

    'n=s' => \my $n,
    # 'config-file=s'

    S => \my $S,
    # ssl => \$ssl,
);


# do not change $hww_args.
my %hww_opt = (
    help => \$show_help,
    version => \$show_version,
    d => \$debug,
    debug => \$debug,

    C => \$no_cookie,
    'no-cookie' => \$no_cookie,

    %hw_opt,
);

get_opt($hww_args, \%hww_opt) or do {
    warning "arguments error";
    sleep 1;
    usage;
};

{
    # restore $hww_args for hw.pl
    local @ARGV = restore_args(%hw_opt);
    debug('restored @ARGV: '.join(' ', @ARGV));

    # for using subroutine which manipulates
    # API without module.
    require 'hw.pl';

    # use cookie. (default)
    no warnings 'once';
    $hw_main::cmd_opt{c} = 1;
}


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
