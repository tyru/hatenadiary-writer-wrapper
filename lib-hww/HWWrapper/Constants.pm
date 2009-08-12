package HWWrapper::Constants;

use strict;
use warnings;
use utf8;

our $VERSION = "1.0.0";

use base qw(Exporter);

our @EXPORT_OK = qw(
    $BASE_DIR
    $HWW_LIB
);


our $BASE_DIR = File::Spec->rel2abs(
    File::Spec->catdir(File::Basename::dirname(__FILE__), '..', '..')
);
our $HWW_LIB = File::Spec->catfile($BASE_DIR, "lib-hww");




1;
