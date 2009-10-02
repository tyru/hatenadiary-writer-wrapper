package HWWrapper::Commands::Editor;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{editor} = {
        coderef => \&run,
        desc => "edit today's entry quickly",
        option => {
            'g|gui' => {
                desc => 'wait until forked program exits',
            },
            'p|program=s' => {
                desc => 'editor program to edit',
            },
        },
    };
}


sub run {
    my ($self, $args, $opt) = @_;
    my $is_gui_prog = $opt->{'g|gui'};

    my $editor;
    if ($opt->{'p|program=s'}) {    # --program
        $editor = $opt->{'p|program=s'};

    }
    elsif (defined $self->editor) {
        # default value is $ENV{EDITOR}.
        $editor = $self->editor;
    }
    else {
        $self->error(
            "no editor program found."
           ." please set env 'EDITOR' or give me editor path."
        );
    }

    unless (-e $editor) {
        my $e;
        # find in $PATH.
        for my $path (File::Spec->path) {
            my $editor_path = File::Spec->catfile($path, $editor);
            if (-e $editor_path) {
                $e = $editor_path;
                last;
            }
        }
        $self->error("could not find '$editor'.") unless defined $e;
        $editor = $e;
    }


    my ($year, $month, $day);
    if (@$args) {
        ($year, $month, $day) = $self->split_date($args->[0]);
    }
    else {
        ($year, $month, $day) = (localtime)[5, 4, 3];
        $year  += 1900;
        $month += 1;
    }
    my $entrypath = $self->get_entrypath($year, $month, $day);
    # save status of file test because $entrypath might be created after this.
    my $exist_entry = (-f $entrypath);
    my $mtime       = (-M $entrypath);

    puts("opening editor...");

    if ($is_gui_prog) {
        run_gui_prog($self, $editor, $entrypath);
    }
    else {
        system $editor, $entrypath;
    }


    # check entry's status
    if ($exist_entry) {
        if ($mtime == -M $entrypath) {
            puts("changed $entrypath.");
        }
        else {
            puts("not changed $entrypath.");
        }
    }
    else {
        if (-f $entrypath) {
            puts("saved $entrypath.");
        }
        else {
            puts("not saved $entrypath.");
        }
    }
}


sub run_gui_prog {
    my ($self, $editor, $entrypath) = @_;

    $self->require_modules(qw(IPC::Run));

    # prepare editor process.
    my $editor_proc = IPC::Run::harness(
        [$editor, $entrypath], \my $in, \my $out, \my $err
    );

    # install signal handlers.
    my @sig_to_trap = qw(INT);
    local @SIG{@sig_to_trap} = map {
        my $signame = $sig_to_trap[$_];
        STDERR->autoflush(1);

        sub {
            STDERR->print(
                "caught SIG$signame, "
                ."sending SIGKILL to editor process...\n"
            );
            # kill the process immediatelly.
            # (wait 0 second)
            $editor_proc->kill_kill(grace => 0);

            $self->debug("exiting with -1...");
            exit -1;
        };
    } 0 .. $#sig_to_trap;

    # spawn editor program.
    $self->debug("start [$editor $entrypath]...");
    $editor_proc->start;
    $self->debug("finish [$editor $entrypath]...");
    $editor_proc->finish;
    $self->debug("done.");
}

1;
