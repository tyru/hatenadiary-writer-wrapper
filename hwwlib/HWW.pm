package HWW;

use strict;
use warnings;
use utf8;

use version;
our $VERSION = qv('0.0.0');

use File::Spec;
use Pod::Usage;


our %HWW_COMMAND = (
    help => \&help,
    version => \&version,
);



### util commands ###

sub warning {
    warn "warning: ", @_, "\n";
}

sub error {
    die "error: ", @_, "\n";
}

sub debug {
    warn "debug: ", @_, "\n" if $hww_main::debug;
}

sub is_hww_command {
    my ($self, $cmd) = @_;
    $self->can($cmd) && exists $HWW_COMMAND{$cmd};
}



### dispatch ###

sub dispatch {
    my ($self, $cmd, $args) = @_;

    $self = bless {}, $self;

    unless ($self->is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    debug("dispatch $cmd");
    $self->$cmd(@$args);
}



### hww commands ###

sub help {
    my ($self, $cmd) = @_;

    unless (defined $cmd) {
        debug("show HWW.pm pod");
        pod2usage(-verbose => 2, -input => __FILE__);
    }

    unless ($self->is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    my $podpath = File::Spec->catdir($hww_main::HWW_LIB, 'pod', "hww-$cmd.pod");
    unless (-f $podpath) {
        error("we have not written the document of '$cmd' yet. :$!");
    }

    debug("show pod '$podpath'");
    pod2usage(-verbose => 2, -input => $podpath);
}

sub version {
    print <<EOD;
Hatena Diary Writer Wrapper version $HWW::VERSION
EOD
    exit;
}


1;
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

=back


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
