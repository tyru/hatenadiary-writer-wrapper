package HWWrapper::UtilSub;

use strict;
use warnings;
use utf8;

use base qw(Exporter);
use subs qw(dump);

our @EXPORT = our @EXPORT_OK = qw(
    warning
    error
    debug
    dump
    dumper
    puts
    is_hww_command
    alias
    require_modules
    split_opt
    restore_hw_args
);


# do not export methods unnecessarily!
use Data::Dumper ();

use File::Spec ();
use File::Basename ();
use FileHandle ();
use POSIX ();
use Getopt::Long ();
use Carp ();



### util subs ###

sub warning {
    if ($HWWrapper::debug) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = File::Basename::basename($filename);
        $subname = defined $subname ? " $subname:" : "";
        warn "warning:$subname at $filename line $line:", @_, "\n";
    } else {
        warn "warning: ", @_, "\n";
    }
}

sub error {
    my @errmsg;

    if ($HWWrapper::debug) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = File::Basename::basename($filename);
        $subname = defined $subname ? " $subname:" : "";
        @errmsg = ("error:$subname at $filename line $line:", @_, "\n");
    } else {
        @errmsg = ("error: ", @_, "\n");
    }

    unlink($HW::cookie_file);    # from HW::error_exit()

    die @errmsg;
}

sub debug {
    my $subname = (caller 1)[3];
    $subname = defined $subname ? "$subname(): " : '';

    if ($HWWrapper::debug_stderr) {
        warn "debug: $subname", @_, "\n";
    } elsif ($HWWrapper::debug) {
        print "debug: $subname", @_, "\n";
    }
}

sub dump {
    debug(dumper(@_));
}
*CORE::GLOBAL::dump = \&dump;

sub dumper {
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse = 1;
    Data::Dumper::Dumper(@_);
}

# not 'say'.
# but print with newline.
sub puts {
    print @_, "\n";
}

sub is_hww_command {
    my $cmd = shift;
    exists $HWWrapper::HWW_COMMAND{$cmd};
}

# NOTE: unused
sub alias {
    my $pkg = caller;
    my ($type, $to, $from) = @_;

    no strict 'refs';
    if (defined *{$from}{$type}) {
        *{"${pkg}::$to"} = *{$from}{$type};
        debug("imported $from of $type to ${pkg}::$to");
    } else {
        warning("not found reference $from of $type");
    }
}

sub require_modules {
    my @failed;

    for my $m (@_) {
        eval "require $m";
        if ($@) {
            push @failed, $m;
        }
    }

    if (@failed) {
        my $failed = join ', ', @failed;
        error("you need to install $failed.");
    }

    debug("required ".join(', ', @_));
}

# separate options into hww.pl's options and hw.pl's options.
# (like git)
sub split_opt {
    my @hww_opt;
    my $subcmd;

    while (defined(my $a = shift)) {
        if ($a =~ /^-/) {
            push @hww_opt, $a;
        } else {
            $subcmd = $a;    # found command
            last;
        }
    }

    return (\@hww_opt, $subcmd, [@_]);
}

# for hw.pl (now lib-hww/HW.pm)
sub restore_hw_args {
    my %opt = @_;
    my @argv;

    while (my ($k, $v) = each %opt) {
        # deref.
        $v = $$v;
        # option was not given.
        next    unless $v;

        if ($k =~ s/(.*)=s$/$1/) {
            debug("hw's option -$k => $v");
            push @argv, "-$k", $v;
        } else {
            debug("hw's option -$k");
            push @argv, "-$k";
        }
    }

    return @argv;
}





# TODO separate into HWWrapper::UtilSub::Functions
### util subs (need $self) ###

sub get_entrydate {
    my $self = shift;
    my $path = shift;
    $path = File::Basename::basename($path);

    # $path might be html file.
    if ($path =~ /\A(\d{4})-(\d{2})-(\d{2})(-[\w\W]+)?\.(html|txt)\Z/m) {
        return {
            year  => $1,
            month => $2,
            day   => $3,
            rest  => $4,
        };
    } else {
        return undef;
    }
}

