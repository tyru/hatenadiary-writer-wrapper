package HWWrapper;

# TODO
# - 'load'コマンドで取ってきたファイルの先頭行に空行が入るバグを直す
# - プロファイリングして最適化
#
# - テスト追加
#   - 対話形式 (特定の環境変数がセットされてる場合に行うようにする)
#     - はてなから全エントリを持ってくる
#     - はてなから全下書きを持ってくる
#     - そのエントリが入ったディレクトリにたいしてget\_entrydate()やget\_~()など色んなサブルーチンのテストを行う
#   - 日付関係のテスト
#   - 引数(@ARGV)のテスト
#
# - config-hww.txtにHWWrapperの設定を書く
#   - フォーマットは拡張子によって決まる。ymlだったらYAML。txtだったらconfig.txtと同じような形式。(YAML::XSとYAMLは互換性がないらしい。XSを使うのはWindowsにとって厳しいのでYAMLモジュールを使う)
#   - $EDITORの設定
#   - hww.plに常に付ける引数(.provercや.ctagsみたいな感じ)
#   - コマンド名をミスった場合に空気呼んで似てるコマンドを呼び出すか訊く設定 (zshのcorrectみたいに)
#   - パスワードを入力中、端末に表示するかしないか
#   - 補完関数の細かな挙動 (隠しファイルを補完するかなど)
#
# - $self->{config}のそれぞれのキーについて、設定ファイルで変更可能にする


# NOTE
# - new()で設定のデフォルト値をセットして
# - load_config()で設定ファイルの値をセットして
# - parse_opt()で引数の値をセット
#
# croakはモジュールの扱い方に問題があった場合にのみ使われる



use strict;
use warnings;
use utf8;

our $VERSION = '1.7.14';

use base qw(HW HWWrapper::Commands);

# import builtin func's hooks
use HWWrapper::Hook::BuiltinFunc;
# import all util commands!!
use HWWrapper::Functions;


use Carp;
use File::Basename qw(basename);
use Scalar::Util qw(blessed);
use IO::String;







# bless you.
sub new {
    my $pkg = shift;
    if (blessed $pkg) {
        croak "you have already been initialized!";
    }

    my $self = bless { @_ }, $pkg;


    # set members
    $self->{config} = {
        # use cookie. (default)
        no_cookie => 0,

        is_debug_stderr => 0,
        is_debug => 0,
    };
    $self->{arg_opt}{HWWrapper} = {
        d => \$self->{config}{is_debug},
        debug => \$self->{config}{is_debug},

        D => \$self->{config}{is_debug_stderr},
        'debug-stderr' => \$self->{config}{is_debug_stderr},

        C => \$self->{config}{no_cookie},
        'no-cookie' => \$self->{config}{no_cookie},
    };
    $self->{debug_fh} = IO::String->new;


    # initialize config of HW.
    $self->SUPER::new;
}



# load hww config file(default to 'config-hww.txt') here.
# loading hw config file(default to 'config.txt') will be done
# at HW::load_config().
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



# separate options into hww.pl's options and hw.pl's options.
# (like git)
sub split_opt {
    my $self = shift;
    my @hww_opt;
    my $subcmd;
    my @tmp_argv = @_;

    while (defined(my $a = shift)) {
        if ($a =~ /^-/) {
            push @hww_opt, $a;
        }
        else {
            $subcmd = $a;    # found command
            last;
        }
    }

    my @ret = (\@hww_opt, $subcmd, [@_]);
    $self->debug(sprintf "%s -> (%s, %s, %s)\n",
                    dumper(\@tmp_argv),
                    dumper($ret[0]),
                    dumper($ret[1]),
                    dumper($ret[2]));

    # set to $self->{args}{options, command, command_args}.
    @{ $self->{args} }{qw(options command command_args)} = @ret;

    return @ret;
}



# parsing @ARGV which was received at dispatch_with_args().
sub parse_opt {
    my $self = shift;
    unless (blessed $self) {
        croak 'give me blessed $self.';
    }
    unless (exists $self->{args}) {
        croak "you did not passed 'args' option to HWWrapper->new().";
    }

    my $cmd      = $self->{args}{command};
    my $cmd_args = $self->{args}{command_args};

    # return ($cmd, $cmd_args) unless @$options;


    # parse hww.pl's options.
    $self->get_opt_only(    # do get_opt_only() for HW(SUPER::parse_opt()).
        $self->{args}{options},
        $self->{arg_opt}{HWWrapper}
    ) or do {
        $self->warning("arguments error");
        sleep 1;
        $self->dispatch('help');
        exit -1;
    };


    # option arguments result handling
    if ($self->is_debug) {
        print ${ $self->{debug_fh}->string_ref };    # flush all
        $self->{debug_fh} = *STDOUT;
    }
    elsif ($self->is_debug_stderr) {
        $self->warning(${ $self->{debug_fh}->string_ref });    # flush all
        $self->{debug_fh} = *STDERR;
    }
    else {
        $self->{debug_fh} = FileHandle->new(File::Spec->devnull, 'w') or $self->error("Can't open null device.");
    }

    $self->is_debug = 1 if $self->is_debug_stderr;

    # parse HW 's options.
    $self->SUPER::parse_opt();


    return ($cmd, $cmd_args);
}



sub validate_prereq_files {
    my $self = shift;

    for my $file (qw(touch_file config_file txt_dir)) {
        unless (-e $self->$file) {
            $self->error(
                $self->$file.": $!\n\n" .
                "not found prereq files. please run 'perl hww.pl init'."
            );
        }
    }
}



# dispatch command.
# commands are defined in HWWrapper::Commands.
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



# starts from this sub.
# but it's easy to build custom process about hww without using this.
sub dispatch_with_args {
    my $self = shift;
    my @args = @_;

    unless (blessed($self)) {
        croak 'give me blessed $self.';
    }


    # split arguments.
    my ($opts, $cmd, $cmd_args) = $self->split_opt(@args);
    $cmd = 'help' unless defined $cmd;

    unless (is_hww_command($cmd)) {
        $self->error("'$cmd' is not a hww-command. See perl hww.pl help");
    }

    # load config files.
    $self->load_config;

    # parse '$self->{args}{options}' (same as $opts).
    $self->parse_opt();

    unless ($cmd =~ /^ (help | version | copyright | init) $/x) {
        # check if prereq files exist.
        $self->validate_prereq_files();
    }

    # dispatch command.
    $self->dispatch($cmd, $cmd_args);
}



1;
