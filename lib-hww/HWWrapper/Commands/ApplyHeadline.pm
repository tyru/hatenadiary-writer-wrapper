package HWWrapper::Commands::ApplyHeadline;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{'apply-headline'} = {
        coderef => \&run,
        desc => 'rename if modified headlines',
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
        unless (-d $dir) {
            $self->error("$dir: $!");
        }

        my @entry = $self->get_entries($dir);
        unless (@entry) {
            puts("$dir: no entries");
            return;
        }

        for (@entry) {
            apply($self, $_);
        }
    }
    elsif (@$args) {
        unless (-f $args->[0]) {
            $self->error("$args->[0]: $!");
        }
        apply($self, $args->[0]);
    }
    else {
        $self->arg_error;
    }
}


sub apply {
    my ($self, $filename) = @_;

    $self->arg_error unless $filename;

    my $FH = FileHandle->new($filename, 'r') or $self->error("$filename:$!");
    my @headline = $self->find_headlines(do { local $/; <$FH> });
    $FH->close;
    $self->debug("found headline(s):".join(', ', @headline));

    my $date = $self->get_entrydate($filename);
    return  unless defined $date;

    # <year>-<month>-<day>-<headlines>.txt
    my $new_filename = $self->build_entrypath(
        $date->{year},
        $date->{month},
        $date->{day},
        [@headline],
    );

    unless (basename($filename) eq basename($new_filename)) {
        puts("rename $filename -> $new_filename");
        rename $filename, $new_filename
            or $self->error("$filename: Can't rename $filename $new_filename");
    }
}


1;
