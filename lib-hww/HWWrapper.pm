package HWWrapper;

use strict;
use warnings;
use utf8;

our $VERSION = '1.5.0';

use base qw(HW);
# import all util commands!!
use HWWrapper::UtilSub::Functions;


use Carp;
use File::Spec;
use Pod::Usage;
use File::Basename qw(dirname basename);
use FileHandle;
use Scalar::Util qw(blessed);
use POSIX ();
use Regexp::Assemble;
use Term::ReadLine;



use FindBin qw($Bin);
our $HWW_LIB = "$Bin/lib-hww";


# command vs subname
our %HWW_COMMAND = (
    help => 'help',
    version => 'version',
    copyright => 'copyright',
    init => 'init',
    release => 'release',
    update => 'update',
    load => 'load',
    verify => 'verify',
    status => 'status',
    'apply-headline' => 'apply_headline',
    'revert-headline' => 'revert_headline',
    touch => 'touch',
    'gen-html' => 'gen_html',
    'update-index' => 'update_index',
    chain => 'chain',
    diff => 'diff',
    shell => 'shell',

    # TODO commands to manipulate tags.
    # 'add-tag' => 'add_tag',
    # 'delete-tag' => 'delete_tag',
    # 'rename-tag' => 'rename_tag',

    # TODO 現在の日記ファイルを作ってエディタで開くコマンド
    # TODO 設定(ファイルはconfig-hww.txt)を変えるコマンド
    # config => 'config',
);

our $debug = 0;
our $debug_stderr = 0;
our $no_cookie = 0;


# TODO
# - コマンドのヘルプドキュメント書く
# - HWのサブルーチンをHatena AtomPub APIを使うように書き換える
# - コマンド名をミスった場合に空気呼んで似てるコマンドを呼び出すか訊く (zshのcorrectみたいに)
# - $selfがblessedされてるかチェックするアトリビュート
#
# - config-hww.txtにHWWrapperの設定を書く
# -- フォーマットはYAML
# (YAML::XSとYAMLは互換性がないらしい。XSを使うのはWindowsにとって厳しいのでYAMLモジュールを使う)
# -- $EDITORの設定
# -- hww.plに常に付ける引数(.provercや.ctagsみたいな感じ)

# XXX
# - save_diary_draft()がクッキーを使ってログインできてない気がする
# (一回ログインした次が401 Authorizedになる)
# -- それLWP::Authen::Wsse使ってるからじゃ・・・
# -- 違った。はてなのAtomPub APIがcookieでの認証廃止したからだった。
# 受け取ったcookieは即expiredになる。

# NOTE
# - new()で設定のデフォルト値をセットして
# - load_config()で設定ファイルの値をセットして
# - parse_opt()で引数の値をセット






### new() ###

sub new {
    my $pkg = shift;
    if (blessed $pkg) {
        croak "you have already been initialized!";
    }

    my $self = bless { @_ }, $pkg;

    if (exists $self->{args}) {
        my ($opts, $cmd, $cmd_args) = split_opt(@{ $self->{args} });
        $self->{args} = {
            options => $opts,
            command => $cmd,
            command_args => $cmd_args,
        };
    }
    else {
        croak "currently 'args' option is required!!";
    }


    $self->{config} = {
        # this option is default to 1.
        # to make this false, pass '-C' or '--no-cookie' option.
        use_cookie => 1,

        is_debug => 0,
    };
    $self->{arg_opt}{HWWrapper} = {
        d => \$debug,
        debug => \$debug,

        D => \$debug_stderr,
        'debug-stderr' => \$debug_stderr,

        C => \$no_cookie,
        'no-cookie' => \$no_cookie,
    };

    # initialize config of HW.
    $self->SUPER::new;

    # make accessors.
    #
    # $self->$method
    # is lvalue method and identical to
    # $self->{config}{$method}
    $self->mk_accessors(keys %{ $self->{config} });


    return $self;
}



### load_config() ###

sub load_config {
    my $self = shift;

    my $config_file = 'config-hww.txt';
    $self->get_opt_only($self->{args}{options}, {
        'N=s' => \$config_file,
        'config-hww=s' => \$config_file,
    }) or error("arguments error");

    if (-f $config_file) {
        # TODO
    }
    else {
        debug("$config_file is not found. skip to load config...");
    }


    $self->SUPER::load_config;
}



