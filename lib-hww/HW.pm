#!/usr/bin/perl
#
# hw.pl - Hatena Diary Writer (with Loader).
#
# Copyright (C) 2004,2005,2007 by Hiroshi Yuki.
# <hyuki@hyuki.com>
# http://www.hyuki.com/techinfo/hatena_diary_writer.html
#
# Special thanks to:
# - Ryosuke Nanba http://d.hatena.ne.jp/rna/
# - Hahahaha http://www20.big.or.jp/~rin_ne/
# - Ishinao http://ishinao.net/
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# 'Hatena Diary Loader' originally written by Hahahaha(id:rin_ne)
#    http://d.hatena.ne.jp/rin_ne/20040825#p7
#
# Modified by Kengo Koseki (id:koseki2)
#    http://d.hatena.ne.jp/koseki2/
#
package HW;

use strict;
use warnings;
our $VERSION = "1.5.5";

use HWWrapper::UtilSub;


use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use File::Basename;
use Getopt::Std;
use Digest::MD5 qw(md5_base64);
use File::Temp qw(tempdir tempfile);
use File::Spec;
use Pod::Usage;

our $enable_encode = eval('use Encode; 1');

use subs qw(
    login
    get_rkm
    logout
    update_diary_entry
    delete_diary_entry
    doit_and_retry
    create_it
    delete_it
    post_it
    get_timestamp
    read_title_body
    find_image_file
    replace_timestamp
    load_config
);

# Hatena user id (if empty, I will ask you later).
our $username = '';
# Hatena password (if empty, I will ask you later).
our $password = '';
# Hatena group name (for hatena group user only).
our $groupname = '';

# Default file names.
our $touch_file = 'touch.txt';
our $cookie_file = 'cookie.txt';
our $config_file = 'config.txt';
our $target_file = '';

# Load diary date.
our $load_date = '';
# Diff diary date.
our $diff_date = '';

# Filter command.
# e.g. 'iconv -f euc-jp -t utf-8 %s'
# where %s is filename, output is stdout.
our $filter_command = '';

# Proxy setting.
our $http_proxy = '';

# Directory for "YYYY-MM-DD.txt".
our $txt_dir = ".";

# Client and server encodings.
our $client_encoding = '';
our $server_encoding = '';

# Hatena URL.
our $hatena_url = 'http://d.hatena.ne.jp';
our $hatena_sslregister_url = 'https://www.hatena.ne.jp/login';

# Crypt::SSLeay check.
eval {
    require Crypt::SSLeay;
};
if ($@) {
    puts("WARNING: Crypt::SSLeay is not found, use non-encrypted HTTP mode.");
    $hatena_sslregister_url = 'http://www.hatena.ne.jp/login';
}

# Option for LWP::UserAgent.
our %ua_option = (
    agent => "HatenaDiaryWriter/$VERSION", # "Mozilla/5.0",
    timeout => 180,
);

# Other variables.
our $delete_title = 'delete';
our $cookie_jar;
our $user_agent;
our $rkm; # session id for posting.

# Handle command-line option.
# TODO move this into hww.pl
our %cmd_opt = (
    'd' => 0,   # "debug" flag.
    't' => 0,   # "trivial" flag.
    'u' => "",  # "username" option.
    'p' => "",  # "password" option.
    'a' => "",  # "agent" option.
    'T' => "",  # "timeout" option.
    'c' => 0,   # "cookie" flag.
    'g' => "",  # "groupname" option.
    'f' => "",  # "file" option.
    'M' => 0,   # "no timestamp" flag.
    'n' => "",  # "config file" option.
    'S' => 1,   # "SSL" option. This is always 1. Set 0 to login older hatena server.
    'l' => "",  # "load" diary.
    'D' => "",  # "diff" option.
);


if ($0 eq __FILE__) {
    # Start.
    # if ($cmd_opt{l}) {
    #     load_main();    # now load()
    # } elsif ($cmd_opt{D}) {
    #     diff_main();
    # } else {
    #     main();    # now release()
    # }

    # no-error exit.
    exit(0);
}




