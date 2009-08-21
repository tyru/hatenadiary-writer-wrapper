package HWWrapper::Functions;

use strict;
use warnings;
use utf8;

our $VERSION = "1.3.0";

# import builtin func's hooks
use HWWrapper::Hook::BuiltinFunc;


use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = do {
    no strict 'refs';

    my @codes = grep { *$_{CODE} } keys %{__PACKAGE__.'::'};
    # export all subroutines.
    (@codes, @HWWrapper::Hook::BuiltinFunc::EXPORT);
};


# do not export methods unnecessarily!
use Data::Dumper ();



### util subs (don't need $self) ###

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


1;
