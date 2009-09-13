package HWWrapper::Commands;

# class for methods and data for commands.
#
#

use strict;
use warnings;
use utf8;

use base qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(
    %HWW_COMMAND
    $BASE_DIR
    $HWW_LIB
    $POD_DIR
);

use HWWrapper::Functions;

use Carp;
use File::Spec;



our %HWW_COMMAND = map {
    $_ => undef,
} qw(
    apply-headline
    copyright
    diff
    editor
    gen-html
    help
    init
    load
    release
    revert-headline
    shell
    status
    touch
    truncate
    update-index
    verify
    version
);

our $BASE_DIR = File::Spec->rel2abs(
    File::Spec->catdir(dirname(__FILE__), '..', '..')
);

our $HWW_LIB = File::Spec->catfile($BASE_DIR, "lib-hww");

our $POD_DIR = File::Spec->catfile($HWW_LIB, 'pod');



sub get_command {
    my ($self, $cmd) = @_;

    # regist if $cmd is not found.
    unless ($self->loaded($cmd)) {
        $self->regist_command($cmd) || return undef;
    }

    return $HWW_COMMAND{$cmd};
}

sub regist_all_command {
    my ($self) = @_;

    for (keys %HWW_COMMAND) {
        $self->regist_command($_) || return 0;
    }
    return 1;
}

sub regist_command {
    my ($self, $cmd) = @_;
    return 1 if $self->loaded($cmd);

    # failed to regist
    $self->_regist($cmd) || return 0;
    unless (exists $HWW_COMMAND{$cmd} && exists $HWW_COMMAND{$cmd}{coderef}) {
        return 0;
    }

    return 1;
}

# regist if not loaded.
sub _regist {
    my ($self, $cmd) = @_;

    # command name -> package's name in which command is defined.
    my $pkg = $self->cmd2pkg($cmd);

    # load it.
    eval "require $pkg";
    if ($@) {
        # not found!
        return 0;
    }

    # stash command info to %HWW_COMMAND.
    # $pkg knows what this will regist.
    $pkg->regist_command();

    return $self->loaded($cmd);
}

sub loaded {
    my ($self, $cmd) = @_;

    exists $HWW_COMMAND{$cmd} &&
    exists $HWW_COMMAND{$cmd}{coderef};
}

sub cmd2pkg {
    my ($self, $cmd) = @_;

    # split with non-word character
    my @words = split /\W+/, $cmd;
    $_ = ucfirst lc $_ for @words;
    $cmd = "HWWrapper::Commands::" . join '', @words;

    return $cmd;
}

sub pkg2cmd {
    my ($self, $pkg) = @_;

    $pkg =~ s/^HWWrapper::Commands:://;
    $pkg =~ s/[A-Z]/'-' . lc($1)/eg;

    return $pkg;
}



1;