### parse_opt() ###

# this is additinal options which I added.
# not hw.pl's options.
# TODO
# DO NOT DEPEND ON %HW::arg_opt !
# THAT HAS BEEN DELETED ALREADY!!
# our %hw_opt_long = (
#     trivial => \$HW::arg_opt{t},
#     'username=s' => \$HW::arg_opt{u},
#     'password=s' => \$HW::arg_opt{p},
#     'agent=s' => \$HW::arg_opt{a},
#     'timeout=s' => \$HW::arg_opt{T},
#     'group=s' => \$HW::arg_opt{g},
#     'file=s' => \$HW::arg_opt{f},
#     'no-replace' => \$HW::arg_opt{M},
#     'config-file=s' => \$HW::arg_opt{n},
# );

sub parse_opt {
    my $self = shift;
    unless (blessed $self) {
        croak 'give me blessed $self.';
    }
    unless (exists $self->{args}) {
        croak "you did not passed 'args' option to HWWrapper->new().";
    }

    my $options = $self->{args}{options};
    my $cmd = $self->{args}{command};
    my $cmd_args = $self->{args}{command_args};

    return ($cmd, $cmd_args) unless @$options;


    # parse hww.pl's options.
    $self->get_opt_only(
        $options,
        $self->{arg_opt}{HWWrapper}
    ) or do {
        warning("arguments error");
        sleep 1;
        $self->dispatch('help');
        exit -1;
    };

    $self->use_cookie = ! $no_cookie;
    $self->is_debug   = ($debug || $debug_stderr);

    # option arguments result handling
    if ($debug) {
        print ${ $DEBUG->string_ref };    # flush all
        $DEBUG = *STDOUT;
    }
    elsif ($debug_stderr) {
        warning(${ $DEBUG->string_ref });    # flush all
        $DEBUG = *STDERR;
    }
    else {
        $DEBUG = FileHandle->new(File::Spec->devnull, 'w') or error("Can't open null device.");
    }


    # parse HW 's options.
    if (@$options) {
        $self->SUPER::parse_opt();
    }


    return ($cmd, $cmd_args);
}



### dispatch() ###

sub dispatch {
    my $self = shift;
    my ($cmd, $args) = @_;
    $args = [] unless defined $args;

    unless (blessed $self) {
        croak 'give me blessed $self.';
    }

    # detect some errors.
    unless (defined $cmd) {
        error("no command was given.");
    }
    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    # some debug messages.
    my ($filename, $line) = (caller)[1,2];
    $filename = basename($filename);
    debug(sprintf '$self->dispatch(%s) at %s line %s',
            join(', ', map { dumper($_) } @_), $filename, $line);


    my $subname = $HWW_COMMAND{$cmd};
    $self->$subname($args);
}

### dispatch_with_args() ###

sub dispatch_with_args {
    my $self = shift;
    my @argv = @_;

    unless (blessed($self)) {
        croak 'give me blessed $self.';
    }
    unless (exists $self->{args}) {
        croak 'you have not passed args option.';
    }


    # currently this calls HW::load_config() directly.
    $self->load_config;

    # parse options in @_
    my ($cmd, $cmd_args) = $self->parse_opt(@argv);

    # for memory
    # delete $self->{arg_opt};

    $self->dispatch(defined $cmd ? $cmd : 'help', $cmd_args);
}



### hww commands ###

