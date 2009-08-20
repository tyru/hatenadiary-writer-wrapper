package HWWrapper::Commands;

use strict;
use warnings;
use utf8;

our $VERSION = "1.1.0";

# import builtin op's hooks
# (these ops are hooked in HWWrapper::Commands::shell())
#
# and this package also exports these ops.
use HWWrapper::Hook::BuiltinFunc;

use HWWrapper::Functions;
use HWWrapper::Constants qw($BASE_DIR $HWW_LIB);

use File::Basename qw(dirname basename);
use Scalar::Util qw(blessed);
use File::Temp qw(tempdir tempfile);
use Term::ReadLine;
use Pod::Usage;
use List::MoreUtils qw(first_index last_index);


our %HWW_COMMAND = (
    help => {
        coderef => \&help,
        desc => 'display help information about hww',
    },
    version => {
        coderef => \&version,
        desc => 'display version information about hww',
    },
    copyright => {
        coderef => \&copyright,
    },
    init => {
        coderef => \&init,
        option => {
            'c|config' => {
                desc => "apply config's settings",
            },
        },
    },
    release => {
        coderef => \&release,
        desc => 'upload entries to hatena diary',
        option => {
            't|trivial' => {
                desc => "upload entries as trivial",
            },
        },
    },
    update => {
        coderef => \&update,
        desc => 'upload entries to hatena diary as trivial',
        option => {
            't|trivial' => {
                desc => "upload entries as trivial",
            },
        },
    },
    load => {
        coderef => \&load,
        desc => 'load entries from hatena diary',
        option => {
            'a|all' => {
                desc => "fetch all entries",
            },
            'd|draft' => {
                desc => "fetch all draft entries",
            },
            'm|missing-only' => {
                desc => "fetch only missing entries",
            },
            # TODO fetch only different data's entries.
            # 'c|compare' => {
            # },
        },
    },
    verify => {
        coderef => \&verify,
        desc => 'verify misc information',
        option => {
            html => {
                desc => "verify html directory",
            },
        },
    },
    status => {
        coderef => \&status,
        desc => 'show information about entry files',
        option => {
            'a|all' => {
                desc => "show all entries",
            },
            'C|no-caption' => {
                desc => "do not show caption and indent",
            },
        },
    },
    'apply-headline' => {
        coderef => \&apply_headline,
        desc => 'rename if modified headlines',
        option => {
            'a|all' => {
                desc => "check and rename all files",
            },
        },
    },
    'revert-headline' => {
        coderef => \&revert_headline,
        option => {
            'a|all' => {
                desc => "check and rename all files",
            },
        },
    },
    touch => {
        coderef => \&touch,
        desc => "update 'touch.txt'",
    },
    'gen-html' => {
        coderef => \&gen_html,
        desc => 'generate htmls from entry files',
        option => {
            'i|update-index' => {
                desc => "exec 'update-index' command after 'gen-html'",
            },
            'I=s' => {
                desc => "exec 'update-index' command with specified template file after 'gen-html'",
            },
            'm|missing-only' => {
                desc => "generate html only missing entries",
            },
        },
    },
    'update-index' => {
        coderef => \&update_index,
        desc => 'make html from template file by HTML::Template',
        option => {
            'm|max-length=s' => {
                desc => "max summary byte length",
            },
        },
    },
    chain => {
        coderef => \&chain,
        desc => "chain commands with '--'",
    },
    diff => {
        coderef => \&diff,
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
    },
    shell => {
        coderef => \&shell,
    },
    truncate => {
        coderef => \&truncate_cmd,
    },
    editor => {
        coderef => \&editor,
        option => {
            'g|gui' => {
                desc => 'wait until gui program exits',
            },
        }
    },

    # TODO commands to manipulate tags.
    # 'add-tag' => 'add_tag',
    # 'delete-tag' => 'delete_tag',
    # 'rename-tag' => 'rename_tag',

    # TODO 現在の日記ファイルを作ってエディタで開くコマンド
    # TODO 設定(ファイルはconfig-hww.txt)を変えるコマンド
    # config => 'config',
);



### hww commands ###

