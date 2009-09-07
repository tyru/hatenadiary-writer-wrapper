package HWWrapper::Commands::Release;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{release} = {
        coderef => \&run,
        desc => 'upload entries to hatena diary',
        option => {
            't|trivial' => {
                desc => "upload entries as trivial",
            },
        },
    };
}


sub run {
    my ($self, $args, $opt) = @_;
    $self->trivial = $opt->{'t|trivial'};

    if (@$args) {
        unless (-e $args->[0]) {
            $self->error($args->[0].": $!");
        }

        if (-d $args->[0]) {
            $self->txt_dir = $args->[0];
        }
        elsif (-f $args->[0]) {
            $self->target_file = $args->[0];
        }
    }


    my $count = 0;
    my @files;

    # Setup file list.
    if ($self->target_file) {
        # Do not check timestamp.
        push(@files, $self->target_file);
        $self->debug("files: option -f: @files");
    }
    else {
        for ($self->get_entries($self->txt_dir)) {
            # Check timestamp.
            next if (-e($self->touch_file) and (-M($_) > -M($self->touch_file)));
            push(@files, $_);
        }
        $self->debug(sprintf 'files: current dir (%s): %s', $self->txt_dir, join ' ', @files);
    }

    # Process it.
    for my $file (@files) {
        # Check file name.
        next unless ($file =~ /\b(\d\d\d\d)-(\d\d)-(\d\d)(?:-.+)?\.txt$/);
        # Check if it is a file.
        next unless (-f $file);

        my ($year, $month, $day) = ($1, $2, $3);
        my $date = $year . $month . $day;

        # Login if necessary.
        $self->login();

        # Replace "*t*" unless suppressed.
        $self->replace_timestamp($file) unless ($self->no_timestamp);

        # Read title and body.
        my ($title, $body) = $self->read_title_body($file);

        # Find image files.
        my $imgfile = $self->find_image_file($file);

        if ($title eq $self->delete_title) {
            # Delete entry.
            puts("Delete $year-$month-$day.");
            $self->delete_diary_entry($date);
            puts("Delete OK.");
        }
        else {
            # Update entry.
            puts("Post $year-$month-$day.  " . ($imgfile ? " (image: $imgfile)" : ""));
            $self->update_diary_entry($year, $month, $day, $title, $body, $imgfile);
            puts("Post OK.");
        }

        sleep(1);

        $count++;
    }

    # Logout if necessary.
    $self->logout();

    if ($count == 0) {
        puts("No files are posted.");
    }
    else {
        unless ($self->target_file) {
            # Touch file.
            my $FILE;
            open($FILE, '>', $self->touch_file) or error($self->touch_file.": $!");
            print $FILE $self->get_timestamp();
            close($FILE);
        }
    }
}


1;
