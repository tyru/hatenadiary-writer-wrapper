package HWWrapper::Commands::Touch;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{touch} = {
        coderef => \&run,
        desc => "update 'touch.txt'",
    };
}


sub run {
    my ($self, $args) = @_;

    my $filename = File::Spec->catfile($self->txt_dir, 'touch.txt');
    my $FH = FileHandle->new($filename, 'w') or $self->error("$filename:$!");
    # NOTE: I assume that this format is compatible
    # between Date::Manip::UnixDate and POSIX::strftime.
    my $touch_fmt = '%Y%m%d%H%M%S';

    if (@$args) {
        $self->require_modules(qw(Date::Manip));
        Date::Manip->import(qw(ParseDate UnixDate));
        # NOTE: this parser is not compatible with 'rake touch <string>'.
        $FH->print(UnixDate(ParseDate(shift @$args), $touch_fmt));
    }
    else {
        $FH->print(POSIX::strftime($touch_fmt, localtime));
    }

    $FH->close;
}


1;