sub parse_opt {
    my $self = shift;
    local @ARGV = @_;

    local $Getopt::Std::STANDARD_HELP_VERSION = 1;
    getopts("tdu:p:a:T:cg:f:Mn:l:D:", \%cmd_opt) or error("Unknown option.");

    if ($cmd_opt{d}) {
        debug("Debug flag on.");
        debug("Cookie flag on.") if $cmd_opt{c};
        debug("Trivial flag on.") if $cmd_opt{t};
        VERSION_MESSAGE();
    }

    # Override config file name (before load_config).
    $config_file = $cmd_opt{n} if $cmd_opt{n};

    # Override global vars with config file.
    $self->load_config() if -e($config_file);

    # Override global vars with command-line options.
    $username = $cmd_opt{u} if $cmd_opt{u};
    $password = $cmd_opt{p} if $cmd_opt{p};
    $groupname = $cmd_opt{g} if $cmd_opt{g};
    $ua_option{agent} = $cmd_opt{a} if $cmd_opt{a};
    $ua_option{timeout} = $cmd_opt{T} if $cmd_opt{T};
    $target_file = $cmd_opt{f} if $cmd_opt{f};
    $load_date = $cmd_opt{l} if $cmd_opt{l};
    $diff_date = $cmd_opt{D} if $cmd_opt{D};

    # Change $hatena_url to Hatena group URL if ($groupname is defined).
    if ($groupname) {
        $hatena_url = "http://$groupname.g.hatena.ne.jp";
    }
}

# Load diary main sequence. -l option
sub load {
    my $self = shift;
    my ($year, $month, $day) = $self->parse_date($load_date);

    # Login if necessary.
    $self->login() unless ($user_agent);

    puts("Load $year-$month-$day.");
    my ($title, $body) = $self->load_diary_entry($year,$month,$day);
    $self->save_diary_entry($year,$month,$day,$title,$body);
    puts("Load OK.");

    $self->logout() if ($user_agent);
}

sub diff_main {
    my $self = shift;
    my ($year, $month, $day) = $self->parse_date($diff_date);

    # Login if necessary.
    $self->login() unless ($user_agent);

    puts("Diff $year-$month-$day.");
    my ($title, $body) = $self->load_diary_entry($year,$month,$day);
    $self->logout() if ($user_agent);

    my $src = $title."\n".$body;

    my $tmpdir = tempdir(CLEANUP => 1);
    my($fh, $tmpfilename) = tempfile('diff_XXXXXX', DIR => $tmpdir);
    print $fh $src;
    close $fh;

    my $filename = $self->text_filename($year,$month,$day);
    my $cmd = "diff $tmpfilename $filename";
    system $cmd;
}

sub parse_date($) {
    my $self = shift;
    my ($date) = @_;
    if ($date !~ /\A(\d\d\d\d)-(\d\d)-(\d\d)(?:-.+)?(?:\.txt)?\Z/) {
        error("Illegal date format.");
    }
    return ($1, $2, $3);
}

# Main sequence.
sub release {
    my $self = shift;
    my $count = 0;
    my @files;

    # Setup file list.
    if ($cmd_opt{f}) {
        # Do not check timestamp.
        push(@files, $cmd_opt{f});
        debug("release: files: option -f: @files");
    } else {
        while (glob("$txt_dir/*.txt")) {
            # Check timestamp.
            next if (-e($touch_file) and (-M($_) > -M($touch_file)));
            push(@files, $_);
        }
        debug("release: files: current dir ($txt_dir): @files");
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
        $self->login() unless ($user_agent);

        # Replace "*t*" unless suppressed.
        $self->replace_timestamp($file) unless ($cmd_opt{M});

        # Read title and body.
        my ($title, $body) = $self->read_title_body($file);

        # Find image files.
        my $imgfile = $self->find_image_file($file);

        if ($title eq $delete_title) {
            # Delete entry.
            puts("Delete $year-$month-$day.");
            $self->delete_diary_entry($date);
            puts("Delete OK.");
        } else {
            # Update entry.
            puts("Post $year-$month-$day.  " . ($imgfile ? " (image: $imgfile)" : ""));
            $self->update_diary_entry($year, $month, $day, $title, $body, $imgfile);
            puts("Post OK.");
        }

        sleep(1);

        $count++;
    }

    # Logout if necessary.
    $self->logout() if ($user_agent);

    if ($count == 0) {
        puts("No files are posted.");
    } else {
        unless ($cmd_opt{f}) {
            # Touch file.
            my $FILE;
            open($FILE, "> $touch_file") or die "$!:$touch_file\n";
            print $FILE $self->get_timestamp();
            close($FILE);
        }
    }
}