# display help information about hww
sub help {
    my ($self, $args) = @_;
    my $cmd = shift @$args;

    # TODO
    # - hww.plのオプションを見られるようにする (shellコマンドの為に)
    # - --list-command (主にzsh補完用)
    # - -P, --no-pager (ページャで起動)
    # - Pod::Manでヘルプを出力し、utf8オプションを有効にし、日本語を出力できるようにする。

    unless (defined $cmd) {
        my $hww_pl_path = File::Spec->catfile($BASE_DIR, 'hww.pl');
        pod2usage(-verbose => 1, -input => $hww_pl_path, -exitval => "NOEXIT");

        puts("available commands:");
        for my $command (sort keys %HWW_COMMAND) {
            if (exists $HWW_COMMAND{$command}{desc}) {
                puts("  $command - $HWW_COMMAND{$command}{desc}");
            }
            else {
                puts("  $command");
            }
        }
        puts();
        puts("and if you want to know hww.pl's option, perldoc -F hww.pl");

        return;
    }


    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl hww.pl help");
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
Hatena Diary Writer Wrapper version v$HWWrapper::VERSION
EOD
    HW::VERSION_MESSAGE();
}

# TODO write help
sub copyright {
    print <<EOD;

hw.pl - Hatena Diary Writer (with Loader).

Copyright (C) 2004,2005,2007 by Hiroshi Yuki.
<hyuki\@hyuki.com>
http://www.hyuki.com/techinfo/hatena_diary_writer.html

Special thanks to:
- Ryosuke Nanba http://d.hatena.ne.jp/rna/
- Hahahaha http://www20.big.or.jp/~rin_ne/
- Ishinao http://ishinao.net/

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

'Hatena Diary Loader' originally written by Hahahaha(id:rin_ne)
   http://d.hatena.ne.jp/rin_ne/20040825#p7

Modified by Kengo Koseki (id:koseki2)
   http://d.hatena.ne.jp/koseki2/


hww.pl - Hatena Diary Writer Wrapper

Copyright (C) 2009 by tyru.
<tyru.exe\@gmail.com>

EOD
}

