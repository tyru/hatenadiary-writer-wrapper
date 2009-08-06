package HWWrapper::UtilSub::Functions;

use strict;
use warnings;
use utf8;

use subs qw(dump);

use base qw(Exporter);

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
use File::Basename ();




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



1;
