package HWW;

use strict;
use warnings;
use utf8;

our $VERSION = '0.4.10';

# import util subs.
use HWW::UtilSub;


use Data::Dumper;

use File::Spec;
use Pod::Usage;
use File::Basename;
use FileHandle;
use Scalar::Util qw(blessed);
use POSIX ();


# command vs subname
our %HWW_COMMAND = (
    help => 'help',
    version => 'version',
    init => 'init',
    release => 'release',
    update => 'update',
    load => 'load',
    verify => 'verify',
    status => 'status',
    'apply-headline' => 'apply_headline',
    touch => 'touch',
    'gen-html' => 'gen_html',
    'update-index' => 'update_index',
    chain => 'chain',

    # TODO commands to manipulate tags.
    # 'add-tag' => 'add_tag',
    # 'delete-tag' => 'delete_tag',
    # 'rename-tag' => 'rename_tag',
);

# TODO
# - write the document (under hwwlib/pod/)
# - use Hatena AtomPub API. rewrite hw_main 's subroutine.




### dispatch ###

sub dispatch {
    my ($self, $cmd, $args) = @_;

    if ($hww_main::debug) {
        my ($filename, $line) = (caller)[1,2];
        $filename = basename($filename);
        my $args = join ', ', map { dumper($_) } @_;
        debug("at $filename line $line: dispatch($args)");
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
        pod2usage(-verbose => 1, -input => $0, -exitval => "NOEXIT");
        
        puts("available commands:");
        for my $command (keys %HWW_COMMAND) {
            puts("  $command");
        }
        puts;
        puts("and if you want to know hww.pl's option, perldoc -F hww.pl");

        return;
    }

    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    my $podpath = File::Spec->catdir($hww_main::HWW_LIB, 'pod', "hww-$cmd.pod");
    unless (-f $podpath) {
        error("we have not written the document of '$cmd' yet.");
    }

    debug("show pod '$podpath'");
    pod2usage(-verbose => 2, -input => $podpath, -exitval => "NOEXIT");
}

sub version {
    print <<EOD;
Hatena Diary Writer Wrapper version $HWW::VERSION
EOD
}

sub init {
    my ($self, $args) = @_;

    my $txt_dir = "text";
    my $config_file = "config.txt";
    my $cookie_file = "cookie.txt";

    my $read_config;
    get_opt($args, {
        config => \$read_config,
        c => \$read_config,
    });

    if ($read_config) {
        $txt_dir = $hw_main::txt_dir;
        $config_file = $hw_main::config_file;
        $cookie_file = $hw_main::cookie_file;
    }
    my $touch_file = File::Spec->catfile($txt_dir, 'touch.txt');


    unless (-e $txt_dir) {
        mkdir $txt_dir;
    }

    unless (-e $config_file) {
        my $CONF = FileHandle->new($config_file, 'w') or error("$config_file:$!");
        $CONF->print(<<EOT);
id:yourid
txt_dir:$txt_dir
touch:$touch_file
client_encoding:utf-8
server_encoding:euc-jp
EOT
        $CONF->close;
    }

    unless (-e $cookie_file) {
        # touch
        my $TOUCH = FileHandle->new($cookie_file, 'w') or error("$cookie_file:$!");
        $TOUCH->close;
    }

    chmod 0600, $cookie_file;
}

