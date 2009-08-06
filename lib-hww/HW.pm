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
our $VERSION = "1.5.8";

use HWWrapper::UtilSub;
use base qw(Class::Accessor::Lvalue);


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
# our $username = '';
# Hatena password (if empty, I will ask you later).
# our $password = '';
# Hatena group name (for hatena group user only).
# our $groupname = '';

# Default file names.
our $touch_file = 'touch.txt';
our $cookie_file = 'cookie.txt';
# our $config_file = 'config.txt';
# our $target_file = '';

# Load diary date.
# our $load_date = '';
# Diff diary date.
# our $diff_date = '';

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
# our $hatena_url = 'http://d.hatena.ne.jp';
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
# our %ua_option = (
#     agent => "HatenaDiaryWriter/$VERSION", # "Mozilla/5.0",
#     timeout => 180,
# );

# Other variables.
our $delete_title = 'delete';
our $cookie_jar;
our $user_agent;
our $rkm; # session id for posting.

# Handle command-line option.
# our %cmd_opt = (
#     'd' => 0,   # "debug" flag.
#     't' => 0,   # "trivial" flag.
#     'u' => "",  # "username" option.
#     'p' => "",  # "password" option.
#     'a' => "",  # "agent" option.
#     'T' => "",  # "timeout" option.
#     'c' => 0,   # "cookie" flag.
#     'g' => "",  # "groupname" option.
#     'f' => "",  # "file" option.
#     'M' => 0,   # "no timestamp" flag.
#     'n' => "",  # "config file" option.
#     'S' => 1,   # "SSL" option. This is always 1. Set 0 to login older hatena server.
#     'l' => "",  # "load" diary.
#     'D' => "",  # "diff" option.
# );


if ($0 eq __FILE__) {
    # Start.
    # if ($cmd_opt{l}) {
    #     load_main();    # now load()
    # } elsif ($cmd_opt{D}) {
    #     diff_main();    # now diff()
    # } else {
    #     main();    # now release()
    # }

    # no-error exit.
    exit(0);
}




