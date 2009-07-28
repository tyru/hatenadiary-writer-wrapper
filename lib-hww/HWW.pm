package HWW;

use strict;
use warnings;
use utf8;

use version;
our $VERSION = qv('0.0.10');

# import util subs.
use HWW::UtilSub;


use Data::Dumper;

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
    'show-entry' => 'show_entry',
    'apply-headline' => 'apply_headline',
    touch => 'touch',
    'gen-html' => 'gen_html',
);

# TODO
# - write the document (under hwwlib/pod/)
# - the option which hw.pl can use should also be used in hww.pl
# - use Hatena AtomPub API. rewrite hw_main 's subroutine.




### dispatch ###

sub dispatch {
    my ($self, $cmd, $args) = @_;

    if ($hww_main::debug) {
        my ($filename, $line) = (caller)[1,2];
        my $args = join ', ', map { dumper($_) } @_;
        debug("dispatch($args) is called from at $filename line $line");
    }

    unless (blessed $self) {
        $self = bless {}, $self;
    }
    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    dump(\@_);
    debug("dispatch '$cmd'");

    my $subname = $HWW_COMMAND{$cmd};
    $self->$subname($args);
}



### hww commands ###

sub help {
    my ($self, $args) = @_;
    my $cmd = exists $args->[0] ? $args->[0] : undef;

    unless (defined $cmd) {
        puts("available commands:");
        for my $command (keys %HWW_COMMAND) {
            puts("  $command");
        }
        puts;
        puts("and if you want to know hww.pl's option, perldoc -F hww.pl");

        exit 0;    # end.
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
        my $ymd = shift(@$args) || $self->arg_error;
        call_hw('-l', $ymd);
    }
}

# currently only checking duplicated entries.
sub verify {
    my ($self) = @_;

    # TODO
    # - get $txt_dir from arguments.
    # - verify html dir(option).


    # check if a entry duplicates other entries.
    my %entry;
    my @duplicated;
    for my $file (get_entries()) {
        my $date = get_entrydate($file);
        # no checking because get_entries()
        # might return only existed file.
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

# show entries in many ways.
sub show_entry {
    my ($self, $args) = @_;

    my $all;
    my $no_caption;
    getopt($args, {
        all => \$all,
        a => \$all,
        C => \$no_caption,
        'no-caption' => \$no_caption,
    });

    if ($all) {
        puts("all entries:") unless $no_caption;
        for (get_entries()) {
            print "  " unless $no_caption;
            puts($_);
        }
    } else {
        # updated only.
        puts("updated entries:") unless $no_caption;
        for my $entry (get_entries()) {
            if ((-e $entry && -e $hw_main::touch_file)
                && -M $entry < -M $hw_main::touch_file)
            {
                print "  " unless $no_caption;
                puts($entry);
            }
        }
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
        my $filename = shift || $self->arg_error;

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
        for my $file (glob "$hw_main::txt_dir/*.txt") {
            $apply->($file);
        }
    } else {
        $apply->(shift(@$args) || $self->arg_error);
    }
}

sub touch {
    my ($self, $args) = @_;

    # TODO parse given date string,
    # and replace the line in touch.txt with that date.

    my $filename = File::Spec->catfile($hw_main::txt_dir, 'touch.txt');
    my $FH = FileHandle->new($filename, 'w') or error("$filename:$!");
    $FH->print(POSIX::strftime("%Y%m%d%H%M%S", localtime));
    $FH->close;
}

sub gen_html {
    my ($self, $args) = @_;

    require_modules(qw(Text::Hatena));

    my ($in, $out) = @$args;
    if (! defined $in || ! defined $out) {
        $self->arg_error;
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

        # TODO use POE(option)?
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
        $self->arg_error;
    }
}


1;