sub release {
    my ($self, $args) = @_;

    my $trivial;
    get_opt($args, {
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
    get_opt($args, {
        all => \$all,
        a => \$all,
        draft => \$draft,
        d => \$draft,
    }) or error("arguments error");


    if ($all) {
        package hw_main;

        use HWW::UtilSub qw(require_modules);
        require_modules(qw(XML::TreePP));

        # import and declare package global variables.
        our $user_agent;
        our $cookie_jar;
        our $hatena_url;
        our $username;
        our $txt_dir;

        if (@$args) {
            $txt_dir = shift(@$args);
        }
        unless (-d $txt_dir) {
            mkdir $txt_dir or error_exit("$txt_dir:$!");
        }

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

    } elsif ($draft) {
        package hw_main;

        use HWW::UtilSub qw(require_modules);
        require_modules(qw(LWP::Authen::Wsse XML::TreePP));


        my $draft_dir = shift(@$args);
        $self->arg_error unless defined $draft_dir;
        unless (-d $draft_dir) {
            mkdir $draft_dir or error_exit("can't mkdir $draft_dir:$!");
        }

        # apply patch dynamically.
        {
            my $save_diary_draft = sub ($$$) {
                my ($epoch, $title, $body) = @_;
                my $filename = draft_filename($epoch);

                my $OUT;
                if (not open $OUT, ">", $filename) {
                    error_exit("$!:$filename");
                }
                print $OUT $title."\n";
                print $OUT $body;
                close $OUT;
                print_debug("save_diary_entry: return 1 (OK)");
                return 1;
            };

            my $draft_filename = sub ($) {
                my ($epoch) = @_;
                return File::Spec->catfile($draft_dir, "$epoch.txt");
            };

            no strict 'refs';
            *save_diary_draft = $save_diary_draft;
            *draft_filename = $draft_filename;
        }

        # import and declare package global variables.
        our $user_agent;
        our $cookie_jar;
        our $hatena_url;
        our $username;
        our $password;


        login() unless ($user_agent);

        $user_agent->cookie_jar($cookie_jar);

        # $user_agent->credentials("d.hatena.ne.jp", '', $username, $password);
        {
            # Override get_basic_credentials
            # to return current username and password.
            package LWP::UserAgent;
            no warnings qw(redefine once);
            *get_basic_credentials = sub { ($username, $password) };
        }

        # http://d.hatena.ne.jp/{user}/atom/draft
        my $draft_collection_url = "$hatena_url/$username/atom/draft";
        my $xml_parser = XML::TreePP->new;

        # save draft entry.
        print_message("getting drafts...");
        for (my $page_num = 1; ; $page_num++) {
            my $url = $draft_collection_url.($page_num == 1 ? '' : "?page=$page_num");
            # $user_agent->simple_request() can't handle authentication response.
            print_debug("GET $url");
            my $r = $user_agent->request(
                HTTP::Request::Common::GET($url)
            );

            unless ($r->is_success) {
                error_exit("couldn't get drafts: ".$r->status_line);
            }

            my $drafts = $xml_parser->parse($r->content);
            my $feed = $drafts->{feed};

            unless (exists $feed->{entry}) {
                # No more drafts found.
                last;
            }

            for my $entry (@{ $feed->{entry} }) {
                my $epoch = (split '/', $entry->{'link'}{'-href'})[-1];
                save_diary_draft($epoch, $entry->{'title'}, $entry->{'content'}{'#text'});
            }
        }

        logout() if ($user_agent);

    } else {
        if (defined(my $ymd = shift(@$args))) {
            call_hw('-l', $ymd);
        } else {
            $self->arg_error;
        }
    }
}

# currently only checking duplicated entries.
sub verify {
    my ($self, $args) = @_;

    my $verify_html;
    get_opt($args, {
        html => \$verify_html,
    });

    my $dir = shift(@$args);
    my $fileglob;
    if ($verify_html) {
        $fileglob = '*.html';
    }


    my @entry = get_entries($dir, $fileglob);
    unless (@entry) {
        $dir = defined $dir ? $dir : $hw_main::txt_dir;
        puts("$dir: no entries found.");
        exit 0;
    }

    # check if a entry duplicates other entries.
    puts("checking duplicated entries...");
    my %entry;
    for my $file (@entry) {
        my $date = get_entrydate($file);
        dump($date);
        # no checking because get_entries()
        # might return only existed file.
        my $ymd = sprintf "%s-%s-%s",
                            $date->{year},
                            $date->{month},
                            $date->{day};
        if (exists $entry{$ymd}) {
            debug("$file is duplicated.");
            puts("foo:$ymd, $file");
            push @{ $entry{$ymd}{file} }, $file;
        } else {
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
    } else {
        puts("ok: not found any bad conditions.");
    }
}

# show entry's status
sub status {
    my ($self, $args) = @_;

    my $all;
    my $no_caption;
    get_opt($args, {
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
    get_opt($args, {
        all => \$all,
        a => \$all,
    });


    my $apply = sub {
        my $filename = shift;
        $self->arg_error unless $filename;

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
        if (defined(my $file = shift(@$args))) {
            $apply->($file);
        } else {
            $self->arg_error;
        }
    }
}

sub touch {
    my ($self, $args) = @_;

    my $filename = File::Spec->catfile($hw_main::txt_dir, 'touch.txt');
    my $FH = FileHandle->new($filename, 'w') or error("$filename:$!");
    # NOTE: I assume that this format is compatible
    # between Date::Manip::UnixDate and POSIX::strftime.
    my $touch_fmt = '%Y%m%d%H%M%S';

    if (@$args) {
        require_modules(qw(Date::Manip));
        Date::Manip->import(qw(ParseDate UnixDate));
        # NOTE: this parser is not compatible with 'rake touch <string>'.
        $FH->print(UnixDate(ParseDate(shift @$args), $touch_fmt));
    } else {
        $FH->print(POSIX::strftime($touch_fmt, localtime));
    }

    $FH->close;
}

sub gen_html {
    my ($self, $args) = @_;

    my $make_index;
    my $index_tmpl;
    my $missing_only;
    get_opt($args, {
        'update-index' => \$make_index,
        i => \$make_index,
        'I=s' => \$index_tmpl,
        'missing-only' => \$missing_only,
        m => \$missing_only,
    });

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

        puts("gen_html: $in -> $out");

        my $OUT = FileHandle->new($out, 'w') or error("$out:$!");
        $OUT->print($html) or error("can't write to $html");
        $OUT->close;
    };

    if (-d $in && (-d $out || ! -e $out)) {
        unless (-e $out) {
            mkdir $out;
        }

        for my $infile (glob "$in/*.txt") {
            my $outfile = File::Spec->catfile($out, basename($infile));
            # *.txt -> *.html
            $outfile =~ s/\.txt$/.html/;

            # '--missing-only' option generate only non-existent file.
            unless ($missing_only && -f $outfile) {
                $gen_html->($infile, $outfile);
            }
        }

        if (defined $index_tmpl) {
            $self->dispatch('update-index', [$index_tmpl, $out])
        } elsif ($make_index) {
            $self->dispatch('update-index', [$out]);
        }

    } elsif (-f $in && (-f $out || ! -e $out)) {
        $gen_html->($in, $out);

        if ($make_index) {
            $self->dispatch('update-index', [dirname($out)]);
        }

    } else {
        # arguments error. show help.
        $self->arg_error;
    }
}

sub update_index {
    my ($self, $args) = @_;

    my $max_strlen = 200;
    get_opt($args, {
        'max-length=s' => \$max_strlen,
        'm=s' => \$max_strlen,
    });


    require_modules(qw(
        HTML::TreeBuilder
        HTML::Template
        DateTime
        Time::Local
    ));

    my $update_index_main = sub {
        my ($html_dir, $index_tmpl) = @_;

        unless (-f $index_tmpl) {
            error_exit("$index_tmpl:$!");
        }


        my $template = HTML::Template->new(
            filename => $index_tmpl,
            die_on_bad_params => 0,    # No die if set non-existent parameter.
        );

        my @entry;
        for my $path (glob "$html_dir/*") {
            my $basename = basename($path);
            next    unless $basename =~ /^(\d{4})-(\d{2})-(\d{2})(?:-.+)?\.html$/;


            my ($year, $month, $day);
            my @date = ($year, $month, $day) = ($1, $2, $3);
            my $epoch = Time::Local::timelocal(0, 0, 0, $day, $month - 1, $year - 1900);


            my $tree = HTML::TreeBuilder->new_from_file($path);

            my $title = do {
                my ($h3) = $tree->find('h3');

                my $title;
                if (defined $h3) {
                    $title = $h3->as_text;
                    $title =~ s/^\*?\d+\*//;
                } else {
                    $title = "no title";
                };

                $title;
            };

            my $summary = do {
                # Get the inner text of all tags.
                my $as_text;
                $as_text = sub {
                    my ($elements, $text) = @_;
                    $text = "" unless defined $text;

                    while (defined(my $elem = shift @$elements)) {
                        if (Scalar::Util::blessed($elem) && $elem->isa('HTML::Element')) {
                            next    if lc($elem->tag) eq 'h3';    # Skip headline
                            @_ = ([$elem->content_list, @$elements], $text);
                            goto &$as_text;
                        } else {
                            my $s = "$elem";    # Stringify (call overload "")
                            next    if $s =~ /\A\s*\Z/m;
                            $s =~ s/\s*/ /m;    # Shrink all whitespaces
                            $text .= $s;
                        }

                        return $text.' ...' if length($text) > $max_strlen;
                    }

                    return $text;
                };

                my $sm;
                for my $section ($tree->look_down(class => 'section')) {
                    $sm .= $as_text->([$section->content_list]);
                    last    if length($sm) >= $max_strlen;
                }

                $sm;
            };

            $tree = $tree->delete;    # For memory


            # Newer to older
            unshift @entry, {
                'date'    => join('-', @date),
                'year'    => $date[0],
                'month'   => $date[1],
                'day'     => $date[2],
                'epoch'   => $epoch,
                'title'   => $title,
                'link'    => $basename,
                'summary' => $summary,
            };

            # dump($entry[0]);
        }
        $template->param(entrylist => \@entry);

        my $now = DateTime->now;
        $template->param(lastchanged_datetime => $now);
        $template->param(lastchanged_year  => $now->year);
        $template->param(lastchanged_month => $now->month);
        $template->param(lastchanged_day   => $now->day);
        $template->param(lastchanged_epoch => $now->epoch);


        # Output
        my $index_html = File::Spec->catfile($html_dir, "index.html");
        open my $OUT, '>', $index_html or error_exit("$index_html:$!");
        print $OUT $template->output;
        close $OUT;

        debug("generated $index_html...");
    };


    my $path = shift(@$args);
    unless (defined $path) {
        $self->arg_error;
    }

    if (-f $path) {
        if (@$args) {
            my $dir = shift @$args;
            error("$dir:$!") unless -d $dir;
            $update_index_main->($dir, $path);
        } else {
            $update_index_main->(dirname($path), $path);
        }

    } elsif (-d $path) {
        my $index_tmpl = File::Spec->catfile($path, 'index.tmpl');
        $update_index_main->($path, $index_tmpl);

    } else {
        warning("$path is neither file nor directory.");
        STDERR->flush;
        $self->arg_error;
    }
}

# perl hww.pl chain gen-html from to -- update-index index.tmpl to -- version
sub chain {
    my ($self, $args) = @_;
    return unless @$args;

    shift @$args while $args->[0] =~ /^-/;

    # @$args: (foo -x -- bar -y -- baz -z)
    # @dispatch:   ([qw(foo -x)], [qw(bar -y)], [qw(baz -z)])

    my @dispatch;
    push @dispatch, do {
        my @command_args;

        while (defined($_ = shift @$args)) {
            if ($_ eq '--') {
                last;
            } else {
                push @command_args, $_;
            }
        }

        \@command_args;
    } while @$args;


    for (@dispatch) {
        my ($command, @args) = @$_;
        $self->dispatch($command => \@args);
    }
}


1;