sub parse_opt {
    my $self = shift;
    my %cmd_opt = (
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

    {
        local @ARGV = @_;
        local $Getopt::Std::STANDARD_HELP_VERSION = 1;
        getopts("tdu:p:a:T:cg:f:Mn:l:D:", \%cmd_opt) or error("Unknown option.");
    }

    if ($cmd_opt{d}) {
        debug("Debug flag on.");
        debug("Cookie flag on.") if $cmd_opt{c};
        debug("Trivial flag on.") if $cmd_opt{t};
        VERSION_MESSAGE();
    }


    # NOTE:
    # settings will be overridden like the followings
    # - set default settings
    # - set config settings
    # - set arguments settings
    #
    # but -n option(config file) is exceptional case.
    #


    ### set default settings ###

    my $config_file;
    if ($cmd_opt{n}) {
        $config_file = $cmd_opt{n};    # exceptional case
    } else {
        $config_file = 'config.txt';
    }

    my $hatena_url = 'http://d.hatena.ne.jp';

    my %ua_option = (
        agent => "HatenaDiaryWriter/$VERSION", # "Mozilla/5.0",
        timeout => 180,
    );

    my %config = (
        config_file => $config_file,    # needless to store though.
        username => '',
        password => '',
        groupname => '',
        target_file => '',
        hatena_url => $hatena_url,

        %ua_option,

        no_timestamp => 0,
        enable_ssl => 1,

        # this default value is different with original 'hw.pl'.
        # to set this 0, you must give '--no-cookie' option to 'hww.pl'.
        use_cookie => 1,

        # TODO
        # this option will be deprecated
        # because 'release' or 'update' command take this option.
        trivial => 0,

        # TODO && NOTE
        # HWWrapper::load() and HWWrapper::diff() will call
        # SUPER:: with argument so there'll be no reason to
        # stash value in $self->{config}.
        load_date => '',
        diff_date => '',
    );


    # make accessors.
    __PACKAGE__->mk_accessors(keys %config);

    # set default.
    for my $method (keys %config) {
        debug("set default of $method: $config{$method}");
        $self->$method = $config{$method};
    }


    ### set config setttings ###

    # load config at this timing
    # because also load_config() uses above accessors.
    $self->load_config($config_file) if -f $config_file;


    ### set arguments settings ###

    my %args = (
        u => 'username',
        p => 'password',
        g => 'groupname',
        a => 'agent',
        T => 'timeout',
        f => 'target_file',

        # unnecessary because HWWrapper prepares 'load' and 'diff' command.
        # l => 'load_date',
        # D => 'diff_date',
    );
    while (my ($k, $method) = each %args) {
        my $arg_value = $cmd_opt{$k};
        if ($arg_value) {
            debug("set args: $k => $arg_value");
            $self->$method = $arg_value;
        }
    }

    # Change $hatena_url to Hatena group URL if ($groupname is defined).
    if ($self->groupname) {
        my $tmp = $self->hatena_url;
        $self->hatena_url = "http://$cmd_opt{g}.g.hatena.ne.jp";
        debug(sprintf 'hatena_url: %s -> %s', $tmp, $self->hatena_url);
    }
}

# Load diary main sequence. -l option
sub load {
    my $self = shift;
    my ($year, $month, $day) = $self->parse_date($self->load_date);

    # Login if necessary.
    $self->login() unless ($user_agent);

    puts("Load $year-$month-$day.");
    my ($title, $body) = $self->load_diary_entry($year,$month,$day);
    $self->save_diary_entry($year,$month,$day,$title,$body);
    puts("Load OK.");

    $self->logout() if ($user_agent);
}

sub diff {
    my $self = shift;
    my ($year, $month, $day) = $self->parse_date($self->diff_date);

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
    if ($self->target_file) {
        # Do not check timestamp.
        push(@files, $self->target_file);
        debug("files: option -f: @files");
    } else {
        while (glob("$txt_dir/*.txt")) {
            # Check timestamp.
            next if (-e($touch_file) and (-M($_) > -M($touch_file)));
            push(@files, $_);
        }
        debug("files: current dir ($txt_dir): @files");
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
        $self->replace_timestamp($file) unless ($self->no_timestamp);

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
        unless ($self->target_file) {
            # Touch file.
            my $FILE;
            open($FILE, '>', $touch_file) or die "$!:$touch_file\n";
            print $FILE $self->get_timestamp();
            close($FILE);
        }
    }
}

# Login.
sub login() {
    my $self = shift;
    $user_agent = LWP::UserAgent->new(agent => $self->agent, timeout => $self->timeout);
    $user_agent->env_proxy;
    if ($http_proxy) {
        $user_agent->proxy('http', $http_proxy);
        debug("proxy for http: $http_proxy");
        $user_agent->proxy('https', $http_proxy);
        debug("proxy for https: $http_proxy");
    }

    # Ask username if not set.
    unless ($self->username) {
        print "Username: ";
        chomp($self->username = <STDIN>);
    }

    # If "cookie" flag is on, and cookie file exists, do not login.
    if ($self->use_cookie() and -e($cookie_file)) {
        debug("Loading cookie jar.");

        $cookie_jar = HTTP::Cookies->new;
        $cookie_jar->load($cookie_file);
        $cookie_jar->scan(\&get_rkm);

        debug("\$cookie_jar = " . $cookie_jar->as_string);

        puts("Skip login.");

        return;
    }

    # Ask password if not set.
    unless ($self->password) {
        print "Password: ";
        chomp($self->password = <STDIN>);
    }

    my %form;
    $form{name} = $self->username;
    $form{password} = $self->password;

    my $r; # Response.
    if ($self->enable_ssl) {
        my $diary_url = sprintf '%s/%s/', $self->hatena_url, $self->username;

        $form{backurl} = $diary_url;
        $form{mode} = "enter";
        if ($self->use_cookie) {
            $form{persistent} = "1";
        }

        puts("Login to $hatena_sslregister_url as $form{name}.");

        $r = $user_agent->simple_request(
            HTTP::Request::Common::POST("$hatena_sslregister_url", \%form)
        );

        debug($r->status_line);

        debug("\$r = " . $r->content());
    } else {
        # For older version.

        debug('hatena_url: '.$self->hatena_url);
        puts(sprintf 'Login to %s as %s.', $self->hatena_url, $form{name});
        $r = $user_agent->simple_request(
            HTTP::Request::Common::POST($self->hatena_url."/login", \%form)
        );

        debug($r->status_line);

        if (not $r->is_redirect) {
            error("Login: Unexpected response: ", $r->status_line);
        }
    }

    # Check to exist <meta http-equiv="refresh" content="1;URL=..." />
    unless (defined $r->header('refresh')) {
        debug("failed to login. retry...");
        # $username = '';    # needless?
        $self->password = '';
        # Retry to login.
        @_ = ($self);
        goto &login;
    }

    puts("Login OK.");

    debug("Making cookie jar.");

    $cookie_jar = HTTP::Cookies->new;
    $cookie_jar->extract_cookies($r);
    $cookie_jar->save($cookie_file);
    $cookie_jar->scan(\&get_rkm);

    debug("\$cookie_jar = " . $cookie_jar->as_string);
}

# get session id.
sub get_rkm($$$$$$$$$$$) {
    # NOTE: no $self
    my ($version, $key, $val) = @_;
    if ($key eq 'rk') {
        $rkm = md5_base64($val);
        debug("\$rkm = " . $rkm);
    }
}

# Logout.
sub logout() {
    my $self = shift;
    return unless $user_agent;

    # If "cookie" flag is on, and cookie file exists, do not logout.
    if ($self->use_cookie() and -e($cookie_file)) {
        puts("Skip logout.");
        return;
    }

    my %form;
    $form{name} = $self->username;
    $form{password} = $self->password;

    puts(sprintf 'Logout from %s as %s.', $self->hatena_url, $form{name});

    $user_agent->cookie_jar($cookie_jar);
    my $r = $user_agent->get($self->hatena_url."/logout");
    debug($r->status_line);

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

    if ($self->trivial) {
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
        if ($ok or not $self->use_cookie) {
            last;
        }
        debug($msg);
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

    debug($date);

    $user_agent->cookie_jar($cookie_jar);

    my $r = $user_agent->simple_request(
        HTTP::Request::Common::POST(sprintf('%s/%s/edit', $self->hatena_url, $self->username),
            # Content_Type => 'form-data',
            Content => [
                mode => "delete",
                date => $date,
                rkm => $rkm,
            ]
        )
    );

    debug($r->status_line);

    if ((not $r->is_redirect()) and (not $r->is_success())) {
        error("Delete: Unexpected response: ", $r->status_line);
    }

    debug("Location: " . $r->header("Location"));

    # Check the result. ERROR if the location ends with the date.
    # (Note that delete error != post error)
    if ($r->header("Location") =~ m(/$date$)) {                    # /)){
        debug("returns 0 (ERROR).");
        return 0;
    } else {
        debug("returns 1 (OK).");
        return 1;
    }
}

sub create_it($$$) {
    my $self = shift;
    my ($year, $month, $day) = @_;

    debug("$year-$month-$day.");

    $user_agent->cookie_jar($cookie_jar);

    my $r = $user_agent->simple_request(
        HTTP::Request::Common::POST(sprintf('%s/%s/edit', $self->hatena_url, $self->username),
            Content_Type => 'form-data',
            Content => [
                mode => "enter",
                timestamp => $self->get_timestamp(),
                year => $year,
                month => $month,
                day => $day,
                trivial => $self->use_cookie,
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

    debug($r->status_line);

    if ((not $r->is_redirect()) and (not $r->is_success())) {
        error("Create: Unexpected response: ", $r->status_line);
    }

    debug("Location: " . $r->header("Location"));

    # Check the result. OK if the location ends with the date.
    if ($r->header("Location") =~ m(/$year$month$day$)) {          # /)){
        debug("returns 1 (OK).");
        return 1;
    } else {
        debug("returns 0 (ERROR).");

        return 0;
    }
}

sub post_it($$$$$$) {
    my $self = shift;
    my ($year, $month, $day, $title, $body, $imgfile) = @_;

    debug("$year-$month-$day.");

    $user_agent->cookie_jar($cookie_jar);

    my $r = $user_agent->simple_request(
        HTTP::Request::Common::POST(sprintf('%s/%s/edit', $self->hatena_url, $self->username),
            Content_Type => 'form-data',
            Content => [
                mode => "enter",
                timestamp => $self->get_timestamp(),
                year => $year,
                month => $month,
                day => $day,
                title => $title,
                trivial => $self->use_cookie,
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

    debug($r->status_line);

    if (not $r->is_redirect) {
        error("Post: Unexpected response: ", $r->status_line);
    }

    debug("Location: " . $r->header("Location"));

    # Check the result. OK if the location ends with the date.
    if ($r->header("Location") =~ m(/$year$month$day$)) {          # /)){
        debug("returns 1 (OK).");
        return 1;
    } else {
        debug("returns 0 (ERROR).");
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
    debug("input: $input");
    my $FILE;
    if (not open($FILE, '<', $input)) {
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
            if ($self->target_file) {
                debug("-f option, always update: $imgfile");
                return $imgfile;
            } elsif (-e($touch_file) and (-M($imgfile) > -M($touch_file))) {
                debug("skip $imgfile (not updated).");
                next;
            } else {
                debug($imgfile);
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
    open($FILE, '<', $filename) or error("$!: $filename");
    my $file = join('', <$FILE>);
    close($FILE);

    # Replace.
    my $newfile = $file;
    $newfile =~ s/^\*t\*/"*" . time() . "*"/gem;

    # Write if replaced.
    if ($newfile ne $file) {
        debug($filename);
        open($FILE, '>', $filename) or error("$!: $filename");
        print $FILE $newfile;
        close($FILE);
    }
}

# Show help message. This is called by getopts.
sub HELP_MESSAGE {
    pod2usage(-verbose => 2);
}

# Load config file.
sub load_config {
    my $self = shift;
    my $config_file = shift;
    unless (defined $config_file) {
        error("config file was not given.");
    }

    debug("Loading config file ($config_file).");
    my $CONF;
    if (not open($CONF, '<', $config_file)) {
        error("Can't open $config_file.");
    }
    while (<$CONF>) {
        chomp;
        if (/^\#/) {
            # skip comment.
        } elsif (/^$/) {
            # skip blank line.
        } elsif (/^id:([^:]+)$/) {
            $self->username = $1;
            debug("id:".$self->username);
        } elsif (/^g:([^:]+)$/) {
            $self->groupname = $1;
            debug("g:".$self->groupname);
        } elsif (/^password:(.*)$/) {
            $self->password = $1;
            debug("password:********");
        } elsif (/^cookie:(.*)$/) {
            $cookie_file = glob($1);
            $self->use_cookie = 1; # If cookie file is specified, Assume '-c' is given.
            debug("cookie:$cookie_file");
        } elsif (/^proxy:(.*)$/) {
            $http_proxy = $1;
            debug("proxy:$http_proxy");
        } elsif (/^client_encoding:(.*)$/) {
            $client_encoding = $1;
            debug("client_encoding:$client_encoding");
        } elsif (/^server_encoding:(.*)$/) {
            $server_encoding = $1;
            debug("server_encoding:$server_encoding");
        } elsif (/^filter:(.*)$/) {
            $filter_command = $1;
            debug("filter:$filter_command");
        } elsif (/^txt_dir:(.*)$/) {
            $txt_dir = glob($1);
            debug("txt_dir:$txt_dir");
        } elsif (/^touch:(.*)$/) {
            $touch_file = glob($1);
            debug("touch:$touch_file");
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

    debug(sprintf '%s/%s/edit?date=%s%s%s', $self->hatena_url, $self->username, $year, $month, $day);

    $user_agent->cookie_jar($cookie_jar);

    my $r = $user_agent->simple_request(
        HTTP::Request::Common::GET(sprintf '%s/%s/edit?date=%s%s%s', $self->hatena_url, $self->username, $year, $month, $day));

    debug($r->status_line);

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

    debug("OK");
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
    if (not open($OUT, '>', $filename)) {
        error("$!:$filename");
    }
    print $OUT $title."\n";
    print $OUT $body;
    close($OUT);
    debug("wrote $filename");
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