# display help information about hww
sub help {
    my ($self, $args) = @_;
    my $cmd = shift @$args;


    unless (defined $cmd) {
        pod2usage(-verbose => 1, -input => $0, -exitval => "NOEXIT");
        
        puts("available commands:");
        for my $command (sort keys %HWW_COMMAND) {
            puts("  $command");
        }
        puts();
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

sub copyright {
    # hw.pl
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
    my ($self, $args) = @_;

    my $txt_dir = "text";
    my $config_file = "config.txt";
    my $cookie_file = "cookie.txt";

    my $read_config;
    $self->get_opt($args, {
        config => \$read_config,
        c => \$read_config,
    });

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
        # make empty file
        my $TOUCH = FileHandle->new($cookie_file, 'w') or error("$cookie_file:$!");
        $TOUCH->close;
    }

    chmod 0600, $cookie_file;
}

# upload entries to hatena diary
sub release {
    my ($self, $args) = @_;

    my $trivial;
    $self->get_opt($args, {
        trivial => \$trivial,
        t => \$trivial,
    });
    $self->trivial = $trivial;

    my $dir = shift @$args;
    if (defined $dir) {
        $self->txt_dir = $dir;
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
    $self->get_opt($args, {
        all => \$all,
        a => \$all,
        draft => \$draft,
        d => \$draft,
        # TODO comparing each entries, and it's different, fetch it.
        # 'compare' => \$compare,
        # 'c' => \$compare,
        'missing-only' => \$missing_only,
        m => \$missing_only,
    }) or error("arguments error");


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
    else {
        if (defined(my $ymd = shift(@$args))) {
            $self->SUPER::load($ymd);
        }
        else {
            $self->arg_error;
        }
    }
}

# verify misc information
# NOTE: currently only checking duplicated entries.
sub verify {
    my ($self, $args) = @_;

    my $verify_html;
    $self->get_opt($args, {
        html => \$verify_html,
    });

    my $dir = shift(@$args);
    my $fileglob;
    if ($verify_html) {
        $fileglob = '*.html';
    }


    my @entry = $self->get_entries($dir, $fileglob);
    unless (@entry) {
        $dir = defined $dir ? $dir : $self->txt_dir;
        puts("$dir: no entries found.");
        exit 0;
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
            puts("foo:$ymd, $file");
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
    my ($self, $args) = @_;

    my $all;
    my $no_caption;
    $self->get_opt($args, {
        all => \$all,
        a => \$all,
        C => \$no_caption,
        'no-caption' => \$no_caption,
    });

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
    my ($self, $args) = @_;

    my $all;
    $self->get_opt($args, {
        all => \$all,
        a => \$all,
    });


    my $apply = sub {
        error;
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

    if ($all) {
        my $dir = @$args ? $args->[0] : $self->txt_dir;
        my @entry = $self->get_entries($dir);
        unless (@entry) {
            puts("$dir: no entries");
            exit;
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
    my ($self, $args) = @_;

    my $all;
    $self->get_opt($args, {
        all => \$all,
        a => \$all,
    });


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

    if ($all) {
        my $dir = @$args ? $args->[0] : $self->txt_dir;
        my @entry = $self->get_entries($dir);
        unless (@entry) {
            puts("$dir: no entries");
            exit;
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
    my ($self, $args) = @_;

    my $make_index;
    my $index_tmpl;
    my $missing_only;
    $self->get_opt($args, {
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
        unless (defined $self->get_entrydate($in)) {
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
    my ($self, $args) = @_;

    my $max_strlen = 200;
    $self->get_opt($args, {
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
                        if (Scalar::Util::blessed($elem) && $elem->isa('HTML::Element')) {
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
    my ($self, $args) = @_;

    # TODO
    # ディレクトリやファイルを受け取るようにする(オプションで)

    if (@$args) {
        $self->SUPER::diff($args->[0]);
    }
    else {
        for (map { basename($_) } $self->get_updated_entries()) {
            $self->SUPER::diff($_);
        }
    }
}


{
    my $initialized = 0;
    my %shell_cmd;
    my $shell_cmd_re;

    # TODO rewrite help
    sub shell {
        my ($self, $args) = @_;

        unless ($initialized) {
            %shell_cmd = (
                'q(?:uit)?' => sub { exit },
            );
            # match word.
            %shell_cmd = map { '\\b'.$_.'\\b' => $shell_cmd{$_} } keys %shell_cmd;

            $shell_cmd_re = Regexp::Assemble->new->track->add(keys %shell_cmd);

            $initialized = 1;
        }

        my $term = Term::ReadLine->new;
        # TODO write completion subroutine


        # EOF (or q or quit) to leave shell.
        SHELL:
        while (defined(my $line = $term->readline("> "))) {
            next SHELL if $line =~ /^\s*$/;

            DISPATCH:
            for my $shell_args (shell_eval_string($line)) {
                my ($cmd, @cmd_args) = @$shell_args;

                if (is_hww_command($cmd)) {
                    $self->dispatch($cmd => \@cmd_args);
                }
                elsif ($shell_cmd_re->match($cmd)) {
                    $shell_cmd{$shell_cmd_re->matched}->(\@cmd_args);
                }
                else {
                    STDERR->print("$cmd: command not found\n");
                    last DISPATCH;
                }
            }
        }
    }
}


1;