# Login.
sub login() {
    my $self = shift;
    $user_agent = LWP::UserAgent->new(%ua_option);
    $user_agent->env_proxy;
    if ($http_proxy) {
        $user_agent->proxy('http', $http_proxy);
        debug("login: proxy for http: $http_proxy");
        $user_agent->proxy('https', $http_proxy);
        debug("login: proxy for https: $http_proxy");
    }

    # Ask username if not set.
    unless ($username) {
        print "Username: ";
        chomp($username = <STDIN>);
    }

    # If "cookie" flag is on, and cookie file exists, do not login.
    if ($cmd_opt{c} and -e($cookie_file)) {
        debug("login: Loading cookie jar.");

        $cookie_jar = HTTP::Cookies->new;
        $cookie_jar->load($cookie_file);
        $cookie_jar->scan(\&get_rkm);

        debug("login: \$cookie_jar = " . $cookie_jar->as_string);

        puts("Skip login.");

        return;
    }

    # Ask password if not set.
    unless ($password) {
        print "Password: ";
        chomp($password = <STDIN>);
    }

    my %form;
    $form{name} = $username;
    $form{password} = $password;

    my $r; # Response.
    if ($cmd_opt{S}) {
        my $diary_url = "$hatena_url/$username/";

        $form{backurl} = $diary_url;
        $form{mode} = "enter";
        if ($cmd_opt{c}) {
            $form{persistent} = "1";
        }

        puts("Login to $hatena_sslregister_url as $form{name}.");

        $r = $user_agent->simple_request(
            HTTP::Request::Common::POST("$hatena_sslregister_url", \%form)
        );

        debug("login: " . $r->status_line);

        debug("login: \$r = " . $r->content());
    } else {
        # For older version.

        puts("Login to $hatena_url as $form{name}.");
        $r = $user_agent->simple_request(
            HTTP::Request::Common::POST("$hatena_url/login", \%form)
        );

        debug("login: " . $r->status_line);

        if (not $r->is_redirect) {
            error("Login: Unexpected response: ", $r->status_line);
        }
    }

    # Check to exist <meta http-equiv="refresh" content="1;URL=..." />
    unless (defined $r->header('refresh')) {
        debug("failed to login. retry...");
        # $username = '';    # needless?
        $password = '';
        # Retry to login.
        @_ = ($self);
        goto &login;
    }

    puts("Login OK.");

    debug("login: Making cookie jar.");

    $cookie_jar = HTTP::Cookies->new;
    $cookie_jar->extract_cookies($r);
    $cookie_jar->save($cookie_file);
    $cookie_jar->scan(\&get_rkm);

    debug("login: \$cookie_jar = " . $cookie_jar->as_string);
}

# get session id.
sub get_rkm($$$$$$$$$$$) {
    # NOTE: no $self
    my ($version, $key, $val) = @_;
    if ($key eq 'rk') {
        $rkm = md5_base64($val);
        debug("get_rkm: \$rkm = " . $rkm);
    }
}

# Logout.
sub logout() {
    my $self = shift;
    return unless $user_agent;

    # If "cookie" flag is on, and cookie file exists, do not logout.
    if ($cmd_opt{c} and -e($cookie_file)) {
        puts("Skip logout.");
        return;
    }

    my %form;
    $form{name} = $username;
    $form{password} = $password;

    puts("Logout from $hatena_url as $form{name}.");

    $user_agent->cookie_jar($cookie_jar);
    my $r = $user_agent->get("$hatena_url/logout");
    debug("logout: " . $r->status_line);

    if (not $r->is_redirect and not $r->is_success) {
        error("Logout: Unexpected response: ", $r->status_line);
    }

    unlink($cookie_file);

    puts("Logout OK.");
}

