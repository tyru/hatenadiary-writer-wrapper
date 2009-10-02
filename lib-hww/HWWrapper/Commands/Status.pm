package HWWrapper::Commands::Status;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{status} = {
        coderef => \&run,
        desc => 'show information about entry files',
        option => {
            'a|all' => {
                desc => "show all entries",
            },
            'C|no-caption' => {
                desc => "do not show caption and indent",
            },
        },
    };
}


# FIXME
# - apply-headlineでリネームした場合もstatusコマンドで表示されてしまう(多分)
#
# TODO
# - ログインしてるかしてないか表示
# - 管理下でないファイル(フォーマットに則ってないファイル)も表示
sub run {
    my ($self, $args, $opt) = @_;

    my $all = $opt->{'a|all'};
    my $no_caption = $opt->{'C|no-caption'};

    # if undef, $self->txt_dir is used.
    local $self->{config}{txt_dir} = @$args ? $args->[0] : $self->txt_dir;
    local $self->{config}{touch_file} = @$args ? File::Spec->catfile($self->txt_dir, 'touch.txt') : $self->touch_file;
    unless (-f $self->touch_file) {
        $self->error($self->touch_file.": $!");
    }


    if ($all) {
        puts("all entries:") unless $no_caption;
        for ($self->get_entries) {
            print "  " unless $no_caption;
            puts($_);
        }
    }
    else {
        # updated only.
        my @updated_entry = $self->get_updated_entries;

        unless (@updated_entry) {
            puts("no files updated.");
            return;
        }

        puts("updated entries:") unless $no_caption;
        for my $entry (@updated_entry) {
            print "  " unless $no_caption;
            puts($entry);
        }
    }
}


1;
