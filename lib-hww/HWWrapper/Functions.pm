package HWWrapper::Functions;

use strict;
use warnings;
use utf8;

# import builtin func's hooks
use HWWrapper::Hook::BuiltinFunc;

# import some util func
use File::Basename qw(fileparse dirname basename);
use Scalar::Util qw(blessed);



use base qw(Exporter);

# export all subroutines!!
our @EXPORT = our @EXPORT_OK = do {
    no strict 'refs';

    my @codes = grep { *$_{CODE} } keys %{__PACKAGE__.'::'};
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

sub strcount {
    my ($str, $substr) = @_;
    my $count = 0;
    my $pos = 0;

    until ((my $tmp = index($str, $substr, $pos)) == -1) {
        $pos = $tmp + 1;    # next pos
        $count++;
    }

    return $count;
}


1;
