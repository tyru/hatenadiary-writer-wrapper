package HWW::UtilSub;

use strict;
use warnings;

use base qw(Exporter);

# export all subroutine.
our @EXPORT = do {
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




### util subs ###

sub warning {
    if ($hww_main::debug) {
        my ($filename, $line) = (caller)[1, 2];
        warn "warning: at $filename line $line:", @_, "\n";
    } else {
        warn "warning: ", @_, "\n";
    }
}

sub error {
    if ($hww_main::debug) {
        my ($filename, $line) = (caller)[1, 2];
        die "error: at $filename line $line:", @_, "\n";
    } else {
        die "error: ", @_, "\n";
    }
}

sub debug {
    warn "debug: ", @_, "\n" if $hww_main::debug;
}

sub dumper {
    debug(Data::Dumper::Dumper(@_));
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

sub alias {
    my ($type, $to, $from) = @_;
    no strict 'refs';
    if (defined *{$from}{$type}) {
        *$to = *{$from}{$type};
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
}

sub get_entrydate {
    my $path = shift;

    if (File::Basename::basename($path) =~ /\A(\d{4})-(\d{2})-(\d{2})(-.+)?\.txt\Z/) {
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
    my $dir = defined $_[0] ? shift : $hw_main::txt_dir;
    grep {
        -e $_ && -f $_
    } grep {
        defined get_entrydate($_)
    } glob "$dir/*.txt"
}

# get misc time from 'touch.txt'.
# NOTE: this sub is not used
sub get_touchdate {
    my $touch_time = do {
        my $FH = FileHandle->new($hw_main::touch_file, 'r') or error(":$!");
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



### util subs (need $self) ###

sub arg_error {
    my $self = shift;
    my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
    debug("arg_error: called at $filename line $line");

    my %rev_dict = reverse %hww_main::HWW_COMMAND;
    my $cmdname = $rev_dict{$subname};

    eval {
        error("$cmdname: arguments error. show ${cmdname}'s help...");
    };

    $self->dispatch('help', [$cmdname]);
}



1;