# Update entry.
sub update_diary_entry($$$$$$) {
    my $self = shift;
    my ($year, $month, $day, $title, $body, $imgfile) = @_;

    if ($cmd_opt{t}) {
        # clear existing entry. if the entry does not exist, it has no effect.
        $self->doit_and_retry("update_diary_entry: CLEAR.", sub { return $self->post_it($year, $month, $day, "", "", "") });
    }

    # Make empty entry before posting.
    $self->doit_and_retry("update_diary_entry: CREATE.", sub { return $self->create_it($year, $month, $day) });

    # Post.
    $self->doit_and_retry("update_diary_entry: POST.", sub { return $self->post_it($year, $month, $day, $title, $body, $imgfile) });
}

# Delete entry.
sub delete_diary_entry($) {
    my $self = shift;
    my ($date) = @_;

    # Delete.
    $self->doit_and_retry("delete_diary_entry: DELETE.", sub { return $self->delete_it($date) });
}

# Do the $funcref, and retry if fail.
sub doit_and_retry($$) {
    my $self = shift;
    my ($msg, $funcref) = @_;
    my $retry = 0;
    my $ok = 0;

    while ($retry < 2) {
        $ok = $funcref->();
        if ($ok or not $cmd_opt{c}) {
            last;
        }
        debug("try_it: $msg");
        unlink($cookie_file);
        puts("Old cookie. Retry login.");
        $self->login();
        $retry++;
    }

    if (not $ok) {
        error("try_it: Check username/password.");
    }
}

# Delete.
sub delete_it($) {
    my $self = shift;
    my ($date) = @_;

    debug("delete_it: $date");

    $user_agent->cookie_jar($cookie_jar);

    my $r = $user_agent->simple_request(
        HTTP::Request::Common::POST("$hatena_url/$username/edit",
            # Content_Type => 'form-data',
            Content => [
                mode => "delete",
                date => $date,
                rkm => $rkm,
            ]
        )
    );

    debug("delete_it: " . $r->status_line);

    if ((not $r->is_redirect()) and (not $r->is_success())) {
        error("Delete: Unexpected response: ", $r->status_line);
    }

    debug("delete_it: Location: " . $r->header("Location"));

    # Check the result. ERROR if the location ends with the date.
    # (Note that delete error != post error)
    if ($r->header("Location") =~ m(/$date$)) {                    # /)){
        debug("delete_it: returns 0 (ERROR).");
        return 0;
    } else {
        debug("delete_it: returns 1 (OK).");
        return 1;
    }
}

sub create_it($$$) {
    my $self = shift;
    my ($year, $month, $day) = @_;

    debug("create_it: $year-$month-$day.");

    $user_agent->cookie_jar($cookie_jar);

    my $r = $user_agent->simple_request(
        HTTP::Request::Common::POST("$hatena_url/$username/edit",
            Content_Type => 'form-data',
            Content => [
                mode => "enter",
                timestamp => $self->get_timestamp(),
                year => $year,
                month => $month,
                day => $day,
                trivial => $cmd_opt{t},
                rkm => $rkm,

                # Important:
                # If (entry does exists) { append empty string (i.e. nop) }
                # If (entry does not exist) { create empty entry }
                title => "",
                body => "",
                date => "",
            ]
        )
    );

    debug("create_it: " . $r->status_line);

    if ((not $r->is_redirect()) and (not $r->is_success())) {
        error("Create: Unexpected response: ", $r->status_line);
    }

    debug("create_it: Location: " . $r->header("Location"));

    # Check the result. OK if the location ends with the date.
    if ($r->header("Location") =~ m(/$year$month$day$)) {          # /)){
        debug("create_it: returns 1 (OK).");
        return 1;
    } else {
        debug("create_it: returns 0 (ERROR).");

        return 0;
    }
}

