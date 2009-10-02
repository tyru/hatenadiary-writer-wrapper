package HWWrapper::Commands::Truncate;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;

use List::MoreUtils qw(first_index last_index);



sub regist_command {
    $HWW_COMMAND{truncate} = {
        coderef => \&run,
        desc => "truncate head or tail's blank lines of entry text",
    };
}


sub run {
    my ($self, $args) = @_;

    my $all;
    $self->get_opt($args, {
        all => \$all,
        a => \$all,
    }) or $self->arg_error();


    my $truncate = sub {
        my $file = shift;

        my $FH = FileHandle->new($file, 'r') or $self->error("$file: $!");
        my ($title, @body) = <$FH>;
        $FH->close;

        # find the line number of the top or bottom of blank lines.
        my $first = first_index { not /^\s*$/ } @body;
        my $last  = last_index { not /^\s*$/ } @body;

        # no waste blank lines.
        if ($first == 0 && $last == $#body) {
            return;
        }
        puts("$file: found waste blank lines...");

        # remove waste blank lines.
        $self->debug("truncate: [0..$#body] -> [$first..$last]");
        @body = @body[$first .. $last];

        # write result.
        $FH = FileHandle->new($file, 'w') or $self->error("$file: $!");
        $FH->print($title);
        $FH->print($_) for @body;
        $FH->close;
    };


    if ($all) {
        # don't change txt_dir because modifying this value influences other commands.
        my $txt_dir = $self->txt_dir;
        $txt_dir = $args->[0] if @$args;
        unless (-d $txt_dir) {
            mkdir $txt_dir or $self->error($txt_dir.": $!");
        }

        for my $entrypath ($self->get_entries($txt_dir)) {
            $self->debug($entrypath);
            $truncate->($entrypath);
        }
    }
    else {
        unless (@$args) {
            $self->arg_error();
        }

        my $file = shift @$args;
        unless (-f $file) {
            $self->error("$file: $!");
        }

        $truncate->($file);
    }
}


1;
