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
elsif ($@) {
    die $@;
}



HWWrapper->new->run(@ARGV);

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

=item -N=<config_file>, --config-hww=<config file>

load hww's config file.
default value is 'config-hww.txt'.

=item --no-load-hww

do not load hww's config file.

=back


=head1 HW OPTIONS

=over

=item -u=<username>, --username=<username>

hatena username.

=item -p=<password>, --password=<password>

hatena password.

=item -a=<agent>, --agent=<agent>

user agent.
default value is "HatenaDiaryWriterWrapper/<version_name>".

=item -T=<seconds>, --timeout=<seconds>

timeout.
default value is 180.

=item -c, --use-cookie

use cookie.
skip login/logout if 'cookie.txt'(default name) exists.

=item -g=<groupname>

groupname. specify groupname.

=item -M, --no-timestamp

do not replace *t* with current time.

=item -n=<config_file>, --config-hw=<config_file>

hw's config file.
default value is 'config.txt'.

=item --no-load-hw

do not load hw's config file.

=back


=head1 AUTHOR

hatena diary writer:
    Hiroshi Yuki
    Ryosuke Nanba <http://d.hatena.ne.jp/rna/>
    Hahahaha <http://www20.big.or.jp/~rin_ne/>
    Ishinao <http://ishinao.net/>
    +Loader by Kengo Koseki. <http://d.hatena.ne.jp/koseki2/>

hatena diary writer wrapper:
    tyru <http://d.hatena.ne.jp/tyru/>

