package HWW::UtilSub;

use strict;
use warnings;
use utf8;

use base qw(Exporter);

# export all subroutine.
our @EXPORT = our @EXPORT_OK = do {
    no strict 'refs';
    my @subname = grep { *$_{CODE} } keys %HWW::UtilSub::;
    debug("exporting ".join(', ', @subname));
    @subname;
};


# do not export methods unnecessarily!
use Data::Dumper ();

use File::Spec ();
use File::Basename ();
use FileHandle ();
use POSIX ();
use Getopt::Long ();




### util subs ###

sub warning {
    my $subname = (caller 1)[3];
    $subname = defined $subname ? " $subname:" : "";

    if ($hww_main::debug) {
        my ($filename, $line) = (caller)[1, 2];
        $filename = File::Basename::basename($filename);
        warn "warning:$subname at $filename line $line:", @_, "\n";
    } else {
        warn "warning:$subname ", @_, "\n";
    }
}

sub error {
    my $subname = (caller 1)[3];
    $subname = defined $subname ? " $subname:" : "";

    if ($hww_main::debug) {
        my ($filename, $line) = (caller)[1, 2];
        $filename = File::Basename::basename($filename);
        die "error:$subname at $filename line $line:", @_, "\n";
    } else {
        die "error:$subname ", @_, "\n";
    }

    # from HW::error_exit()
    unlink($HW::cookie_file);
}

sub debug {
    my $subname = (caller 1)[3];
    $subname = defined $subname ? "$subname(): " : '';
    if ($hww_main::debug_stderr) {
        warn "debug: $subname", @_, "\n";
    } elsif ($hww_main::debug) {
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
    exists $HWW::HWW_COMMAND{$cmd};
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

sub call_hw {
    my $hw = File::Spec->catfile($hww_main::BASE_DIR, 'hw.pl');
    my @debug = $hww_main::debug ? qw(-d) : ();
    my @cookie = $hww_main::no_cookie ? () : qw(-c);

    system 'perl', $hw, @debug, @cookie, @_;
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

sub get_entrydate {
    my $path = shift;

    # $path might be html file.
    if (File::Basename::basename($path) =~ /\A(\d{4})-(\d{2})-(\d{2})(-.+)?\.(html|txt)\Z/) {
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
    my ($body) = @_;
    my @headline;
    while ($body =~ s/^\*([^\n\*]+)\*//m) {
        push @headline, $1;
    }
    return @headline;
}

sub get_entries {
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
    my @entries = get_entries(@_);
    my %hash;
    for my $date (map { get_entrydate($_) } @entries) {
        my $ymd = join '-', @$date{qw(year month day)};
        $hash{$ymd} = $date;
    }
    %hash;
}

# get misc info about time from 'touch.txt'.
# NOTE: unused
sub get_touchdate {
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
        my ($argv, $opt) = @_;

        debug('$opt = '.dumper($opt));
        debug('before: $argv = '.dumper($argv));

        local @ARGV = @$argv;
        my $result = $parser->getoptions(%$opt);
        # my $result = GetOptions(%$opt);

        # update arguments. delete all processed options.
        @$argv = @ARGV;
        debug('after: $argv = '.dumper($argv));

        return $result;
    }
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



### util subs (need $self) ###

sub arg_error {
    my $self = shift;
    my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
    $filename = File::Basename::basename($filename);
    debug("arg_error: called at $filename line $line");

    $subname =~ s/.*:://;    # delete package's name
    my %rev_dict = reverse %HWW::HWW_COMMAND;
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

    if ($hww_main::debug) {
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
