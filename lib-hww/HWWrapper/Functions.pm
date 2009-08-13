package HWWrapper::Functions;

use strict;
use warnings;
use utf8;

our $VERSION = "1.0.16";

# import builtin op's hooks
# (these ops are hooked in HWWrapper::Commands::shell())
#
# and this package also exports these ops.
use HWWrapper::Hook::BuiltinFunc;


use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = do {
    no strict 'refs';

    my @codes = grep { *$_{CODE} } keys %{__PACKAGE__.'::'};
    # export all subroutines and $DEBUG.
    (@codes, qw($DEBUG), @HWWrapper::Hook::BuiltinFunc::EXPORT);
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
    exists $HWWrapper::Commands::HWW_COMMAND{$cmd};
}

# NOTE: unused
sub alias {
    my $pkg = caller;
    my ($to, $from_ref) = @_;

    if (ref $from_ref) {
        no strict 'refs';
        *{"${pkg}::$to"} = $from_ref;
    }
    else {
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
sub shell_eval_str {
    my $line = shift;
    my @args;

    if ($line =~ /\n/m) {
        Carp::croak "give me the string line which does NOT contain newline!";
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


    while (length $line) {
        next if $line =~ s/^ \s+//x;

        if ($line =~ /^"/) {    # double quotes
            my $evaluated = get_quote_str($line, begin => q("), end => q("), eval => 1);
            $line = $evaluated->{rest_str};
            $push_args->($evaluated->{body});
        }
        elsif ($line =~ /^'/) {    # single quotes
            my $got = get_quote_str($line, begin => q('), end => q('));
            $line = $got->{rest_str};
            $push_args->($got->{body});    # push body
        }
        elsif ($line =~ s/^ (\S+)//mx) {    # literal WORD
            # evaluate it.
            $line = (sprintf q("%s"), $1).$line;
        }
        else {    # wtf?
            error("parse error");
        }
    }

    return @args;
}

sub is_complete_str {
    my $line = shift;

    eval {
        shell_eval_str($line)
    };

    if ($@ =~ /unexpected end of string while looking for/) {
        return 0;
    }
    else {
        return 1;
    }
}

sub get_quote_str {
    my $line = shift;
    my %opt = (
        eval => 0,
        @_
    );
    unless (exists $opt{begin} && exists $opt{end}) {
        Carp::croak "give me options 'begin' and 'end' at least!";
    }

    my ($lquote, $rquote) = @opt{qw(begin end)};
    unless ($line =~ s/^$lquote//) {
        Carp::croak "regex '^$lquote' does not matched to ".dumper($line);
    }

    my $shift_str = sub {
        return undef if length $_[0] == 0;
        my $c = substr $_[0], 0, 1;    # first char
        $_[0] = substr $_[0], 1;       # rest
        return $c;
    };
    my $body = '';
    my $completed;


    while (length $line) {
        my $c = $shift_str->($line);

        if ($c eq $rquote) {    # end of string
            $completed = 1;
            last;
        }
        elsif ($c eq "\\") {    # escape
            if ($opt{eval}) {
                my $ch = $shift_str->($line);
                # unexpected end of string ...
                last unless defined $ch;

                $c = "\\".$ch;
                $body .= eval sprintf q("%s"), $c;
            }
            else {
                $body .= $c;
            }
        }
        else {
            $body .= $c;
        }
    }

    unless ($completed) {
        error("unexpected end of string while looking for $rquote");
    }

    return {
        body => $body,
        rest_str => $line,
    };
}



1;
