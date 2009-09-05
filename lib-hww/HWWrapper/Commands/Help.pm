package HWWrapper::Commands::Help;

use strict;
use warnings;
use utf8;

use base qw(HWWrapper::Commands::Base);

# export our variables.
use HWWrapper::Commands;
# export sub who does not take $self.
use HWWrapper::Functions;


use Pod::Usage;




sub regist_command {
    $HWW_COMMAND{help} = {
        coderef => \&run,
        desc => 'display help information about hww',
    };
}


sub run {
    my ($self, $args, $opt) = @_;
    my $cmd = shift @$args;

    # TODO
    # - -P, --no-pager (ページャで起動)
    # - Pod::Manでヘルプを出力し、utf8オプションを有効にし、日本語を出力できるようにする。
    if ($opt->{'--list-command'}) {
        # --list-command
        for my $command (sort keys %HWW_COMMAND) {
            puts($command);
        }

        return;
    }
    elsif (not defined $cmd) {
        # show all commands and usage.
        my $hww_pl_path = File::Spec->catfile($BASE_DIR, 'hww.pl');
        pod2usage(-verbose => 1, -input => $hww_pl_path, -exitval => "NOEXIT");

        puts("available commands:");
        for my $command (sort keys %HWW_COMMAND) {
            puts("  $command");
        }
        puts();
        puts("and if you want to know hww.pl's option, perldoc -F hww.pl");

        return;
    }
    elsif (not $self->is_command($cmd)) {
        # $cmd is not command, error.
        $self->error("'$cmd' is not a hww-command. See perl hww.pl help");
    }


    # show help pod.

    my $podpath = File::Spec->catdir($POD_DIR, "hww-$cmd.pod");
    unless (-f $podpath) {
        $self->error("we have not written the document of '$cmd' yet.");
    }

    $self->debug("show pod '$podpath'");
    pod2usage(-verbose => 2, -input => $podpath, -exitval => "NOEXIT");
}


1;
