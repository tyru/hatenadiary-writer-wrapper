package HWWrapper;

use strict;
use warnings;
use utf8;

our $VERSION = '1.1.17';

use base 'HW';

# import util subs.
use HWWrapper::UtilSub;


use Data::Dumper;

use File::Spec;
use Pod::Usage;
use File::Basename qw(dirname basename);
use FileHandle;
use Scalar::Util qw(blessed);
use POSIX ();



use FindBin qw($Bin);

# redefine for test scripts...
our $BASE_DIR = $Bin;
our $HWW_LIB  = File::Spec->catfile($BASE_DIR, 'lib-hww');


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
    #
    # diff => 'diff',
);

# TODO
# - write the document (under lib-hww/pod/)
# - use Hatena AtomPub API. rewrite HW 's subs.
# - HWのサブルーチンをHWWrapper::UtilSubで置き換えられる所は置き換える
# - HWのデバッグメッセージを変更
# - hww.pl内の引数処理を、HWWrapper.pm内に持っていって、HWWrapperが処理できるものはそこで、処理できないものはHWでする
# - HWがグローバル変数に頼るのをやめる($selfにつっこむ)
# - バージョンとヘルプにHW.pmのid:hyukiさん達のcopyright入れる
# - hw.plのオプションを取り替える
# (例えば-tはreleaseやupdateで指定できるのでいらない)
# - テスト環境を整える

# XXX
# - save_diary_draft()がクッキーを使ってログインできてない気がする
# (一回ログインした次が401 Authorizedになる)






### new() ###

sub new {
    my $self = bless {}, shift;

    # if ($self->SUPER::can('new')) {
    #     $self->SUPER::new(@_);
    # }

    return $self;
}



### parse_opt() ###
# parse @ARGV and if HWW can't handle that option(s),
# do $self->SUPER::parse_opt().

# hw.pl's options.
our %hw_opt = (
    t => \$HW::cmd_opt{t},
    'u=s' => \$HW::cmd_opt{u},
    'p=s' => \$HW::cmd_opt{p},
    'a=s' => \$HW::cmd_opt{a},
    'T=s' => \$HW::cmd_opt{T},
    'g=s' => \$HW::cmd_opt{g},
    'f=s' => \$HW::cmd_opt{f},
    M => \$HW::cmd_opt{M},
    'n=s' => \$HW::cmd_opt{n},
    # hw.pl's old option. hw.pl does not recognize this option.
    # S => \$HW::cmd_opt{S},
);
# this is additinal options which I added.
# not hw.pl's options.
our %hw_opt_long = (
    trivial => \$HW::cmd_opt{t},
    'username=s' => \$HW::cmd_opt{u},
    'password=s' => \$HW::cmd_opt{p},
    'agent=s' => \$HW::cmd_opt{a},
    'timeout=s' => \$HW::cmd_opt{T},
    'group=s' => \$HW::cmd_opt{g},
    'file=s' => \$HW::cmd_opt{f},
    'no-replace' => \$HW::cmd_opt{M},
    'config-file=s' => \$HW::cmd_opt{n},
);

my $show_help;
my $show_version;
our $debug;
our $debug_stderr;
our $no_cookie;
# hww.pl's options.
my %hww_opt = (
    help => \$show_help,
    version => \$show_version,

    d => \$debug,
    debug => \$debug,

    D => \$debug_stderr,
    'debug-stderr' => \$debug_stderr,

    C => \$no_cookie,
    'no-cookie' => \$no_cookie,

    %hw_opt,
    %hw_opt_long,
);


sub parse_opt {
    my $self = shift;
    my @argv = @_;
    my ($hww_args, $cmd, $cmd_args) = split_opt(@argv);
    my $tmp = [@$hww_args];

    # parse hww.pl's options.
    get_opt($hww_args, \%hww_opt) or do {
        warning "arguments error";
        sleep 1;
        $self->dispatch('help');
        exit -1;
    };
    debug(sprintf "%s -> %s, %s, %s",
                    dumper(\@argv),
                    dumper($tmp),
                    dumper($cmd),
                    dumper($cmd_args));

    if ($show_help || ! defined $cmd) {
        $self->dispatch('help');
        exit -1;
    }
    if ($show_version) {
        $self->dispatch('version');
        exit -1;
    }
    $HW::cmd_opt{c} = 1 unless $no_cookie;
    $HW::cmd_opt{d} = 1 if $debug;


    # restore arguments for hw.pl
    @argv = restore_hw_args(%hw_opt);

    # parse hw.pl's options.
    # NOTE: even if @argv == 0, let it parse.
    debug('let hw parse @argv...');
    $self->SUPER::parse_opt(@argv);

    return ($cmd, $cmd_args);
}



### dispatch() ###

