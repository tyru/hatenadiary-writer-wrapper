use strict;
use warnings;

use Test::More;
use Test::Output qw(stdout_isnt stderr_is output_from);
plan 'no_plan';

use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);

use HWWrapper;
my $wrapper = HWWrapper->new;

use HWWrapper::UtilSub;


{
    my @debugfiles;

    sub suicide {
        my $msg = shift;
        unlink $_ for @debugfiles;
        die $msg;
    }

    sub writedb {
        my ($filename, $text) = @_;

        require FileHandle;
        my $DBFH = FileHandle->new($filename, 'w') or suicide "$filename:$!";
        $DBFH->print($text);
        $DBFH->close;

        push @debugfiles, $filename;
    }
}


sub check_output {
    my $cmd = shift;


    stdout_isnt {
        $wrapper->dispatch($cmd);
    } '', "'$cmd' outputs something to stdout";

    stderr_is {
        $wrapper->dispatch($cmd);
    } '', "'$cmd' outputs nothing to stderr";

    my @same = (
        sub { $wrapper->dispatch($cmd) },
        sub { $wrapper->dispatch($cmd, []) },
        sub { $wrapper->$cmd() },
    );

    my $stdout = sub { (output_from \&{ shift() })[0] };
    my @outputs = map { $stdout->($_) } @same;
    ok uniq(@outputs) == 1, "equals all stdout";

    my $stderr = sub { (output_from \&{ shift() })[1] };
    @outputs = map { $stderr->($_) } @same;
    ok uniq(@outputs) == 1, "equals all stderr";
    ok $outputs[0] eq '', "stderr is ''";

    my $output = qx(perl hww.pl help);
    my $output2 = $stdout->(sub { $wrapper->dispatch('help') });
    # because HWWrapper.pm sees $0.
    ok $output ne $output2 or do {
        writedb "call-hww.pl.txt", $output;
        writedb "dispatch-cmd.txt", $output2;
        diag "test failed. see 'call-hww.pl.txt' and 'dispatch-cmd.txt'.";
    };
}



check_output($_) for qw(help version);

