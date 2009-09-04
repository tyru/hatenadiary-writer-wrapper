package HWWrapper::Commands::Verify;

use strict;
use warnings;
use utf8;

use base qw(HWWrapper::Commands::Base);

# export our variables.
use HWWrapper::Commands qw(%HWW_COMMAND);
# export sub who does not take $self.
use HWWrapper::Functions;




sub regist_command {
    $HWW_COMMAND{verify} = {
        coderef => \&run,
        desc => 'verify misc information',
        option => {
            html => {
                desc => "verify html directory",
            },
        },
    };
}


# NOTE: currently only checking duplicated entries.
#
# TODO
# - 0詰めされてない日付のファイル名をチェック
# - はてな記法のチェック
sub run {
    my ($self, $args, $opt) = @_;

    my $dir = shift @$args;
    my $fileglob = '*.txt';
    # verify html files.
    if ($opt->{html}) {
        $fileglob = '*.html';
    }


    my @entry = $self->get_entries($dir, $fileglob);
    unless (@entry) {
        $dir = defined $dir ? $dir : $self->txt_dir;
        puts("$dir: no entries found.");
        return;
    }

    # check if a entry duplicates other entries.
    puts("checking duplicated entries...");
    my %entry;
    for my $file (@entry) {
        my $date = $self->get_entrydate($file);
        $self->dump($date);
        my $ymd = $self->cat_date($date->{year}, $date->{month}, $date->{day});
        if (exists $entry{$ymd}) {
            $self->debug("$file is duplicated.");
            push @{ $entry{$ymd}{file} }, $file;
        }
        else {
            $entry{$ymd} = {
                file => [$file]
            };
        }
    }

    my @duplicated = grep {
        @{ $entry{$_}{file} } > 1
    } keys %entry;

    if (@duplicated) {
        puts("duplicated entries here:");
        for my $ymd (@duplicated) {
            puts("  $ymd:");
            puts("    $_") for @{ $entry{$ymd}{file} };
        }
    }
    else {
        puts("ok: not found any bad conditions.");
    }
}


1;