sub post_it($$$$$$) {
    my $self = shift;
    my ($year, $month, $day, $title, $body, $imgfile) = @_;

    debug("post_it: $year-$month-$day.");

    $user_agent->cookie_jar($cookie_jar);

    my $r = $user_agent->simple_request(
        HTTP::Request::Common::POST("$hatena_url/$username/edit",
            Content_Type => 'form-data',
            Content => [
                mode => "enter",
                timestamp => $self->get_timestamp(),
                year => $year,
                month => $month,
                day => $day,
                title => $title,
                trivial => $cmd_opt{t},
                rkm => $rkm,

                # Important:
                # This entry must already exist.
                body => $body,
                date => "$year$month$day",
                image => [
                    $imgfile,
                ]
            ]
        )
    );

    debug("post_it: " . $r->status_line);

    if (not $r->is_redirect) {
        error("Post: Unexpected response: ", $r->status_line);
    }

    debug("post_it: Location: " . $r->header("Location"));

    # Check the result. OK if the location ends with the date.
    if ($r->header("Location") =~ m(/$year$month$day$)) {          # /)){
        debug("post_it: returns 1 (OK).");
        return 1;
    } else {
        debug("post_it: returns 0 (ERROR).");
        return 0;
    }
}

# Get "YYYYMMDDhhmmss" for now.
sub get_timestamp() {
    my $self = shift;
    my (@week) = qw(Sun Mon Tue Wed Thu Fri Sat);
    my ($sec, $min, $hour, $day, $mon, $year, $weekday) = localtime(time);
    $year += 1900;
    $mon++;
    $mon = "0$mon" if $mon < 10;
    $day = "0$day" if $day < 10;
    $hour = "0$hour" if $hour < 10;
    $min = "0$min" if $min < 10;
    $sec = "0$sec" if $sec < 10;
    $weekday = $week[$weekday];
    return "$year$mon$day$hour$min$sec";
}

# Show version message. This is called by getopts.
sub VERSION_MESSAGE {
    # Do not print this message if '--help' was given.
    return if grep { $_ eq '--help' } @ARGV;
    print <<"EOD";
Hatena Diary Writer(+Loader) Version $VERSION
Copyright (C) 2004,2005,2007,2009 by Hiroshi Yuki / +Loader by Kengo Koseki.
EOD
}

# Read title and body.
sub read_title_body($) {
    my $self = shift;
    my ($file) = @_;

    # Execute filter command, if any.
    my $input = $file;
    if ($filter_command) {
        $input = sprintf("$filter_command |", $file);
    }
    debug("read_title_body: input: $input");
    my $FILE;
    if (not open($FILE, $input)) {
        error("$!:$input");
    }
    my $title = <$FILE>; # first line.
    chomp($title);
    my $body = join('', <$FILE>); # rest of all.
    close($FILE);

    # Convert encodings.
    if ($enable_encode and ($client_encoding ne $server_encoding)) {
        debug("Convert from $client_encoding to $server_encoding.");
        Encode::from_to($title, $client_encoding, $server_encoding);
        Encode::from_to($body, $client_encoding, $server_encoding);
    }

    return($title, $body);
}

# Find image file.
sub find_image_file($) {
    my $self = shift;
    my ($fulltxt) = @_;
    my ($base, $path, $type) = fileparse($fulltxt, qr/\.txt/);
    for my $ext ('jpg', 'png', 'gif') {
        my $imgfile = "$path$base.$ext";
        if (-e $imgfile) {
            if ($cmd_opt{f}) {
                debug("find_image_file: -f option, always update: $imgfile");
                return $imgfile;
            } elsif (-e($touch_file) and (-M($imgfile) > -M($touch_file))) {
                debug("find_image_file: skip $imgfile (not updated).");
                next;
            } else {
                debug("find_image_file: $imgfile");
                return $imgfile;
            }
        }
    }
    return undef;
}

# Replace "*t*" with timestamp.
sub replace_timestamp($) {
    my $self = shift;
    my ($filename) = @_;

    # Read.
    my $FILE;
    open($FILE, $filename) or error("$!: $filename");
    my $file = join('', <$FILE>);
    close($FILE);

    # Replace.
    my $newfile = $file;
    $newfile =~ s/^\*t\*/"*" . time() . "*"/gem;

    # Write if replaced.
    if ($newfile ne $file) {
        debug("replace_timestamp: $filename");
        open($FILE, "> $filename") or error("$!: $filename");
        print $FILE $newfile;
        close($FILE);
    }
}