sub find_headlines {
    my $self = shift;
    my ($body) = @_;
    my @headline;

    # NOTE: all headlines are replaced with ' '.
    # because '*headlines**not headlines*' are allowed
    # if headlines were replaced with ''.
    while ($body =~ s/^\*([^\n\*]+)\*/ /m) {
        push @headline, $1;
    }
    return @headline;
}

sub get_entries {
    my $self = shift;
    my ($dir, $fileglob) = @_;

    # set default value.
    $dir      = $HW::txt_dir unless defined $dir;
    $fileglob = '*.txt'           unless defined $fileglob;

    grep {
        -e $_ && -f _
    } grep {
        defined get_entrydate($_)
    } glob "$dir/$fileglob"
}

sub get_entries_hash {
    my $self = shift;
    my @entries = get_entries(@_);
    my %hash;
    for my $date (map { get_entrydate($_) } @entries) {
        my $ymd = join '-', @$date{qw(year month day)};
        $hash{$ymd} = $date;
    }
    %hash;
}

sub get_updated_entries {
    my $self = shift;

    grep {
        (-e $_ && -e $HW::touch_file)
        && -M $_ < -M $HW::touch_file
    } get_entries(@_);
}


# get misc info about time from 'touch.txt'.
# NOTE: unused
sub get_touchdate {
    my $self = shift;

    my $touch_time = do {
        my $FH = FileHandle->new($HW::touch_file, 'r') or error(":$!");
        chomp(my $line = <$FH>);
        $FH->close;

        $line;
    };
    unless ($touch_time =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
        error("touch.txt: bad format");
    }
    return {
        year => $1,
        month => $2,
        day => $3,
        hour => $4,
        min => $5,
        sec => $6,
        epoch => POSIX::mktime($6, $5, $4, $3, $2-1, $1-1900),
    };
}

{
    # gnu_compat: --opt="..." is allowed.
    # no_bundling: single character option is not bundled.
    # no_auto_abbrev: single character option is not bundled.(which?)
    # no_ignore_case: no ignore case on long option.
    my $parser = Getopt::Long::Parser->new(
        config => [qw(
            gnu_compat
            no_bundling
            no_auto_abbrev
            no_ignore_case
        )]
    );

    sub get_opt {
        my $self = shift;
        my ($argv, $opt) = @_;

        local @ARGV = @$argv;
        my $result = $parser->getoptions(%$opt);

        if ($HWWrapper::debug) {
            debug("true value options:");
            for (grep { ${ $opt->{$_} } } keys %$opt) {
                debug(sprintf "  [%s]:[%s]",
                                $_, ${ $opt->{$_} });
            }
        }

        # update arguments. delete all processed options.
        @$argv = @ARGV;
        return $result;
    }
}

# or not, run 'init' command.
sub has_completed_setup {
    my $self = shift;

    -d $HW::txt_dir &&
    -f $self->config_file;
}

sub arg_error {
    my $self = shift;
    my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
    $filename = File::Basename::basename($filename);
    debug("arg_error: called at $filename line $line");

    $subname =~ s/.*:://;    # delete package's name
    my %rev_dict = reverse %HWWrapper::HWW_COMMAND;
    my $cmdname = $rev_dict{$subname};

    unless (defined $cmdname) {
        # internal error (my mistake...)
        error("can't find ${subname}'s command name");
    }

    # no need to localize $@ though
    # because we are going to die :-)
    local $@;
    eval {
        error("$cmdname: arguments error. show ${cmdname}'s help...");
    };
    warn $@;
    STDERR->flush;

    if ($HWWrapper::debug) {
        print "press enter to continue...";
        <STDIN>;
    } else {
        sleep 1;
    }
    $self->dispatch('help', [$cmdname]);

    # from HW::error_exit()
    unlink($HW::cookie_file);

    exit -1;
}




1;
