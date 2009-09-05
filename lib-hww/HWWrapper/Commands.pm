package HWWrapper::Commands;

use strict;
use warnings;
use utf8;

use base qw(Exporter HWWrapper::Base);
our @EXPORT = our @EXPORT_OK = qw(
    %HWW_COMMAND
    $BASE_DIR
    $HWW_LIB
    $POD_DIR
);

use HWWrapper::Functions;

use Carp;
use File::Spec;


# our %HWW_COMMAND = (
#     # TODO commands to manipulate tags.
#     # 'add-tag' => 'add_tag',
#     # 'delete-tag' => 'delete_tag',
#     # 'rename-tag' => 'rename_tag',
# 
#     # TODO 設定(ファイルはconfig-hww.txt)を変えるコマンド
#     # config => 'config',
# 
#     # - ファイルが変更されたら、何らかの処理を実行できるコマンド
#     # (「ファイルが変更された」以外にも色んなイベントに対応できるようにする)
#     # watch => 'watch',
# );


our %HWW_COMMAND = map {
    $_ => undef,
} qw(
    apply-headline
    chain
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
    update
    update-index
    verify
    version
);

our $BASE_DIR = File::Spec->rel2abs(
    File::Spec->catdir(dirname(__FILE__), '..', '..')
);

our $HWW_LIB = File::Spec->catfile($BASE_DIR, "lib-hww");

our $POD_DIR = File::Spec->catfile($HWW_LIB, 'pod');



sub regist_command {
    my ($self, $cmd) = @_;

    $self->_regist($cmd);

    unless (defined $HWW_COMMAND{$cmd}{coderef}) {
        $self->error("assertion failure");
    }

    # this must return coderef, command info.
    return ($HWW_COMMAND{$cmd}{coderef}, $HWW_COMMAND{$cmd});
}

sub regist_all_command {
    my ($self) = @_;

    for (keys %HWW_COMMAND) {
        $self->_regist($_);
    }
}

sub _regist {
    my ($self, $cmd) = @_;

    # command name -> package's name in which command is defined.
    my $pkg = $self->cmd2pkg($cmd);

    # load it.
    eval "require $pkg";
    if ($@) {
        # not found!
        $self->debug($@);
        $self->error("'$cmd' is not a hww command.");
    }

    # stash command info to %HWW_COMMAND.
    # $pkg knows what this will regist.
    $pkg->regist_command()
        unless defined $HWW_COMMAND{$cmd};    # cache!!
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



### hww commands ###

1;
