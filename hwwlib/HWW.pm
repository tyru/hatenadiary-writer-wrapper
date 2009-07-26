package HWW;

use strict;
use warnings;
use utf8;

use version;
our $VERSION = qv('0.0.9');

use File::Spec;
use Pod::Usage;
use File::Basename;
use FileHandle;
use Scalar::Util qw(blessed);
use POSIX ();


our %HWW_COMMAND = (
    help => 'help',
    version => 'version',
    release => 'release',
    update => 'update',
    load => 'load',
    verify => 'verify',
    'apply-headline' => 'apply_headline',
    touch => 'touch',
    'gen-html' => 'gen_html',
);

# TODO
# - write the document (under hwwlib/pod/)
# - the option which hw.pl can use should also be used in hww.pl
# - use Hatena AtomPub API. rewrite hw_main 's subroutine.
# - add the command which generates html.



### util commands ###

sub warning {
    if ($hww_main::debug) {
        my ($filename, $line) = (caller)[1, 2];
        warn "warning: at $filename line $line:", @_, "\n";
    } else {
        warn "warning: ", @_, "\n";
    }
}

sub error {
    if ($hww_main::debug) {
        my ($filename, $line) = (caller)[1, 2];
        die "error: at $filename line $line:", @_, "\n";
    } else {
        die "error: ", @_, "\n";
    }
}

sub debug {
    warn "debug: ", @_, "\n" if $hww_main::debug;
}

# not 'say'.
# but print with newline.
sub puts {
    print @_, "\n";
}

sub is_hww_command {
    my $cmd = shift;
    exists $HWW_COMMAND{$cmd};
}

sub sub_alias {
    my ($to, $from) = @_;
    no strict 'refs';
    *$to = $from;
}

sub_alias getopt => \&hww_main::getopt;

sub call_hw {

    my $hw = File::Spec->catfile($hww_main::BASE_DIR, 'hw.pl');
    my @debug = $hww_main::debug ? qw(-d) : ();
    my @cookie = $hww_main::no_cookie ? () : qw(-c);

    system 'perl', $hw, @debug, @cookie, @_;
}

sub require_modules {
    my @failed;
    for my $m (@_) {
        eval "require $m";
        if ($@) {
            push @failed, $m;
        }
    }
    if (@failed) {
        my $failed = join ', ', @failed;
        error("you need to install $failed.");
    }
}

sub get_entrydate {
    my $path = shift;

    if (basename($path) =~ /\A(\d{4})-(\d{2})-(\d{2})(-.+)?\.txt\Z/) {
        return {
            year  => $1,
            month => $2,
            day   => $3,
            rest  => $4,
        };
    } else {
        return undef;
    }
}

sub find_headlines {
    my ($body) = @_;
    my @headline;
    while ($body =~ s/^\*([^\n\*]+)\*//m) {
        push @headline, $1;
    }
    return @headline;
}



### dispatch ###

sub dispatch {
    my ($self, $cmd, $args) = @_;

    unless (blessed $self) {
        $self = bless {}, $self;
    }

    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    debug("dispatch '$cmd'");
    my $subname = $HWW_COMMAND{$cmd};
    $self->$subname($args);
}



### hww commands ###

sub help {
    my ($self, $args) = @_;
    my $cmd = exists $args->[0] ? $args->[0] : undef;

    unless (defined $cmd) {
        debug("show HWW.pm pod");
        pod2usage(-verbose => 2, -input => __FILE__);
    }

    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    my $podpath = File::Spec->catdir($hww_main::HWW_LIB, 'pod', "hww-$cmd.pod");
    unless (-f $podpath) {
        error("we have not written the document of '$cmd' yet.");
    }

    debug("show pod '$podpath'");
    pod2usage(-verbose => 2, -input => $podpath);
}

sub version {
    print <<EOD;
Hatena Diary Writer Wrapper version $HWW::VERSION
EOD
    exit;
}

sub release {
    my ($self, $args) = @_;

    my $trivial;
    getopt($args, {
        trivial => \$trivial,
        t => \$trivial,
    });

    my @hww_args;
    if ($trivial) {
        push @hww_args, '-t';
    }

    call_hw(@hww_args);
}

sub update {
    my ($self, $args) = @_;
    unshift @$args, '-t';
    $self->release($args);
}

sub load {
    my ($self, $args) = @_;

    my $all;
    my $draft;
    getopt($args, {
        all => \$all,
        a => \$all,
        # draft => \$draft,    # TODO
    }) or error("load: arguments error");

    if ($all) {
        require_modules(qw(XML::TreePP));

        package hw_main;

        # import and declare package global variables.
        our $user_agent;
        our $cookie_jar;
        our $hatena_url;
        our $username;


        # Login if necessary.
        login() unless ($user_agent);

        $user_agent->cookie_jar($cookie_jar);

        my $export_url = "$hatena_url/$username/export";
        print_debug("GET $export_url");
        my $r = $user_agent->simple_request(
            HTTP::Request::Common::GET($export_url)
        );

        unless ($r->is_success) {
            die "couldn't get entries:".$r->status_line;
        }

        my $xml_parser = XML::TreePP->new;
        my $entries = $xml_parser->parse($r->content);

        for my $entry (@{ $entries->{diary}{day} }) {
            my ($year, $month, $day);
            if ($entry->{'-date'} =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
                ($year, $month, $day) = ($1, $2, $3);
            } else {
                error_exit($entry->{'-date'}." is invalid format. (format: YYYY-MM-DD)");
            }

            save_diary_entry($year, $month, $day, $entry->{'-title'}, $entry->{body});
        }

        logout() if ($user_agent);

    } else {
        my $ymd = shift @$args || $self->dispatch('help', ['load']);
        call_hw('-l', $ymd);
    }
}