# TODO write help pod
sub init {
    my ($self, $args, $opt) = @_;

    my $read_config = $opt->{'c|config'};

    my $txt_dir = "text";
    my $config_file = "config.txt";
    my $cookie_file = "cookie.txt";

    my $dir = shift @$args;
    if (defined $dir) {
        $txt_dir = $dir;
    }
    elsif ($read_config) {
        $txt_dir = $self->txt_dir;
        $config_file = $self->config_file,
        $cookie_file = $self->cookie_file;
    }
    my $touch_file = File::Spec->catfile($txt_dir, 'touch.txt');


    if (-e $txt_dir) {
        warning("$txt_dir already exists.");
    }
    else {
        mkdir $txt_dir;
    }

    if (-e $config_file) {
        warning("$config_file already exists.");
    }
    else {
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

    if (-e $cookie_file) {
        warning("$config_file already exists.");
    }
    else {
        # make empty file
        my $TOUCH = FileHandle->new($cookie_file, 'w') or error("$cookie_file:$!");
        $TOUCH->close;
    }

    debug("chmod 0600 $cookie_file");
    chmod 0600, $cookie_file;
}

# upload entries to hatena diary
sub release {
    my ($self, $args, $opt) = @_;
    $self->trivial = $opt->{'t|trivial'};

    if (@$args) {
        unless (-e $args->[0]) {
            error($args->[0].": $!");
        }

        if (-d $args->[0]) {
            $self->txt_dir = $args->[0];
        }
        elsif (-f $args->[0]) {
            $self->target_file = $args->[0];
        }
    }


    my $count = 0;
    my @files;

    # Setup file list.
    if ($self->target_file) {
        # Do not check timestamp.
        push(@files, $self->target_file);
        debug("files: option -f: @files");
    }
    else {
        for ($self->get_entries($self->txt_dir)) {
            # Check timestamp.
            next if (-e($self->touch_file) and (-M($_) > -M($self->touch_file)));
            push(@files, $_);
        }
        debug(sprintf 'files: current dir (%s): %s', $self->txt_dir, join ' ', @files);
    }

    # Process it.
    for my $file (@files) {
        # Check file name.
        next unless ($file =~ /\b(\d\d\d\d)-(\d\d)-(\d\d)(?:-.+)?\.txt$/);
        # Check if it is a file.
        next unless (-f $file);

        my ($year, $month, $day) = ($1, $2, $3);
        my $date = $year . $month . $day;

        # Login if necessary.
        $self->login();

        # Replace "*t*" unless suppressed.
        $self->replace_timestamp($file) unless ($self->no_timestamp);

        # Read title and body.
        my ($title, $body) = $self->read_title_body($file);

        # Find image files.
        my $imgfile = $self->find_image_file($file);

        if ($title eq $self->delete_title) {
            # Delete entry.
            puts("Delete $year-$month-$day.");
            $self->delete_diary_entry($date);
            puts("Delete OK.");
        }
        else {
            # Update entry.
            puts("Post $year-$month-$day.  " . ($imgfile ? " (image: $imgfile)" : ""));
            $self->update_diary_entry($year, $month, $day, $title, $body, $imgfile);
            puts("Post OK.");
        }

        sleep(1);

        $count++;
    }

    # Logout if necessary.
    $self->logout();

    if ($count == 0) {
        puts("No files are posted.");
    }
    else {
        unless ($self->target_file) {
            # Touch file.
            my $FILE;
            open($FILE, '>', $self->touch_file) or error($self->touch_file.": $!");
            print $FILE $self->get_timestamp();
            close($FILE);
        }
    }
}

# upload entries to hatena diary as trivial
sub update {
    my ($self, $args, $opt) = @_;
    $opt->{'t|trivial'} = 1;
    $self->release($args, $opt);
}

# load entries from hatena diary
sub load {
    my ($self, $args, $opt) = @_;

    my $all = $opt->{'a|all'};
    my $draft = $opt->{'d|draft'};
    my $missing_only = $opt->{'m|missing-only'};


    if ($all) {
        require_modules(qw(XML::TreePP));

        if (@$args) {
            $self->txt_dir = shift(@$args);
        }
        unless (-d $self->txt_dir) {
            mkdir $self->txt_dir or error($self->txt_dir.": $!");
        }

        # Login if necessary.
        $self->login();

        $self->user_agent->cookie_jar($self->cookie_jar);

        my $export_url = sprintf '%s/%s/export', $self->hatena_url, $self->username;
        debug("GET $export_url");
        my $r = $self->user_agent->simple_request(
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
        my %current_entries = $self->get_entries_hash();

        unless (exists $entries->{diary}) {
            error("invalid xml data returned from ".$self->hatena_url)
        }
        # exists entries on hatena diary?
        if (! ref $entries->{diary} && $entries->{diary} eq '') {
            puts(sprintf 'no entries on hatena diary. (%s)', $self->hatena_url);
            return;
        }
        unless (ref $entries->{diary} eq 'HASH'
            && ref $entries->{diary}{day} eq 'ARRAY') {
            error("invalid xml data returned from ".$self->hatena_url)
        }
        debug(sprintf '%d entries received.', scalar @{ $entries->{diary}{day} });


        for my $entry (@{ $entries->{diary}{day} }) {
            my ($year, $month, $day);
            if ($entry->{'-date'} =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
                ($year, $month, $day) = ($1, $2, $3);
            }
            else {
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

        $self->logout();

    }
    elsif ($draft) {
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


        $self->login();

        # TODO
        # save wsse header.
        # because authetication with cookie has been obsoleted
        # (cookie is expired at that time) since 2008-09-02.
        #
        # $self->user_agent->cookie_jar($self->cookie_jar);

        my $url = $self->hatena_url->host.':'.$self->hatena_url->port;
        $self->user_agent->credentials($url, '', $self->username, $self->password);

        # http://d.hatena.ne.jp/{user}/atom/draft
        my $draft_collection_url = sprintf '%s/%s/atom/draft', $self->hatena_url, $self->username;
        my $xml_parser = XML::TreePP->new;

        # save draft entry.
        puts("getting drafts...");
        for (my $page_num = 1; ; $page_num++) {
            my $url = $draft_collection_url.($page_num == 1 ? '' : "?page=$page_num");
            # $self->user_agent->simple_request() can't handle authentication response.
            debug("GET $url");
            my $r = $self->user_agent->request(
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

        $self->logout();

    }
    elsif (defined(my $ymd = shift @$args)) {
        my ($year, $month, $day) = $self->parse_date($ymd);

        $self->login();

        puts("Load $year-$month-$day.");
        my ($title, $body) = $self->load_diary_entry($year, $month, $day);
        $self->save_diary_entry($year, $month, $day, $title, $body);
        puts("Load OK.");

        $self->logout();
    }
    else {
        $self->arg_error;
    }
}

# verify misc information
# NOTE: currently only checking duplicated entries.
sub verify {
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
        dump($date);
        # no checking because $self->get_entries()
        # might return only existed file.
        my $ymd = sprintf "%s-%s-%s",
                            $date->{year},
                            $date->{month},
                            $date->{day};
        if (exists $entry{$ymd}) {
            debug("$file is duplicated.");
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

# show information about entry files
sub status {
    my ($self, $args, $opt) = @_;

    my $all = $opt->{'a|all'};
    my $no_caption = $opt->{'C|no-caption'};

    # if undef, $self->txt_dir is used.
    my $dir = shift @$args;
    if (defined $dir) {
        $self->txt_dir = $dir;
        $self->touch_file = File::Spec->catfile($dir, 'touch.txt');
        unless (-f $self->touch_file) {
            error($self->touch_file.": $!");
        }
    }


    if ($all) {
        puts("all entries:") unless $no_caption;
        for ($self->get_entries($dir)) {
            print "  " unless $no_caption;
            puts($_);
        }
    }
    else {
        # updated only.
        my @updated_entry = $self->get_updated_entries($dir);

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
    my ($self, $args, $opt) = @_;


    my $apply = sub {
        my $filename = shift;
        $self->arg_error unless $filename;

        my $FH = FileHandle->new($filename, 'r') or error("$filename:$!");
        my @headline = $self->find_headlines(do { local $/; <$FH> });
        $FH->close;
        debug("found headline(s):".join(', ', @headline));

        my $date = $self->get_entrydate($filename);
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

    if ($opt->{'a|all'}) {
        my $dir = @$args ? $args->[0] : $self->txt_dir;
        my @entry = $self->get_entries($dir);
        unless (@entry) {
            puts("$dir: no entries");
            return;
        }
        for (@entry) {
            $apply->($_);
        }
    }
    elsif (@$args) {
        unless (-f $args->[0]) {
            error($args->[0].":$!");
        }
        $apply->($args->[0]);
    }
    else {
        $self->arg_error;
    }
}

# TODO ヘルプ書く
sub revert_headline {
    my ($self, $args, $opt) = @_;


    my $revert = sub {
        my $filename = shift;

        my $date = $self->get_entrydate($filename);
        unless (defined $date) {
            warning("$filename: not entry file");
            return;
        }
        # <year>-<month>-<day>.txt
        my $new_filename = sprintf '%s-%s-%s.txt', @$date{qw(year month day)};

        debug("check if $filename and $new_filename is same basename?");
        unless (basename($filename) eq basename($new_filename)) {
            puts("rename $filename -> $new_filename");
            rename $filename, File::Spec->catfile(dirname($filename), $new_filename)
                or error("$filename: Can't rename $filename $new_filename");
        }
    };

    if ($opt->{'a|all'}) {
        my $dir = @$args ? $args->[0] : $self->txt_dir;
        my @entry = $self->get_entries($dir);
        unless (@entry) {
            puts("$dir: no entries");
            return;
        }
        for (@entry) {
            $revert->($_);
        }

    }
    elsif (@$args) {
        unless (-f $args->[0]) {
            error($args->[0].":$!");
        }
        $revert->($args->[0]);

    }
    else {
        $self->arg_error;
    }
}

# update 'touch.txt'
sub touch {
    my ($self, $args) = @_;

    my $filename = File::Spec->catfile($self->txt_dir, 'touch.txt');
    my $FH = FileHandle->new($filename, 'w') or error("$filename:$!");
    # NOTE: I assume that this format is compatible
    # between Date::Manip::UnixDate and POSIX::strftime.
    my $touch_fmt = '%Y%m%d%H%M%S';

    if (@$args) {
        require_modules(qw(Date::Manip));
        Date::Manip->import(qw(ParseDate UnixDate));
        # NOTE: this parser is not compatible with 'rake touch <string>'.
        $FH->print(UnixDate(ParseDate(shift @$args), $touch_fmt));
    }
    else {
        $FH->print(POSIX::strftime($touch_fmt, localtime));
    }

    $FH->close;
}

# generate htmls from entry files
sub gen_html {
    my ($self, $args, $opt) = @_;

    my $make_index = $opt->{'i|update-index'};
    my $index_tmpl = $opt->{'I=s'};
    my $missing_only = $opt->{'m|missing-only'};

    # prereq modules.
    require_modules(qw(Text::Hatena));

    # both are directories, or both are files.
    my ($in, $out) = @$args;
    if (! defined $in || ! defined $out) {
        $self->arg_error;
    }


    my $gen_html = sub {
        my ($in, $out) = @_;
        unless (defined $self->get_entrydate($in)) {
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

        puts("gen_html: $in -> $out");

        my $OUT = FileHandle->new($out, 'w') or error("$out:$!");
        $OUT->print($html) or error("can't write to $html");
        $OUT->close;
    };

    if (-d $in && (-d $out || ! -e $out)) {
        unless (-e $out) {
            mkdir $out;
        }

        for my $infile ($self->get_entries($in)) {
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
        }
        elsif ($make_index) {
            $self->dispatch('update-index' => [$out]);
        }

    }
    elsif (-f $in && (-f $out || ! -e $out)) {
        $gen_html->($in, $out);

        if ($make_index) {
            $self->dispatch('update-index' => [dirname($out)]);
        }

    }
    else {
        # arguments error. show help.
        $self->arg_error;
    }
}

# make html from template file by HTML::Template
sub update_index {
    my ($self, $args, $opt) = @_;

    my $max_strlen;
    if (defined $opt->{'m|max-length=s'}) {
        $max_strlen = $opt->{'m|max-length=s'};
    }
    else {
        $max_strlen = 200;
    }


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
        for my $path ($self->get_entries($html_dir, '*')) {
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
                }
                else {
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
                        if (blessed($elem) && $elem->isa('HTML::Element')) {
                            next    if lc($elem->tag) eq 'h3';    # Skip headline
                            @_ = ([$elem->content_list, @$elements], $text);
                            goto &$as_text;
                        }
                        else {
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
        }
        else {
            $update_index_main->(dirname($path), $path);
        }

    }
    elsif (-d $path) {
        my $index_tmpl = File::Spec->catfile($path, 'index.tmpl');
        $update_index_main->($path, $index_tmpl);

    }
    else {
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
            }
            else {
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

# TODO ヘルプ書く
sub diff {
    my ($self, $args, $opt) = @_;

    my $dir = $opt->{'d|dir=s'};
    my $file = $opt->{'f|file=s'};

    if (defined $dir) {
        $self->txt_dir = $dir;
    }


    my $diff = sub {
        my ($year, $month, $day) = $self->parse_date(shift);

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

        my $filename = $self->text_filename($year, $month, $day);
        my $cmd = "diff $tmpfilename $filename";
        system $cmd;
    };


    if (defined $file) {
        # check if $file is entry file
        unless (-f $file) {
            error("$file: $!");
        }
        my $date = $self->get_entrydate($file);
        unless (defined $date) {
            error("$file: not entry file");
        }

        $diff->(
            sprintf '%s-%s-%s', $date->{year}, $date->{month}, $date->{day}
        );
    }
    elsif (@$args) {
        $diff->($args->[0]);
    }
    else {
        for (map { basename($_) } $self->get_updated_entries()) {
            $diff->($_);
        }
    }
}


{
    my %shell_cmd;
    my $dwarn;
    my $grep_cmd;
    my $term;
    my $initialized;


    # TODO write help
    sub shell {
        my ($self, $args) = @_;


        # initialize here for $self.
        unless ($initialized) {
            # define built-in commands.
            %shell_cmd = (
                quit => sub { goto EXIT_LOOP },
                q => sub { $shell_cmd{quit}->(@_) },
                '?' => sub {
                    puts("shell built-in commands here:");
                    puts("  $_") for keys %shell_cmd;
                    puts();
                    puts("if you want to see the help of hww's commands, type 'help'.");
                    STDOUT->flush;
                },
                h => sub { $shell_cmd{'?'}->() },
            );

            # for debug.
            $dwarn = sub {
                return unless $self->is_debug;
                warn @_, "\n";
                sleep 1;
            };

            # find commands in $all_options.
            # e.g.:
            # $incomp_cmd: di
            # $all_options: { diff => { ... }, help => { ...}, ... }
            $grep_cmd = sub {
                my ($incomp_cmd, $all_options) = @_;
                grep {
                    if ($self->is_debug) {
                        STDERR->print(
                            "match [$_]? ", ($incomp_cmd eq substr($_, 0, length $incomp_cmd)), "\n"
                        )
                    }
                    $incomp_cmd eq substr($_, 0, length $incomp_cmd)
                } keys %$all_options;
            };

            $term = Term::ReadLine->new;

            # define completion function!
            $term->Attribs->{completion_function} = sub {
                my ($prev_word, $cur_text, $str_len) = @_;
                my $completed = $cur_text =~ / $/;

                unless (is_complete_str($cur_text)) {
                    $dwarn->("[$cur_text] is not complete string. skip...");
                    return undef;
                }

                # all commands
                my @commands = keys %HWW_COMMAND;


                my @args = shell_eval_str($cur_text);
                if (@args == 0) {
                    return @commands
                }

                my $last_args = $args[-1];
                if (@$last_args == 0) {
                    return @commands;
                }
                $dwarn->(join '', map { "[$_]" } @$last_args);


                if ($last_args->[0] eq 'help') {
                    # stop completion
                    # unless num of args is 1, or num of args is 2 and not completed
                    return undef
                        unless @$last_args == 1 || (@$last_args == 2 && ! $completed);
                    # if arg 1 'help' is not completed, return it
                    return $last_args->[0]
                        if $prev_word eq 'help' && ! $completed;
                    # or return all commands
                    return @commands;
                }
                # complete command
                elsif (is_hww_command($last_args->[0])) {
                    return $last_args->[0]
                        if $prev_word eq $last_args->[0] && ! $completed;

                    # complete options
                    # XXX not completed...
                    my $options = $HWW_COMMAND{ $last_args->[0] }{option};
                    if (@$last_args >= 2 && $last_args->[-1] =~ /^(--?)(.*)$/) {
                        my ($bar, $opt) = ($1, $2);
                        $dwarn->("matced!:[$opt]");

                        if (length $opt) {
                            $dwarn->("grep options");
                            return map { $bar.$_ } $grep_cmd->($opt, $options);
                        }
                        else {
                            $dwarn->("all options");
                            return map { $bar.$_ } keys %$options;
                        }
                    }
                    return undef;
                }
                # incomplete command
                elsif (my @match = $grep_cmd->($last_args->[0], \%HWW_COMMAND)) {
                    return @match;
                }

                $dwarn->("no more completion...");
                return undef;
            };

            debug("initialized shell...");
            $initialized = 1;
        }


        local $HWWrapper::Hook::BuiltinFunc::exit = sub (;$) {
            warning("program exited with ".(@_ ? $_[0] : 0));
        };

        my $readline; $readline = sub {
            my $line = $term->readline("> ");
            # EOF for the first time
            unless (defined $line) {
                # exit shell
                return undef;
            }
            elsif ($line =~ /^\s*$/) {
                # retry to read line.
                goto &$readline;
            }

            # read lines until $line is complete
            until (is_complete_str($line)) {
                if (length $line && substr($line, -1, 1) eq  "\\") {
                    chop $line;
                }

                debug("reading next line...[$line]");
                my $l = $term->readline("");

                # EOF
                return $line unless defined $l;
                $line .= $l;
            }

            return $line;
        };


        # EOF (or q or quit) to leave shell.
        SHELL:
        while (defined(my $line = $readline->())) {

            debug("eval...[$line]");
            DISPATCH:
            for my $shell_args (shell_eval_str($line)) {
                debug(sprintf "process %s...", dumper($shell_args));

                my ($cmd, @cmd_args) = @$shell_args;

                if ($cmd eq 'shell') {
                    warning("you have been already in the shell.");
                    last DISPATCH;
                }
                elsif (is_hww_command($cmd)) {
                    eval {
                        $self->dispatch($cmd => \@cmd_args);
                    };
                }
                elsif (exists $shell_cmd{$cmd}) {
                    eval {
                        $shell_cmd{$cmd}->(\@cmd_args);
                    };
                }
                else {
                    # I can emulate 'correct' in zsh by using familiar_words().
                    # but that might be annoying if that's default.
                    my @familiar = familiar_words(
                        $cmd,
                        [
                            keys(%HWW_COMMAND),
                            keys(%shell_cmd),
                        ],
                        {
                            diff_strlen => 4,
                            partial_match_len => 3,
                        },
                    );

                    if (@familiar) {
                        # so currently I just suggest that words.
                        puts("\nDid you mean this?");
                        puts("\t$_") for @familiar;
                    }
                    else {
                        warning("$cmd: command not found");
                    }
                }

                warning($@) if $@;
            }
        }

        EXIT_LOOP:
    }
}

# TODO write help
sub truncate_cmd {
    my ($self, $args) = @_;

    my $all;
    $self->get_opt($args, {
        all => \$all,
        a => \$all,
    }) or $self->arg_error();


    my $truncate = sub {
        my $file = shift;

        my $FH = FileHandle->new($file, 'r') or error("$file: $!");
        my ($title, @body) = <$FH>;
        $FH->close;

        # find the line number of the top or bottom of blank lines.
        my $first = first_index { not /^\s*$/ } @body;
        my $last  = last_index { not /^\s*$/ } @body;

        # no waste blank lines.
        if ($first == 0 && $last == $#body) {
            return;
        }
        puts("$file: found waste blank lines...");

        # remove waste blank lines.
        debug("truncate: [0..$#body] -> [$first..$last]");
        @body = @body[$first .. $last];

        # write result.
        $FH = FileHandle->new($file, 'w') or error("$file: $!");
        $FH->print($title);
        $FH->print($_) for @body;
        $FH->close;
    };


    if ($all) {
        if (@$args) {
            $self->txt_dir = shift @$args;
        }
        unless (-d $self->txt_dir) {
            mkdir $self->txt_dir or error($self->txt_dir.": $!");
        }

        for my $entrypath ($self->get_entries($self->txt_dir)) {
            debug($entrypath);
            $truncate->($entrypath);
        }
    }
    else {
        unless (@$args) {
            $self->arg_error();
        }

        my $file = shift @$args;
        unless (-f $file) {
            error("$file: $!");
        }

        $truncate->($file);
    }
}

sub editor {
    my ($self, $args, $opt) = @_;

    my $is_gui_prog = $opt->{'g|gui'};

    unless (exists $ENV{EDITOR}) {
        error("set 'EDITOR' environment variable.");
    }
    my $editor = $ENV{EDITOR};
    my ($year, $month, $day) = (localtime)[5, 4, 3];
    $year  += 1900;
    $month += 1;
    my $entrypath = $self->text_filename($year, $month, $day);
    my $exist_entry = (-f $entrypath);
    my $mtime       = (-M $entrypath);


    puts("opening editor...");

    if ($is_gui_prog) {
        require_modules(qw(IPC::Run));

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

                debug("exiting with -1...");
                exit -1;
            };
        } 0 .. $#sig_to_trap;

        # spawn editor program.
        debug("start [$editor $entrypath]...");
        $editor_proc->start;
        debug("finish [$editor $entrypath]...");
        $editor_proc->finish;
        debug("done.");
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

1;
