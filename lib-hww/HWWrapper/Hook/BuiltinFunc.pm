package HWWrapper::Hook::BuiltinFunc;

use strict;
use warnings;
use utf8;

our $VERSION = '1.0.1';

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(
    dump
    exit
    sub
);

use Scalar::Util qw(set_prototype);

# do NOT taint CORE::GLOBAL.
# also CPAN module's builtin func was destroyed!



our $dump = CORE::sub {
    @_ = (HWWrapper::Functions::dumper(@_));
    goto &HWWrapper::Functions::debug;
};
CORE::sub dump { goto &$dump }


our $exit = CORE::sub ($) {
    # default
    CORE::exit @_;
};
CORE::sub exit (;$) { goto &$exit }


our $sub = CORE::sub (&;$) {
    my $realsub = shift;
    my $subname = @_ ? shift : '';

    my $coderef = CORE::sub {
        local *__ANON__ = "__ANON__$subname";
        $realsub->(@_);
    };
    set_prototype(\&$coderef, prototype $realsub);

    return $coderef;
};
CORE::sub sub (&) { goto &$sub }



1;
