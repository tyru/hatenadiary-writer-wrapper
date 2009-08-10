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
my $wrapper = HWWrapper->new(args => \@ARGV);



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
$wrapper->dispatch_with_args;


__END__

=head1 NAME

    hww.pl - Hatena Diary Writer Wrapper


=head1 SYNOPSIS

    $ perl hww.pl [HWW_OPTIONS] [HW_OPTIONS] COMMAND [ARGS]


=head1 HWW OPTIONS

=over

=item -d, --debug

print debug messages.

=item -D, --debug-stderr

print debug messages to stderr.

=item -C, --no-cookie

don't use cookie.

=back


=head1 HW OPTIONS

=over

=item -t

Trivial. Use this switch for trivial edit (i.e. typo).

=item -u username

Username. Specify username.

=item -p password

Password. Specify password.

=item -a agent

User agent. Default value is HatenaDiaryWriter/$VERSION.

=item -T seconds

Timeout. Default value is 180.

=item -c

Cookie. Skip login/logout if $cookie_file exists.

=item -g groupname

Groupname. Specify groupname.

=item -f filename

File. Send only this file without checking timestamp.

=item -M

Do NOT replace *t* with current time.

=item -n config_file

Config file. Default value is $config_file.

=item -l YYYY-MM-DD

Load diary.

=back


=head1 AUTHOR

    tyru <tyru.exe@gmail.com>

