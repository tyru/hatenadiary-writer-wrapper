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
    exit -1;
}

sub version () {
    HWW->version(@_);
    exit -1;
}

# for hw.pl
sub restore_hw_opt {
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
usage() unless @ARGV;
my ($hww_args, $subcmd, $subcmd_args) = split_opt(@ARGV);

my $show_help;
my $show_version;
our $no_cookie;
# hw.pl's options.
our %hw_opt = (
    t => \my $t,

    'u=s' => \my $u,

    'p=s' => \my $p,

    'a=s' => \my $a,

    'T=s' => \my $T,

    'g=s' => \my $g,

    'f=s' => \my $f,

    M => \my $M,

    'n=s' => \my $n,

    S => \my $S,
);

# this is additinal options which I added.
# not hw.pl's options.
our %hw_opt_long = (
    trivial => $hw_opt{t},
    'username=s' => $hw_opt{'u=s'},
    'password=s' => $hw_opt{'p=s'},
    'agent=s' => $hw_opt{'a=s'},
    'timeout=s' => $hw_opt{'T=s'},
    'group=s' => $hw_opt{'g=s'},
    'file=s' => $hw_opt{'f=s'},
    'no-replace' => $hw_opt{M},
    'config-file=s' => $hw_opt{'n=s'},
    ssl => $hw_opt{S},
);


# do not change $hww_args.
our $debug;
our $debug_stderr;
my %hww_opt = (
    help => \$show_help,
    version => \$show_version,

    d => \$debug,
    debug => \$debug,

    D => \$debug_stderr,
    'debug-stderr' => \$debug_stderr,

    C => \$no_cookie,
    'no-cookie' => \$no_cookie,

    %hw_opt,
    %hw_opt_long,
);

get_opt($hww_args, \%hww_opt) or do {
    warning "arguments error";
    sleep 1;
    usage();
};

# restore $hww_args for hw.pl
my @argv = restore_hw_opt(%hw_opt);
# pass only hw.pl's options
HWW->parse_opt(@argv);

$HW::cmd_opt{c} = 1 unless $no_cookie;
$HW::cmd_opt{d} = 1 if $debug;
# apply the result options which was parsed in this script to hw.pl
# update %HW::cmd_opt with %hw_opt.
%HW::cmd_opt = (%HW::cmd_opt, map {
    defined ${ $hw_opt{$_} } ?    # if option was given
    ((split '=')[0] => $hw_opt{$_}) :
    ()
} keys %hw_opt);


usage()   if $show_help;
version() if $show_version;
usage()   unless defined $subcmd;

HWW->dispatch($subcmd => $subcmd_args);


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
