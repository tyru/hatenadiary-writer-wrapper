package HWWrapper::Hook::BuiltinOp;

use strict;
use warnings;
use utf8;

our $VERSION = '1.0.0';

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(
    dump
    exit
);





our $dump = sub {
    @_ = (HWWrapper::Functions::dumper(@_));
    goto &HWWrapper::Functions::debug;
};
sub dump { goto &$dump }
# *CORE::GLOBAL::dump = $dump;


our $exit = sub ($) {
    # default
    CORE::exit @_;
};
sub exit (;$) { goto &$exit }
# *CORE::GLOBAL::exit = $exit;

1;
