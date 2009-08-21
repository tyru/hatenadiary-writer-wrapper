package HWWrapper::Hook::BuiltinFunc;

use strict;
use warnings;
use utf8;

our $VERSION = '1.0.6';

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(
    dump
    exit
);


use HWWrapper::Functions;

use Carp;
use Scalar::Util qw(blessed);


# NOTE:
# do NOT taint CORE::GLOBAL.
# also CPAN module's builtin func was destroyed!




our $dump = sub {
    my $self = shift;
    unless (blessed $self) {
        croak 'give me blessed $self';
    }

    $self->debug(
        HWWrapper::Functions::dumper(@_)
    );
};
sub dump { goto &$dump }


our $exit = sub (;$) {
    # default
    CORE::exit @_;
};
sub exit (;$) { goto &$exit }





1;
