package HWWrapper::Commands::Diff;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;

use File::Temp qw(tempdir tempfile);



sub regist_command {
    $HWW_COMMAND{diff} = {
        coderef => \&run,
        desc => 'show diff between local text and remote text',
        option => {
            'd|dir=s' => {
                desc => "diff all entries in that directory",
            },
            'f|file=s' => {
                desc => "diff only one file",
            },
            # TODO
            # 'format=s' => {},
            # all => {},
        },
    };
}


sub run {
    my ($self, $args, $opt) = @_;

    my $dir = $opt->{'d|dir=s'};
    my $file = $opt->{'f|file=s'};

    if (defined $dir) {
        $self->txt_dir = $dir;
    }


    if (defined $file) {
        # check if $file is entry file
        unless (-f $file) {
            $self->error("$file: $!");
        }
        my $date = $self->get_entrydate($file);
        unless (defined $date) {
            $self->error("$file: not entry file");
        }

        diff(
            $self,
            $self->cat_date($date->{year}, $date->{month}, $date->{day})
        );
    }
    elsif (@$args) {
        diff($self, $args->[0]);
    }
    else {
        my $processed;
        for (map { basename($_) } $self->get_updated_entries()) {
            diff($self, $_);
            $processed = 1;
        }
        unless ($processed) {
            puts("no files updated.");
        }
    }
}


sub diff {
    my ($self, $date) = @_;
    my ($year, $month, $day) = $self->split_date($date);

    # Login if necessary.
    $self->login();

    puts("Diff $year-$month-$day.");
    my ($title,  $body) = $self->load_diary_entry($year, $month, $day);
    $self->logout();

    my $src = $title."\n".$body;

    my $tmpdir = tempdir(CLEANUP => 1);
    my($fh, $tmpfilename) = tempfile('diff_XXXXXX', DIR => $tmpdir);
    print $fh $src;
    close $fh;

    my $filename = $self->get_entrypath($year, $month, $day);
    system "diff", $tmpfilename, $filename;
}


1;