# currently only checking duplicated entries.
sub verify {
    my ($self) = @_;

    my $txt_dir = do {
        package hw_main;
        # import package global variables.
        our $txt_dir;
    };
    # TODO
    # - get $txt_dir from arguments.
    # - verify html dir(option).


    # check if a entry duplicates other entries.
    my %entry;
    my @duplicated;
    for my $file (map { basename $_ } glob "$txt_dir/*.txt") {
        my $date = get_entrydate($file);
        next    unless defined $date;

        my $ymd = sprintf "%s-%s-%s",
                            $date->{year},
                            $date->{month},
                            $date->{day};
        if (exists $entry{$ymd}) {
            debug("$file is duplicated.");
            push @duplicated, [$ymd, $file];
        } else {
            $entry{$ymd} = $file;
        }
    }

    if (@duplicated) {
        puts("duplicated entries here:");
        for (@duplicated) {
            # dulicated entry which was found at first
            puts("  $entry{$_->[0]}");
            # filepath
            puts("  $_->[1]");
        }
    } else {
        puts("ok: not found any bad conditions.");
    }
}
 
sub apply_headline {
    my ($self, $args) = @_;

    my $all;
    getopt($args, {
        all => \$all,
        a => \$all,
    });


    my $apply = sub {
        my $filename = shift || $self->dispatch('help', ['apply-headline']);

        my $FH = FileHandle->new($filename, 'r') or error("$filename:$!");
        my @headline = find_headlines(do { local $/; <$FH> });
        $FH->close;
        debug("found headline(s):".join(', ', @headline));

        my $date = get_entrydate($filename);
        return  unless defined $date;

        # <year>-<month>-<day>-<headlines>.txt
        my $new_filename = hw_main::text_filename(
            $date->{year},
            $date->{month},
            $date->{day},
            \@headline,
        );

        unless (basename($filename) eq basename($new_filename)) {
            puts("rename $filename -> $new_filename");
            rename $filename, $new_filename
                or error("$filename: Can't rename $filename $new_filename");
        }
    };

    if ($all) {
        for my $file (glob "$hww_main::TEXT_DIR/*.txt") {
            $apply->($file);
        }
    } else {
        $apply->(shift @$args || $self->dispatch('help', ['apply-headline']));
    }
}

sub touch {
    my ($self, $args) = @_;

    my $filename = File::Spec->catfile($hww_main::TEXT_DIR, 'touch.txt');
    my $FH = FileHandle->new($filename, 'w') or error("$filename:$!");
    $FH->print(POSIX::strftime("%Y%m%d%H%M%S", localtime));
    $FH->close;
}

sub gen_html {
    my ($self, $args) = @_;

    require_modules(qw(Text::Hatena));

    my ($in, $out) = @$args;
    if (! defined $in || ! defined $out) {
        $self->dispatch('help', ['gen_html'])
    }

    my $gen_html = sub {
        my ($in, $out) = @_;
        unless (defined get_entrydate($in)) {
            return;
        }


        my $IN = FileHandle->new($in, 'r') or error("$in:$!");

        my @text = <$IN>;
        # cut title.
        shift @text;
        # cut blank lines in order not to generate blank section.
        shift @text while ($text[0] =~ /^\s*$/);

        my $html = Text::Hatena->parse(join "\n", @text);
        $IN->close;

        # *.txt -> *.html
        $out =~ s/\.txt$/.html/;
        puts("gen_html: $in -> $out");

        my $OUT = FileHandle->new($out, 'w') or error("$out:$!");
        $OUT->print($html) or error("can't write to $html");
        $OUT->close;
    };

    if (-d $in && (-d $out || ! -e $out)) {
        # TODO generate only non-existent file(option).
        unless (-e $out) {
            mkdir $out;
        }
        for my $infile (glob "$in/*.txt") {
            my $outfile = File::Spec->catfile($out, basename($infile));
            $gen_html->($infile, $outfile);
        }

    } elsif (-f $in && (-f $out || ! -e $out)) {
        $gen_html->($in, $out);

    } else {
        # arguments error. show help.
        $self->dispatch('help', ['gen_html']);
    }
}


1;
__END__

=head1 NAME

    hww.pl - Hatena Diary Writer Wrapper


=head1 SYNOPSIS

    $ perl hww.pl [OPTIONS] COMMAND [ARGS]


=head1 OPTIONS

    these options for 'hww.pl'.
    if you see the help of command options, do it.
    $ perl hww.pl help <command>

=over

=item -h,--help

show this help text.

=item -v,--version

show version.

=back


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
