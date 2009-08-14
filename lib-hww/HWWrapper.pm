package HWWrapper;

# TODO
# - コマンドのヘルプドキュメント書く
# - $selfがblessedされてるかチェックするアトリビュート
# - ログインなどの処理をHatena AtomPub APIを使うように書き換える。
# 現在の処理もオプションで指定すれば使用できるようにする。
# - 'load'コマンドで取ってきたファイルの先頭行に空行が入るバグを直す
# - エラー時にcookie.txtを削除 (DESTROY? $SIG{__DIE__}?)
# - 引数を保存するハッシュにわざわざ\undefを置いておくぐらいならキーのみ指定させて後から\undef追加すればいいんでは
# - shell_eval_str()はutf8に対応しているか。ダメ文字にひっかからないか。またUTF-8じゃない端末ではどうか。
# - %HWWrapper::Commands::HWW_COMMANDを見て、dispatchでget_optを事前にやっといて、第3引数として渡す
# - プロファイリングして最適化
# - '--verbose'オプションを追加。
# -- 現在の--debugの様なオプション。動作が変わることはない。(Enter押さないと次の処理に移らないとかはない)
#
# - config-hww.txtにHWWrapperの設定を書く
# -- フォーマットはYAML
# (YAML::XSとYAMLは互換性がないらしい。XSを使うのはWindowsにとって厳しいのでYAMLモジュールを使う)
# -- $EDITORの設定
# -- hww.plに常に付ける引数(.provercや.ctagsみたいな感じ)
# -- コマンド名をミスった場合に空気呼んで似てるコマンドを呼び出すか訊く設定 (zshのcorrectみたいに)
# -- パスワードを入力中、端末に表示するかしないか
#
# XXX
# - save_diary_draft()がクッキーを使ってログインできてない気がする
# (一回ログインした次が401 Authorizedになる)
# -- それLWP::Authen::Wsse使ってるからじゃ・・・
# -- 違った。はてなのAtomPub APIがcookieでの認証廃止したからだった。
# 受け取ったcookieは即expiredになる。



# NOTE
# - new()で設定のデフォルト値をセットして
# - load_config()で設定ファイルの値をセットして
# - parse_opt()で引数の値をセット



use strict;
use warnings;
use utf8;

our $VERSION = '1.6.4';

use base qw(HW HWWrapper::Commands);

# import builtin op's hooks
# (these ops are hooked in HWWrapper::Commands::shell())
#
# and this package also exports these ops.
use HWWrapper::Hook::BuiltinFunc;
# import all util commands!!
use HWWrapper::Functions;


use Carp;
use File::Basename qw(basename);
use Scalar::Util qw(blessed);



our $debug = 0;
our $debug_stderr = 0;
our $no_cookie = 0;





### new() ###

sub new {
    my $pkg = shift;
    if (blessed $pkg) {
        croak "you have already been initialized!";
    }

    my $self = bless { @_ }, $pkg;

    if (exists $self->{args}) {
        my ($opts, $cmd, $cmd_args) = split_opt(@{ $self->{args} });
        $self->{args} = {
            options => $opts,
            command => $cmd,
            command_args => $cmd_args,
        };
    }
    else {
        croak "currently 'args' option is required!!";
    }


    $self->{config} = {
        # this option is default to 1.
        # to make this false, pass '-C' or '--no-cookie' option.
        use_cookie => 1,

        is_debug => 0,
    };
    $self->{arg_opt}{HWWrapper} = {
        d => \$debug,
        debug => \$debug,

        D => \$debug_stderr,
        'debug-stderr' => \$debug_stderr,

        C => \$no_cookie,
        'no-cookie' => \$no_cookie,
    };

    # initialize config of HW.
    $self->SUPER::new;
}



### load_config() ###

sub load_config {
    my $self = shift;

    my $config_file = 'config-hww.txt';
    $self->get_opt_only($self->{args}{options}, {
        'N=s' => \$config_file,
        'config-hww=s' => \$config_file,
    }) or error("arguments error");

    if (-f $config_file) {
        # TODO
    }
    else {
        debug("$config_file is not found. skip to load config...");
    }


    $self->SUPER::load_config;
}



### parse_opt() ###

# this is additinal options which I added.
# not hw.pl's options.
# TODO
# DO NOT DEPEND ON %HW::arg_opt !
# THAT HAS BEEN DELETED ALREADY!!
# our %hw_opt_long = (
#     trivial => \$HW::arg_opt{t},
#     'username=s' => \$HW::arg_opt{u},
#     'password=s' => \$HW::arg_opt{p},
#     'agent=s' => \$HW::arg_opt{a},
#     'timeout=s' => \$HW::arg_opt{T},
#     'group=s' => \$HW::arg_opt{g},
#     'file=s' => \$HW::arg_opt{f},
#     'no-replace' => \$HW::arg_opt{M},
#     'config-file=s' => \$HW::arg_opt{n},
# );

sub parse_opt {
    my $self = shift;
    unless (blessed $self) {
        croak 'give me blessed $self.';
    }
    unless (exists $self->{args}) {
        croak "you did not passed 'args' option to HWWrapper->new().";
    }

    my $options = $self->{args}{options};
    my $cmd = $self->{args}{command};
    my $cmd_args = $self->{args}{command_args};

    return ($cmd, $cmd_args) unless @$options;


    # parse hww.pl's options.
    $self->get_opt_only(
        $options,
        $self->{arg_opt}{HWWrapper}
    ) or do {
        warning("arguments error");
        sleep 1;
        $self->dispatch('help');
        exit -1;
    };

    $self->use_cookie = ! $no_cookie;
    $self->is_debug   = ($debug || $debug_stderr);

    # option arguments result handling
    if ($debug) {
        print ${ $DEBUG->string_ref };    # flush all
        $DEBUG = *STDOUT;
    }
    elsif ($debug_stderr) {
        warning(${ $DEBUG->string_ref });    # flush all
        $DEBUG = *STDERR;
    }
    else {
        $DEBUG = FileHandle->new(File::Spec->devnull, 'w') or error("Can't open null device.");
    }


    # parse HW 's options.
    if (@$options) {
        $self->SUPER::parse_opt();
    }


    return ($cmd, $cmd_args);
}



### dispatch() ###

sub dispatch {
    my $self = shift;
    my ($cmd, $args) = @_;
    $args = [] unless defined $args;

    unless (blessed $self) {
        croak 'give me blessed $self.';
    }

    # detect some errors.
    unless (defined $cmd) {
        error("no command was given.");
    }
    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl hww.pl help");
    }

    # some debug messages.
    my ($filename, $line) = (caller)[1,2];
    $filename = basename($filename);
    debug(sprintf '$self->dispatch(%s) at %s line %s',
            join(', ', map { dumper($_) } @_), $filename, $line);


    my $coderef = $HWWrapper::Commands::HWW_COMMAND{$cmd}{coderef};
    $coderef->($self, $args);
}

### dispatch_with_args() ###

sub dispatch_with_args {
    my $self = shift;
    my @argv = @_;

    unless (blessed($self)) {
        croak 'give me blessed $self.';
    }
    unless (exists $self->{args}) {
        croak 'you have not passed args option.';
    }


    # currently this calls HW::load_config() directly.
    $self->load_config;

    # parse options in @_
    my ($cmd, $cmd_args) = $self->parse_opt(@argv);

    # for memory
    # delete $self->{arg_opt};

    $self->dispatch(defined $cmd ? $cmd : 'help', $cmd_args);
}



1;
