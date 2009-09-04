package HWWrapper::Commands::RevertHeadline;

use strict;
use warnings;
use utf8;

use base qw(HWWrapper::Commands::Base);

# export our variables.
use HWWrapper::Commands qw(%HWW_COMMAND);
# export sub who does not take $self.
use HWWrapper::Functions;




sub regist_command {
    $HWW_COMMAND{'revert-headline'} = {
        coderef => \&run,
        desc => "revert file's name to 'YYYY-MM-DD.txt' format",
        option => {
            'a|all' => {
                desc => "check and rename all files",
            },
        },
    };
}


sub run {
    my ($self, $args, $opt) = @_;


    if ($opt->{'a|all'}) {
        my $dir = @$args ? $args->[0] : $self->txt_dir;
        my @entry = $self->get_entries($dir);
        unless (@entry) {
            puts("$dir: no entries");
            return;
        }
        for (@entry) {
            revert($self, $_);
        }

    }
    elsif (@$args) {
        unless (-f $args->[0]) {
            $self->error($args->[0].":$!");
        }
        revert($self, $args->[0]);

    }
    else {
        $self->arg_error;
    }
}


sub revert {
    my ($self, $filename) = @_;


    my $date = $self->get_entrydate($filename);
    unless (defined $date) {
        $self->warning("$filename: not entry file");
        return;
    }
    # <year>-<month>-<day>.txt
    my $new_filename = $self->build_entrypath(
        $date->{year}, $date->{month}, $date->{day}
    );

    $self->debug("check if $filename and $new_filename is same basename?");
    unless (basename($filename) eq basename($new_filename)) {
        puts("rename $filename -> $new_filename");
        rename $filename, $new_filename
            or $self->error("$filename: Can't rename $filename $new_filename");
    }
}


1;