# Show help message. This is called by getopts.
sub HELP_MESSAGE {
    pod2usage(-verbose => 2);
}

# Load config file.
sub load_config() {
    my $self = shift;
    debug("Loading config file ($config_file).");
    my $CONF;
    if (not open($CONF, $config_file)) {
        error("Can't open $config_file.");
    }
    while (<$CONF>) {
        chomp;
        if (/^\#/) {
            # skip comment.
        } elsif (/^$/) {
            # skip blank line.
        } elsif (/^id:([^:]+)$/) {
            $username = $1;
            debug("load_config: id:$username");
        } elsif (/^g:([^:]+)$/) {
            $groupname = $1;
            debug("load_config: g:$groupname");
        } elsif (/^password:(.*)$/) {
            $password = $1;
            debug("load_config: password:********");
        } elsif (/^cookie:(.*)$/) {
            $cookie_file = glob($1);
            $cmd_opt{c} = 1; # If cookie file is specified, Assume '-c' is given.
            debug("load_config: cookie:$cookie_file");
        } elsif (/^proxy:(.*)$/) {
            $http_proxy = $1;
            debug("load_config: proxy:$http_proxy");
        } elsif (/^client_encoding:(.*)$/) {
            $client_encoding = $1;
            debug("load_config: client_encoding:$client_encoding");
        } elsif (/^server_encoding:(.*)$/) {
            $server_encoding = $1;
            debug("load_config: server_encoding:$server_encoding");
        } elsif (/^filter:(.*)$/) {
            $filter_command = $1;
            debug("load_config: filter:$filter_command");
        } elsif (/^txt_dir:(.*)$/) {
            $txt_dir = glob($1);
            debug("load_config: txt_dir:$txt_dir");
        } elsif (/^touch:(.*)$/) {
            $touch_file = glob($1);
            debug("load_config: touch:$touch_file");
        } else {
            error("Unknown command '$_' in $config_file.");
        }
    }
    close($CONF);
}


# from hateda loader

# Load entry.
sub load_diary_entry($$$) {
    my $self = shift;
    my ($year, $month, $day) = @_;

    debug("load_it: $hatena_url/$username/edit?date=$year$month$day");

    $user_agent->cookie_jar($cookie_jar);

    my $r = $user_agent->simple_request(
        HTTP::Request::Common::GET("$hatena_url/$username/edit?date=$year$month$day"));

    debug("load_it: " . $r->status_line);

    if (not $r->is_success()) {
        error("Load: Unexpected response: ", $r->status_line);
    }

    # Check entry exist.
    $r->content =~ /<form .*?action="\.\/edit" .*?>(.*<\/textarea>)/s;
    my $form_data = $1;

    $form_data =~ /<input type="hidden" name="date" value="(\d\d\d\d\d\d\d\d)">/;
    my $resp_date = $1;

    if($resp_date ne "$year$month$day") {
        error("Load: Not exist entry.");
    }
    
    # Get title and body.
    my $title = "";
    if ($form_data =~ /<input name="title" .*?value="(.*?)"/) {
        $title = $1;
    }
    $form_data =~ /<textarea .*?>(.*?)<\/textarea>/s;
    my $body = $1;

    # Unescape string.
    $title = $self->unescape($title);
    $body = $self->unescape($body);

    # Convert encodings.
    if ($enable_encode and ($client_encoding ne $server_encoding)) {
        debug("Convert from $client_encoding to $server_encoding.");
        Encode::from_to($title, $server_encoding, $client_encoding);
        Encode::from_to($body, $server_encoding, $client_encoding);
    }

    debug("load_it: OK");
    return ($title, $body);
}

