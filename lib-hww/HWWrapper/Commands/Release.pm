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
    local $self->{config}{trivial} = $opt->{'t|trivial'};

    # don't change txt_dir!!
    # that will influence other commands.
    my $txt_dir = $self->txt_dir;
    my $target_file;
    if (@$args) {
        unless (-e $args->[0]) {
            $self->error($args->[0].": $!");
        }

        if (-d $args->[0]) {
            $txt_dir = $args->[0];
        }
        elsif (-f $args->[0]) {
            $target_file = $args->[0];
        }
    }


    my @files;
    # Setup file list.
    if (defined $target_file) {
        # Do not check timestamp.
        push(@files, $target_file);
        $self->debug("files:@files");
    }
    else {
        for ($self->get_updated_entries($txt_dir)) {
            # Check timestamp.
            push(@files, $_);
        }
        $self->debug(
            sprintf 'current dir:%s, files:%s',
                    $txt_dir, join(', ', @files));
    }

    unless (@files) {
        puts("No files are posted.");
        return;
    }

    # Login if necessary.
    $self->login();

    # Process it.
    for my $file (@files) {
        # Check file name.
        my $datehashref = $self->get_entrydate($file);
        next unless defined $datehashref;

        # Replace "*t*" unless suppressed.
        $self->replace_timestamp($file) unless ($self->no_timestamp);

        # Read title and body.
        my ($title, $body) = $self->read_title_body($file);

        # Find image files.
        my $imgfile = $self->find_image_file($file);

        my ($year, $month, $day) = @$datehashref{qw(year month day)};
        if ($title eq $self->delete_title) {
            # Delete entry.
            puts("Delete $year-$month-$day.");
            $self->delete_diary_entry($year, $month, $day);
            puts("Delete OK.");
        }
        else {
            # Update entry.
            puts("Post $year-$month-$day.  " . ($imgfile ? " (image: $imgfile)" : ""));
            $self->update_diary_entry($year, $month, $day, $title, $body, $imgfile);
            puts("Post OK.");
        }

        sleep(1);
    }

    # Logout if necessary.
    $self->logout();
    # update touch file.
    $self->update_touch_file;
}


1;