sub dispatch {
    my ($self, $cmd, $args) = @_;
    $args = [] unless defined $args;

    unless (blessed $self) {
        $self = bless {}, $self;
    }

    unless (defined $cmd) {
        error("no command was given.");
    }
    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    # some debug messages.
    my ($filename, $line) = (caller)[1,2];
    $filename = basename($filename);
    my $args_dumped = join ', ', map { dumper($_) } @_;
    debug("at $filename line $line: dispatch($args_dumped)");
    debug(sprintf "dispatch '$cmd' with [%s]", join(', ', @$args));

    my $subname = $HWW_COMMAND{$cmd};
    $self->$subname($args);
}



### hww commands ###

# display help information about hww
sub help {
    my ($self, $args) = @_;
    my $cmd = shift @$args;

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

    my $podpath = File::Spec->catdir($HWW_LIB, 'pod', "hww-$cmd.pod");
    unless (-f $podpath) {
        error("we have not written the document of '$cmd' yet.");
    }

    debug("show pod '$podpath'");
    pod2usage(-verbose => 2, -input => $podpath, -exitval => "NOEXIT");
}

# display version information about hww
sub version {
    print <<EOD;
Hatena Diary Writer Wrapper version v$VERSION
EOD
    HW::VERSION_MESSAGE();
}

# TODO write help pod
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
        $txt_dir = $HW::txt_dir;
        $config_file = $HW::config_file;
        $cookie_file = $HW::cookie_file;
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

# upload entries to hatena diary
sub release {
    my ($self, $args) = @_;

    get_opt($args, {
        trivial => $HW::cmd_opt{t},
        t => $HW::cmd_opt{t},
    });

    my $dir = shift @$args;
    if (defined $dir) {
        $HW::txt_dir = $dir;
    }

    $self->SUPER::release();
}

# upload entries to hatena diary as trivial
sub update {
    my ($self, $args) = @_;
    unshift @$args, '-t';
    $self->release($args);
}

# load entries from hatena diary
sub load {
    my ($self, $args) = @_;

    my $all;
    my $draft;
    my $missing_only;
    get_opt($args, {
        all => \$all,
        a => \$all,
        draft => \$draft,
        d => \$draft,
        'missing-only' => \$missing_only,
        m => \$missing_only,
    }) or error("arguments error");


    if ($all) {
        require_modules(qw(XML::TreePP));

        if (@$args) {
            $HW::txt_dir = shift(@$args);
        }
        unless (-d $HW::txt_dir) {
            mkdir $HW::txt_dir or error("$HW::txt_dir:$!");
        }

        # Login if necessary.
        $self->login() unless ($HW::user_agent);

        $HW::user_agent->cookie_jar($HW::cookie_jar);

        my $export_url = "$HW::hatena_url/$HW::username/export";
        debug("GET $export_url");
        my $r = $HW::user_agent->simple_request(
            HTTP::Request::Common::GET($export_url)
        );

        unless ($r->is_success) {
            die "couldn't get entries:".$r->status_line;
        }
        puts("got $export_url");

        # NOTE: (2009-08-02)
        # if there were no entries on hatena,
        # $r->content returns
        #
        # <?xml version="1.0" encoding="UTF-8"?>
        # <diary>
        # </diary>
        #
        # so $entries
        #
        # {'diary' => ''}

        my $xml_parser = XML::TreePP->new;
        my $entries = $xml_parser->parse($r->content);
        my %current_entries = get_entries_hash();

        unless (exists $entries->{diary}) {
            error("invalid xml data returned from $HW::hatena_url")
        }
        # exists entries on hatena diary?
        if (! ref $entries->{diary} && $entries->{diary} eq '') {
            puts("no entries on hatena diary. ($HW::hatena_url)");
            return;
        }
        unless (ref $entries->{diary} eq 'HASH'
            && ref $entries->{diary}{day} eq 'ARRAY') {
            error("invalid xml data returned from $HW::hatena_url")
        }
        debug(sprintf '%d entries received.', scalar @{ $entries->{diary}{day} });


        for my $entry (@{ $entries->{diary}{day} }) {
            my ($year, $month, $day);
            if ($entry->{'-date'} =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
                ($year, $month, $day) = ($1, $2, $3);
            } else {
                error($entry->{'-date'}." is invalid format. (format: YYYY-MM-DD)");
            }

            unless ($missing_only && exists $current_entries{"$year-$month-$day"}) {
                $self->save_diary_entry(
                    $year,
                    $month,
                    $day,
                    $entry->{'-title'},
                    $entry->{body}
                );
            }
        }

        $self->logout() if ($HW::user_agent);

    } elsif ($draft) {
        # FIXME
        # unstable.
        # sometimes I can't login.
        # (something wrong with cookie.txt ?)
        require_modules(qw(LWP::Authen::Wsse XML::TreePP));


        my $draft_dir = shift(@$args);
        $self->arg_error unless defined $draft_dir;
        unless (-d $draft_dir) {
            mkdir $draft_dir or error("can't mkdir $draft_dir:$!");
        }

        # apply patch dynamically.
        {
            my $save_diary_draft = sub ($$$) {
                my $self = shift;
                my ($epoch, $title, $body) = @_;
                my $filename = $self->draft_filename($epoch);
                return if $missing_only && -f $filename;

                my $OUT;
                if (not open $OUT, ">", $filename) {
                    error("$!:$filename");
                }
                print $OUT $title."\n";
                print $OUT $body;
                close $OUT;
                debug("save_diary_draft: wrote $filename");
                return 1;
            };

            my $draft_filename = sub ($) {
                my $self = shift;
                my ($epoch) = @_;
                return File::Spec->catfile($draft_dir, "$epoch.txt");
            };

            no strict 'refs';
            *save_diary_draft = $save_diary_draft;
            *draft_filename = $draft_filename;
        }


        $self->login() unless ($HW::user_agent);

        $HW::user_agent->cookie_jar($HW::cookie_jar);

        # $HW::user_agent->credentials("d.hatena.ne.jp", '', $HW::username, $HW::password);
        {
            # Override get_basic_credentials
            # to return current username and password.
            package LWP::UserAgent;
            no warnings qw(redefine once);
            *get_basic_credentials = sub { ($HW::username, $HW::password) };
        }

        # http://d.hatena.ne.jp/{user}/atom/draft
        my $draft_collection_url = "$HW::hatena_url/$HW::username/atom/draft";
        my $xml_parser = XML::TreePP->new;

        # save draft entry.
        puts("getting drafts...");
        for (my $page_num = 1; ; $page_num++) {
            my $url = $draft_collection_url.($page_num == 1 ? '' : "?page=$page_num");
            # $HW::user_agent->simple_request() can't handle authentication response.
            debug("GET $url");
            my $r = $HW::user_agent->request(
                HTTP::Request::Common::GET($url)
            );

            unless ($r->is_success) {
                error("couldn't get drafts: ".$r->status_line);
            }
            puts("got $url");

            my $drafts = $xml_parser->parse($r->content);
            my $feed = $drafts->{feed};

            unless (exists $feed->{entry}) {
                # No more drafts found.
                last;
            }

            for my $entry (@{ $feed->{entry} }) {
                my $epoch = (split '/', $entry->{'link'}{'-href'})[-1];
                $self->save_diary_draft($epoch, $entry->{'title'}, $entry->{'content'}{'#text'});
            }
        }

        $self->logout() if ($HW::user_agent);

    } else {
        if (defined(my $ymd = shift(@$args))) {
            $HW::load_date = $HW::cmd_opt{l} = $ymd;
            $self->SUPER::load();
        } else {
            $self->arg_error;
        }
    }
}

