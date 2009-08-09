package HWWrapper::UtilSub::Functions;

use strict;
use warnings;
use utf8;

our $VERSION = "1.0.7";

use subs qw(dump);

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = do {
    no strict 'refs';

    my @codes = grep { *$_{CODE} } keys %HWWrapper::UtilSub::Functions::;
    # export all subroutines and $DEBUG.
    (@codes, qw($DEBUG));
};


# do not export methods unnecessarily!
use Data::Dumper ();
use File::Basename ();
use IO::String ();
use Carp ();


our $DEBUG = IO::String->new;



### util subs ###

sub warning {
    if ($HWWrapper::debug) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = File::Basename::basename($filename);
        warn "warning: $subname()  at $filename line $line:", @_, "\n";
    }
    else {
        warn "warning: ", @_, "\n";
    }
}

sub error {
    my @errmsg;

    if ($HWWrapper::debug) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = File::Basename::basename($filename);
        @errmsg = ("error: $subname() at $filename line $line:", @_, "\n");
    }
    else {
        @errmsg = ("error: ", @_, "\n");
    }

    # unlink($HW::cookie_file);    # from HW::error_exit()

    die @errmsg;
}

sub debug {
    my $subname = (caller 1)[3];
    $DEBUG->print("debug: $subname(): ", @_, "\n");
}

sub dump {
    @_ = (dumper(@_));
    goto &debug;
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
    my ($to, $from_ref) = @_;

    if (ref $from_ref) {
        no strict 'refs';
        *{"${pkg}::$to"} = $from_ref;
    } else {
        warning("$from_ref is not reference");
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
    debug(sprintf "%s -> (%s, %s, %s)\n",
                    dumper(\@tmp_argv),
                    dumper($ret[0]),
                    dumper($ret[1]),
                    dumper($ret[2]));

    return @ret;
}

# TODO
# - if text's end is backslash, read nextline.
#
# - pipe
# - runnning background
#
# NOTE:
# pass "complete command line string".
# DON'T pass incomplete string. e.g.: "right double quote missing
sub shell_eval_string {
    my $line = shift;
    my @args;

    if ($line =~ /\n/m) {
        Carp::croak "give me the line which does NOT contain newline!";
    }

    my $push_args = sub {
        Carp::croak "push_args: receive empty args" unless @_;

        if (@args) {
            push @{ $args[-1] }, @_;
        }
        else {
            push @args, [@_];
        }
    };
    my $shift_str = sub {
        my $c = substr $_[0], 0, 1;    # first char
        $_[0] = substr $_[0], 1;       # rest
        return $c;
    };


    while (length $line) {
        next if $line =~ s/^ \s+//x;

        if ($line =~ s/^"//) {    # double quotes
            my $body = '';

            while (length $line) {
                my $c = $shift_str->($line);

                if ($c eq q(")) {    # end of string
                    last;
                }
                elsif ($c eq "\\") {    # escape
                    $c = "\\" . $shift_str->($line);
                    $body .= eval sprintf q("%s"), $c;
                }
                else {
                    $body .= $c;
                }
            }

            $push_args->($body);
        }
        elsif ($line =~ s/^ (') ([^\1]*?) \1//x) {    # single quotes
            $push_args->($2);    # push body
        }
        elsif ($line =~ s/^ (\S+)//mx) {    # WORD
            # wrap it with double quotes.
            $line = (sprintf q("%s"), $1).$line;
        }
        else {    # wtf?
            error("parse error");
        }
    }

    return @args;
}



1;