sub text_filename($$$;$) {
    my $self = shift;
    my ($year,$month,$day, $headlines) = @_;
    my $datename;
    if (defined $headlines
        && ref $headlines eq 'ARRAY'
        && @$headlines) {
        $datename = "$year-$month-$day-".join('-', @$headlines);
    } else {
        $datename = "$year-$month-$day";
    }

    while (glob("$txt_dir/*.txt")) {
        next unless (/\b(\d\d\d\d-\d\d-\d\d)(?:-.+)?\.txt$/);
        next unless (-f $_);
        return $_ if $datename eq $1
    }

    my $filename = File::Spec->catfile($txt_dir, "$datename.txt");
    return $filename;
}

sub save_diary_entry {
    my $self = shift;
    my ($year, $month, $day, $title, $body);
    my $filename;
    if (ref $_[0] eq 'HASH') {
        # New way of passing arguments.
        # this can take 'headlines' option additionally.
        my %opt = %{ shift() };
        ($year,$month,$day,$title,$body) = @opt{qw(year month day title body)};
        $filename = $self->text_filename($year, $month, $day, exists $opt{headlines} ? $opt{headlines} : undef);
    } else {
        # Original way of passing arguments.
        ($year,$month,$day,$title,$body) = @_;
        $filename = $self->text_filename($year, $month, $day);
    }


    # $self->backup($filename);
    
    my $OUT;
    if (not open($OUT, ">$filename")) {
        error("$!:$filename");
    }
    print $OUT $title."\n";
    print $OUT $body;
    close($OUT);
    debug("save_diary_entry: return 1 (OK)");
    return 1;
}

sub backup($) {
    my $self = shift;
    my ($filename) = @_;
    # Check if file is exist. (Skip)
    if(-f "$filename") {
        my $bakext = 0;
        while(-f "$filename.$bakext") {
            $bakext++;
        }
        if (not rename("$filename", "$filename.$bakext")) {
            error("$!:$filename");
        }
    }
}

sub unescape($) {
    my $self = shift;
    my ($str) = @_;
    my @escape_string = (
        "&lt;<",
        "&gt;>",
        "&quot;\"",
        "&nbsp; ",
    );
    
    for(@escape_string) {
        my ($from, $to) = split(/;/);
        $str =~ s/$from;/$to/sg;
    }
    
    $str =~ s/&#(\d+);/chr($1)/seg;
    $str =~ s/&amp;/&/sg;
    
    return $str;
}

1;
__END__

=head1 NAME

hw.pl - Hatena Diary Writer


=head1 SYNOPSIS

    $ perl hw.pl [Options]

    # upload updated entries(with cookie)
    $ perl hw.pl -c

=head1 OPTIONS

=over

=item --version

Show version.

=item --help

Show this message.

=item -t

Trivial. Use this switch for trivial edit (i.e. typo).

=item -d

Debug. Use this switch for verbose log.

=item -u username

Username. Specify username.

=item -p password

Password. Specify password.

=item -a agent

User agent. Default value is HatenaDiaryWriter/$VERSION.

=item -T seconds

Timeout. Default value is 180.

=item -c

Cookie. Skip login/logout if $cookie_file exists.

=item -g groupname

Groupname. Specify groupname.

=item -f filename

File. Send only this file without checking timestamp.

=item -M

Do NOT replace *t* with current time.

=item -n config_file

Config file. Default value is $config_file.

=item -l YYYY-MM-DD

Load diary.

=item -L

Load all entries of diary.

=item -s

Load all drafts. drafts will be saved in '$draft_dir'.

=back


=head1 CONFIG FILE EXAMPLE

    id:yourid
    password:yourpassword
    cookie:cookie.txt
    # txt_dir:/usr/yourid/diary
    # touch:/usr/yourid/diary/hw.touch
    # proxy:http://www.example.com:8080/
    # g:yourgroup
    # client_encoding:Shift_JIS
    # server_encoding:UTF-8
    ## for Unix, if Encode module is not available.
    # filter:iconv -f euc-jp -t utf-8 %s


=head1 AUTHOR

Hiroshi Yuki
Kengo Koseki (+Loader)


=head1 COPYRIGHT

Copyright (C) 2004,2005,2007,2009 by Hiroshi Yuki / +Loader by Kengo Koseki.