# verify misc information
# NOTE: currently only checking duplicated entries.
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
        $dir = defined $dir ? $dir : $HW::txt_dir;
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

# show information about entry files
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

    # if undef, $HW::txt_dir is used.
    my $dir = shift @$args;
    if (defined $dir) {
        $HW::txt_dir = $dir;
        $HW::touch_file = File::Spec->catfile($dir, 'touch.txt');
        unless (-f $HW::touch_file) {
            error("$HW::touch_file:$!");
        }
    }


    if ($all) {
        puts("all entries:") unless $no_caption;
        for (get_entries($dir)) {
            print "  " unless $no_caption;
            puts($_);
        }
    } else {
        # updated only.
        my @updated_entry = grep {
            (-e $_ && -e $HW::touch_file)
            && -M $_ < -M $HW::touch_file
        } get_entries($dir);

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

# rename if modified headlines.
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
        my $new_filename = $self->text_filename(
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
        for my $file (glob "$HW::txt_dir/*.txt") {
            $apply->($file);
        }
    } else {
        my $file;
        if (defined($file = shift(@$args)) && -f $file) {
            $apply->($file);
        } else {
            $self->arg_error;
        }
    }
}

# update 'touch.txt'
sub touch {
    my ($self, $args) = @_;

    my $filename = File::Spec->catfile($HW::txt_dir, 'touch.txt');
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

# generate htmls from entry files
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
            $self->dispatch('update-index' => [$index_tmpl, $out])
        } elsif ($make_index) {
            $self->dispatch('update-index' => [$out]);
        }

    } elsif (-f $in && (-f $out || ! -e $out)) {
        $gen_html->($in, $out);

        if ($make_index) {
            $self->dispatch('update-index' => [dirname($out)]);
        }

    } else {
        # arguments error. show help.
        $self->arg_error;
    }
}

# make html from template file by HTML::Template
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
            error("$index_tmpl:$!");
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
        open my $OUT, '>', $index_html or error("$index_html:$!");
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

# chain commands with '--'
#   perl hww.pl chain gen-html from to -- update-index index.tmpl to -- version
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
