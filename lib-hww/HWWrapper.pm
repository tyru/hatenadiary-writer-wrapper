package HWWrapper;

# TODO
# - コマンドのヘルプドキュメント書く
# - 'load'コマンドで取ってきたファイルの先頭行に空行が入るバグを直す
# - エラー時にcookie.txtを削除 (DESTROY? $SIG{__DIE__}?)
# - プロファイリングして最適化
# - '--verbose'オプションを追加。
# -- 現在の--debugの様なオプション。動作が変わることはない。(Enter押さないと次の処理に移らないとかはない)
#
# - config-hww.txtにHWWrapperの設定を書く
# -- フォーマットは拡張子によって決まる。ymlだったらYAML。txtだったらconfig.txtと同じような形式。
# (YAML::XSとYAMLは互換性がないらしい。XSを使うのはWindowsにとって厳しいのでYAMLモジュールを使う)
# -- $EDITORの設定
# -- hww.plに常に付ける引数(.provercや.ctagsみたいな感じ)
# -- コマンド名をミスった場合に空気呼んで似てるコマンドを呼び出すか訊く設定 (zshのcorrectみたいに)
# -- パスワードを入力中、端末に表示するかしないか
# -- 補完関数の細かな挙動 (隠しファイルを補完するかなど)


# NOTE
# - new()で設定のデフォルト値をセットして
# - load_config()で設定ファイルの値をセットして
# - parse_opt()で引数の値をセット



use strict;
use warnings;
use utf8;

our $VERSION = '1.7.7';

use base qw(HW HWWrapper::Commands);

# import builtin func's hooks
use HWWrapper::Hook::BuiltinFunc;
# import all util commands!!
use HWWrapper::Functions;


use Carp;
use File::Basename qw(basename);
use Scalar::Util qw(blessed);
use IO::String;



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


    # set members
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
    $self->{debug_fh} = IO::String->new;

    # split arguments
    if (exists $self->{args}) {
        my ($opts, $cmd, $cmd_args) = $self->split_opt(@{ $self->{args} });
        $self->{args} = {
            options => $opts,
            command => $cmd,
            command_args => $cmd_args,
        };
    }
    else {
        croak "currently, 'args' option is required!!";
    }

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
    }) or $self->error("arguments error");

    if (-f $config_file) {
        # TODO
    }
    else {
        $self->debug("$config_file is not found. skip to load config...");
    }


    $self->SUPER::load_config;
}



### parse_opt() ###

sub parse_opt {
    my $self = shift;
    unless (blessed $self) {
        croak 'give me blessed $self.';
    }
    unless (exists $self->{args}) {
        croak "you did not passed 'args' option to HWWrapper->new().";
    }

    my $options  = $self->{args}{options};
    my $cmd      = $self->{args}{command};
    my $cmd_args = $self->{args}{command_args};

    return ($cmd, $cmd_args) unless @$options;


    # parse hww.pl's options.
    $self->get_opt_only(    # do get_opt_only() for HW(SUPER::parse_opt()).
        $options,
        $self->{arg_opt}{HWWrapper}
    ) or do {
        $self->warning("arguments error");
        sleep 1;
        $self->dispatch('help');
        exit -1;
    };

    $self->use_cookie = ! $no_cookie;
    $self->is_debug   = ($debug || $debug_stderr);

    # option arguments result handling
    if ($debug) {
        print ${ $self->{debug_fh}->string_ref };    # flush all
        $self->{debug_fh} = *STDOUT;
    }
    elsif ($debug_stderr) {
        $self->warning(${ $self->{debug_fh}->string_ref });    # flush all
        $self->{debug_fh} = *STDERR;
    }
    else {
        $self->{debug_fh} = FileHandle->new(File::Spec->devnull, 'w') or $self->error("Can't open null device.");
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
        $self->error("no command was given.");
    }
    unless (is_hww_command($cmd)) {
        $self->error("'$cmd' is not a hww-command. See perl hww.pl help");
    }

    # some debug messages.
    my ($filename, $line) = (caller)[1,2];
    $filename = basename($filename);
    $self->debug(sprintf '$self->dispatch(%s) at %s line %s',
            join(', ', map { dumper($_) } @_), $filename, $line);

    # get arguments value
    my %opt;
    my $cmd_info = $HWWrapper::Commands::HWW_COMMAND{$cmd};
    if (exists $cmd_info->{option}) {
        # prepare result options.
        %opt = map {
            $_ => \do {my $anon_scalar}
        } keys %{ $cmd_info->{option} };

        # get options.
        $self->get_opt($args, \%opt) or $self->arg_error($cmd);

        # deref values.
        $opt{$_} = ${ $opt{$_} } for keys %opt;
    }

    # dispatch
    $cmd_info->{coderef}->($self, $args, \%opt);
}

### dispatch_with_args() ###

sub dispatch_with_args {
    my $self = shift;

    unless (blessed($self)) {
        croak 'give me blessed $self.';
    }
    unless (exists $self->{args}) {
        croak 'you have not passed args option.';
    }


    # currently this calls HW::load_config() directly.
    $self->load_config;

    # parse options
    my ($cmd, $cmd_args) = $self->parse_opt();

    # for memory
    # delete $self->{arg_opt};

    $self->dispatch(defined $cmd ? $cmd : 'help', $cmd_args);
}



1;
