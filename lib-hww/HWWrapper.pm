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
#   - hww.plに常に付ける引数(.provercや.ctagsみたいな感じ)
#   - コマンド名をミスった場合に空気呼んで似てるコマンドを呼び出すか訊く設定 (zshのcorrectみたいに)
#   - パスワードを入力中、端末に表示するかしないか
#   - 補完関数の細かな挙動 (隠しファイルを補完するかなど)


# NOTE
# - new()で設定のデフォルト値をセットして
# - load_config()で設定ファイルの値をセットして
# - parse_opt()で引数の値をセット
#
# croakはモジュールの扱い方に問題があった場合にのみ使われる



use strict;
use warnings;
use utf8;

our $VERSION = '1.9.0';

use base qw(HW);

# import all util commands!!
use HWWrapper::Functions;


use Carp qw(croak);
use IO::String;
use Fcntl qw(:mode);







# bless you.
sub new {
    my $pkg = shift;
    if (blessed $pkg) {
        croak "you have already been initialized!";
    }

    my $self = bless { @_ }, $pkg;


    # config
    $self->{config} = {
        # use cookie. (default)
        no_cookie => 0,

        is_debug_stderr => 0,
        is_debug => 0,

        config_hww_file => 'config-hww.txt',

        # hw compatible settings.
        # this value is not used.
        # but HWWrapper::load_config() look at this.
        hw => {},

        editor => $ENV{EDITOR},
        alias => {
            update => 'release -t',
        },
        no_load_config_hww => 0,
        login_retry_num => 2,
    };

    # login_retry_count
    $self->{login_retry_count} = 0;

    # hw_comp_config
    $self->{hw_comp_config} = {
        id => 'username',
        g => 'groupname',
        password => 'password',
        cookie => 'cookie_file',
        proxy => 'http_proxy',
        client_encoding => 'client_encoding',
        server_encoding => 'server_encoding',
        filter => 'filter_command',
        txt_dir => 'txt_dir',
        touch => 'touch_file',
    };

    # arg_opt
    my %arg_opt = (
        'd|debug' => \$self->{config}{is_debug},
        'D|debug-stderr' => \$self->{config}{is_debug_stderr},
        'C|no-cookie' => \$self->{config}{no_cookie},
        'N|config-hww=s' => \$self->{config}{config_hww_file},
        'no-load-hww' => \$self->{config}{no_load_config_hww},
    );
    while (my ($k, $v) = each %arg_opt) {
        $self->{arg_opt}{$k} = $v;
    }

    # debug_fh
    $self->{debug_fh} = IO::String->new;


    # initialize config of HW.
    $self->SUPER::new;
}



# load hww config file(default to 'config-hww.txt') here.
# loading hw config file(default to 'config.txt') will be done
# at HW::load_config().
sub load_config {
    my $self = shift;

    if ($self->no_load_config_hww) {
        $self->debug("'--no-load-hww' was given...skip");
        return;
    }
    else {
        if (-f $self->config_hww_file) {
            $self->__load_config($self->config_hww_file);
        } else {
            $self->debug($self->config_hww_file." is not found. skip to load config...");
        }
    }

    # read config.txt.
    $self->SUPER::load_config;
}

sub __load_config {
    my ($self, $config) = @_;

    my $FH = FileHandle->new($config)
                or $self->error("$config: $!");

    while (<$FH>) {
        next if /^#/ or /^\s*$/;
        chomp;

        $self->debug($FH->input_line_number.': '.$_);

        if (/^ ([^:]+) : \s* (.*) $/x) {    # match!
            if (strcount($1, '.') > 1) {
                $self->error("too many dots: allowed only one dot.");
            }

            my ($k, $v) = ($1, $2);

            my $kk;
            ($k, $kk) = split /\./, $k;

            unless (exists $self->{config}{$k}) {
                $self->error("$k: no such key config value");
            }

            if (defined $kk) {
                # $1 contains dot.
                unless (ref $self->{config}{$k} eq 'HASH') {
                    # die if not hash
                    $self->error("$k.$kk: invalid type");
                }

                if ($k eq 'hw') {
                    # hw compatible settings.
                    unless (exists $self->{hw_comp_config}{$kk}) {
                        $self->error("$k: no such key config value");
                    }
                    $self->{config}{ $self->{hw_comp_config}{$kk} } = $v;
                } else {
                    $self->{config}{$k}{$kk} = $v;
                }
            }
            else {
                # $1 does not contain dot.
                unless (not ref $self->{config}{$k}) {
                    # die if not scalar
                    $self->error("$k: invalid type");
                }
                $self->{config}{$k} = $v;
            }
        }
        else {
            $self->error(sprintf "%s: %d: invalid format",
                            $config, $FH->input_line_number);
        }
    }

    $FH->close;
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

    return ($cmd, $cmd_args) unless @{ $self->{args}{options} };


    # get hww.pl and hw.pl options.
    $self->get_opt(
        $self->{args}{options},
        $self->{arg_opt}
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


    # change hw option settings like above.
    $self->SUPER::parse_opt();

    return ($cmd, $cmd_args);
}



sub validate_prereq_files {
    my $self = shift;

    # these files must exist.
    for my $file (qw(config_file txt_dir)) {
        unless (-e $self->$file) {
            $self->error(
                $self->$file.": $!\n\n" .
                "not found prereq files. please run 'perl hww.pl init'."
            );
        }
    }

    # check permissions.
    for my $file (qw(cookie_file config_file config_hww_file)) {
        next unless -f $self->$file;
        my $mode = (stat $self->$file)[2];
        if (($mode & S_IRWXG) || ($mode & S_IRWXO)) {
            my $fmt = "%s: permission %o is too open. please run 'init' command.";
            $self->warning(sprintf $fmt, $self->$file, S_IMODE($mode));
        }
    }
}



# dispatch command.
# commands are defined in HWWrapper::Commands.
sub dispatch {
    my $self = shift;
    my ($cmd, $args) = @_;
    $args = [] unless defined $args;

    # detect some errors.
    unless (blessed $self) {
        croak 'give me blessed $self.';
    }
    unless (defined $cmd) {
        $self->error("no command was given.");
    }


    # if $cmd is alias, get real args.
    ($cmd, @$args) = ($self->expand_alias($cmd), @$args);

    # some debug messages.
    if ($self->is_debug) {
        my ($filename, $line) = (caller)[1,2];
        $filename = basename($filename);
        $self->debug(sprintf '$self->dispatch(%s) at %s line %s',
                join(', ', map { dumper($_) } @_), $filename, $line);
    }

    # require package if not loaded
    my $cmd_info = HWWrapper::Commands->get_command($cmd);
    unless (defined $cmd_info) {
        $self->error("'$cmd' is not a hww command.");
    }

    # get arguments value
    my %opt;
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
sub dispatch_with_args {
    my $self = shift;
    my @args = @_;

    unless (blessed($self)) {
        croak 'give me blessed $self.';
    }


    # split arguments.
    my ($opts, $cmd, $cmd_args) = $self->split_opt(@args);
    $cmd = 'help' unless defined $cmd;

    # load config files.
    $self->load_config();

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
