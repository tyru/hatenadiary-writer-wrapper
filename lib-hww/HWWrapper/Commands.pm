package HWWrapper::Commands;

use strict;
use warnings;
use utf8;

use base qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(
    %HWW_COMMAND
    $BASE_DIR
    $HWW_LIB
);

# import builtin func's hooks
use HWWrapper::Hook::BuiltinFunc;
use HWWrapper::Functions;

use Carp;
use File::Basename qw(dirname basename);
use Term::ReadLine;


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


our %HWW_COMMAND;

our $BASE_DIR = File::Spec->rel2abs(
    File::Spec->catdir(dirname(__FILE__), '..', '..')
);

our $HWW_LIB = File::Spec->catfile($BASE_DIR, "lib-hww");




sub init_command {
    my ($self, $cmd) = @_;

    # command name -> package's name in which command is defined.
    my $pkg = cmd2pkg($cmd);

    # load it.
    eval "require $pkg";
    if ($@) {
        # not found!
        $self->debug($@);
        $self->cmd_not_found_error($cmd);
    }

    # stash command info to %HWW_COMMAND.
    # $pkg knows what this will regist.
    $pkg->regist_command();

    # assertion
    unless (exists $HWW_COMMAND{$cmd}) {
        $self->error("'$cmd' is not defined in command hash.");
    }

    # this must return coderef, command info.
    return ($HWW_COMMAND{$cmd}{coderef}, $HWW_COMMAND{$cmd});
}

sub cmd2pkg {
    my $cmd = shift;

    # split with non-word character
    my @words = split /\W+/, $cmd;
    $_ = ucfirst lc $_ for @words;
    $cmd = "HWWrapper::Commands::" . join '', @words;

    return $cmd;
}



### hww commands ###

1;
