package HWWrapper::Hook::BuiltinFunc;

use strict;
use warnings;
use utf8;

our $VERSION = '1.0.1';

use base qw(Exporter);

our @EXPORT;
our @EXPORT_OK;
BEGIN {
    @EXPORT = @EXPORT_OK = qw(
        dump
        exit
    );
}
use subs @EXPORT;


use HWWrapper::Functions;

use Scalar::Util qw(set_prototype);


# NOTE:
# do NOT taint CORE::GLOBAL.
# also CPAN module's builtin func was destroyed!




our $dump = sub {
    @_ = (HWWrapper::Functions::dumper(@_));
    goto &HWWrapper::Functions::debug;
};
alias 'dump' => $dump;


our $exit = sub ($) {
    # default
    CORE::exit @_;
};
alias 'exit' => $exit;





1;
