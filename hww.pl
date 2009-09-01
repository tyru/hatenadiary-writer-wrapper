#!/usr/bin/env perl
package hww_main;    # For safety. package 'main' is in hw.pl

use strict;
use warnings;
use utf8;

use File::Spec;

use FindBin qw($Bin);
use lib "$Bin/lib-hww";


eval { require HWWrapper };

if ($@ =~ /^Can't locate (\S*)/) {
    die <<EOM;
$@


error: no prereq modules.

you need to install some modules,
please see README.md for install.

EOM
}



HWWrapper->new->dispatch_with_args(@ARGV);

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

