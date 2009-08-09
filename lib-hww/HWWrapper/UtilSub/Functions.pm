package HWWrapper::UtilSub::Functions;

use strict;
use warnings;
use utf8;

our $VERSION = "1.0.5";

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
    $DEBUG
);


# do not export methods unnecessarily!
use Data::Dumper ();
use File::Basename ();
use IO::String;


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
# for debug :)
# sub debug {
#     my $subname = (caller 1)[3];
#     print "debug: $subname(): ", @_, "\n";
# }

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



1;
