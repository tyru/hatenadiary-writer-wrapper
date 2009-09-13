package HWWrapper;

# NOTE
# 設定は次の順番で上書きされる。
#
# 1. デフォルト - new()
# 2. 設定ファイル - load_config()
# 3. 引数 - parse_opt()
#
# つまり引数からの値が一番優先順位が高い。



use strict;
use warnings;
use utf8;

our $VERSION = '2.0.5';

use base qw(HW);

# import all util commands!!
use HWWrapper::Functions;


# croakは引数がおかしい場合にのみ使われる
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
        is_debug_stderr => 0,
        is_debug => 0,

        config_hww_file => 'config-hww.txt',

        # hw compatible settings.
        # this value is not used.
        # but HWWrapper::load_config() looks at this.
        hw => {},

        editor => $ENV{EDITOR},
        alias => {
            update => 'release -t',
        },
        no_load_config_hww => 0,
        login_retry_num => 2,
        delete_cookie_if_error => 0,
        load_from_pit => 0,
        pit_domain => 'hatena.ne.jp',
        use_cookie => 0,
        dont_show_password => 0,
        prompt_str => '> ',
        prompt_next_line_str => '',
        group => {},
    };

    # current_group
    $self->{current_group} = '';
    # previous_group_stash
    #   this is stash for default group setting.
    $self->{previous_group_stash} = {};

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



# load hww config file(default to 'config-hww.txt').
sub load_config {
    my $self = shift;

    if ($self->no_load_config_hww) {
        $self->debug("'--no-load-hww' was given...skip");
        return;
    }
    else {
        if (-f $self->config_hww_file) {
            my $confname = $self->config_hww_file;
            my $FH = FileHandle->new($confname)
                        or $self->error("$confname: $!");

            while (<$FH>) {
                next if /^#/ or /^\s*$/;
                chomp;

                my $lnum = $FH->input_line_number;
                $self->debug("$lnum: $_");

                if (/^ ([^:]+) : (.*) $/x) {
                    eval {
                        $self->set_config($1, $2);
                    };
                    if ($@) {
                        chomp $@;
                        $self->warning($@);
                        $self->error(
                            "error occured at line $lnum while loading $confname: '$_'"
                        );
                    }
                } else {
                    $self->error("invalid format in $confname: '$_'");
                }
            }

            # hw compatible settings.
            my %hw = %{ $self->{config}{hw} };
            while (my ($k, $v) = each %hw) {
                unless (exists $self->{hw_comp_config}{$k}) {
                    $self->error("no such a hw key config value.");
                }
                $self->{config}{ $self->{hw_comp_config}{$k} } = $v;
            }

            $FH->close;
        } else {
            $self->debug($self->config_hww_file." is not found. skip to load config...");
        }
    }

    # read config.txt.
    $self->SUPER::load_config;
}

sub set_config {
    my ($self, $k, $v) = @_;
    $self->__set_config($self->{config}, [split /\./, $k], $v);
}

sub __set_config {
    my ($self, $config, $keys, $v) = @_;

    if (@$keys == 0) {
        return;
    }
    elsif (@$keys == 1) {
        my $k = shift @$keys;
        $config->{$k} = $v;
    }
    else {
        my $k = shift @$keys;

        if (exists $config->{$k}) {
            unless (ref $config->{$k} eq 'HASH') {
                $self->error("$k: invalid type");
            }
        }
        else {
            $config->{$k} = {};
        }

        $self->__set_config($config->{$k}, $keys, $v);
    }
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



# parsing @ARGV which was received at run().
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

    # load_from_pit, pit_domain
    if ($self->load_from_pit) {
        $self->require_modules('Config::Pit');
        my $config = Config::Pit::pit_get($self->pit_domain, 'require' => {
            username => 'your username on hatena',
            password => 'your password on hatena',
        });
        if (! exists $config->{username} || ! exists $config->{password}) {
            $self->error("can't get username and password from Config::Pit.");
        }
        $self->username = $config->{username};
        $self->password = $config->{password};
    }


    return ($cmd, $cmd_args);
}



# check permissions and make warnings if it is too open.
sub check_permission {
    my $self = shift;

    if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
        $self->debug("skip checking permissions: this is $^O environment.");
        return;
    }

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

    unless ($self->is_command($cmd)) {
        $self->error("'$cmd' is not a hww command.");
    }


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
        $self->debug($@);
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
sub run {
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

    # parse '$self->{args}{options}'.
    $self->parse_opt();

    unless ($cmd =~ /^ (help | version | copyright | init) $/x) {
        # check if permissions are too open.
        $self->check_permission();
    }

    # dispatch command.
    $self->dispatch($cmd, $cmd_args);
}



1;
