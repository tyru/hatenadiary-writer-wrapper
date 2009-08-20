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
our $VERSION = "1.6.0";

use base qw(HWWrapper::Base);

# import builtin op's hooks
# (these ops are hooked in HWWrapper::Commands::shell())
#
# and this package also exports these ops.
use HWWrapper::Hook::BuiltinFunc;

# import all util commands!!
use HWWrapper::Functions;


use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use File::Basename;
use Getopt::Std;
use Digest::MD5 qw(md5_base64);
use File::Spec;
use Pod::Usage;
use URI;
use IO::Prompt qw(prompt);

my $rkm; # session id for posting.



# TODO
# - login()のwsse対応
# - configにwsseヘッダを保存するファイル名を追加


# NOTE:
# settings will be overridden like the followings
# - set default settings
# - set config settings
# - set arguments settings
#
# but -n option(config file) is exceptional case.
#


### set default settings ###
sub new {
    my $self = shift;

    $self->{arg_opt}{HW} = {
        t => \my $t,    # "trivial" flag.
        'u=s' => \my $u,    # "username" option.
        'p=s' => \my $p,    # "password" option.
        'a=s' => \my $a,    # "agent" option.
        'T=s' => \my $T,    # "timeout" option.
        'g=s' => \my $g,    # "groupname" option.
        'f=s' => \my $f,    # "file" option.
        M => \my $M,    # "no timestamp" flag.
        'n=s' => \my $n,    # "config file" option.
        # S => \undef,    # "SSL" flag. This is always 1. Set 0 to login older hatena server.
    };


    ### make default config - begin ###

    my $hatena_url = 'http://d.hatena.ne.jp';

    my %ua_option = (
        agent => "HatenaDiaryWriter/$VERSION", # "Mozilla/5.0",
        timeout => 180,
    );

    my %config = (
        username => '',
        password => '',
        groupname => '',
        target_file => '',
        hatena_url => URI->new($hatena_url),

        %ua_option,

        no_timestamp => 0,
        enable_ssl => 1,

        trivial => 0,

        touch_file => 'touch.txt',
        cookie_file => 'cookie.txt',
        config_file => 'config.txt',

        # Filter command.
        # e.g. 'iconv -f euc-jp -t utf-8 %s'
        # where %s is filename, output is stdout.
        filter_command => '',

        http_proxy => '',

        # this is default to '.'
        # but txt_dir of config file which is generated
        # by 'init' command is default to 'text'.
        # so txt_dir is 'text' unless user edit it.
        txt_dir => '.',

        client_encoding => '',
        server_encoding => '',

        # string to delete entry from hatena diary.
        # see the URLs at the top of the front comment lines.
        delete_title => 'delete',
        cookie_jar => undef,
        user_agent => undef,

        # login url.
        hatena_sslregister_url => 'https://www.hatena.ne.jp/login',

        enable_encode => eval('use Encode; 1'),
    );

    # add $self->{config} to %config
    %config = (
        %config,
        %{ $self->{config} },    # override
    );
    # stash config into myself
    $self->{config} = \%config;

    ### make default config - end ###


    # Crypt::SSLeay check.
    eval {
        require Crypt::SSLeay;
    };
    if ($@) {
        warning("Crypt::SSLeay is not found, use non-encrypted HTTP mode.");
        $self->{config}{hatena_sslregister_url} = 'http://www.hatena.ne.jp/login';
    }


    # make accessors at base class.
    $self->SUPER::new;
}

### set arguments settings ###
sub parse_opt {
    my $self = shift;
    my $arg_opt = $self->{arg_opt}{HW};
    my @argv = @_;

    return unless @argv;

    # get options
    $self->get_opt($self->{args}{options}, $arg_opt);


    my %args = (
        t => 'trivial',
        'u=s' => 'username',
        'p=s' => 'password',
        'g=s' => 'groupname',
        'a=s' => 'agent',
        'T=s' => 'timeout',
        'f=s' => 'target_file',
        M => 'no_timestamp',
    );

    while (my ($k, $method) = each %args) {
        my $arg_value = ${ $arg_opt->{$k} };
        if ($arg_value) {
            debug("set args: $k => $arg_value");
            $self->$method = $arg_value;
        }
    }

    # Change $self->hatena_url to Hatena group URL if $arg_opt->{'g=s'} is defined.
    if (${ $arg_opt->{'g=s'} }) {
        my $tmp = $self->hatena_url;
        $self->hatena_url = URI->new(sprintf 'http://%s.g.hatena.ne.jp', ${ $arg_opt->{'g=s'} });
        debug(sprintf 'hatena_url: %s -> %s', $tmp, $self->hatena_url);
    }
}

sub parse_date {
    my $self = shift;
    my ($date) = @_;
    if ($date !~ /\A(\d\d\d\d)-(\d\d)-(\d\d)(?:-.+)?(?:\.txt)?\Z/) {
        error("$date: Illegal date format.");
    }
    return ($1, $2, $3);
}

# Login.
sub login {
    my $self = shift;
    return if $self->user_agent;

    $self->user_agent = LWP::UserAgent->new(agent => $self->agent, timeout => $self->timeout);
    $self->user_agent->env_proxy;
    if ($self->http_proxy) {
        $self->user_agent->proxy('http', $self->http_proxy);
        debug("proxy for http: ".$self->http_proxy);
        $self->user_agent->proxy('https', $self->http_proxy);
        debug("proxy for https: ".$self->http_proxy);
    }

    # Ask username if not set.
    unless ($self->username) {
        $self->username = prompt("Username: ", -echo => '');
    }

    # If "cookie" flag is on, and cookie file exists, do not login.
    if ($self->use_cookie() and -e($self->cookie_file)) {
        debug("Loading cookie jar.");

        $self->cookie_jar = HTTP::Cookies->new;
        $self->cookie_jar->load($self->cookie_file);
        $self->cookie_jar->scan(\&get_rkm);

        debug("\$cookie_jar = " . $self->cookie_jar->as_string);

        puts("Skip login.");

        return;
    }

    # Ask password if not set.
    unless ($self->password) {
        $self->password = prompt("Password: ", -echo => '');
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

        puts(sprintf 'Login to %s as %s.',
            $self->hatena_sslregister_url, $form{name});

        $r = $self->user_agent->simple_request(
            HTTP::Request::Common::POST($self->hatena_sslregister_url, \%form)
        );

        debug($r->status_line);

        debug("\$r = " . $r->content());
    }
    else {
        # For older version.

        debug('hatena_url: '.$self->hatena_url);
        puts(sprintf 'Login to %s as %s.', $self->hatena_url, $form{name});
        $r = $self->user_agent->simple_request(
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

    $self->cookie_jar = HTTP::Cookies->new;
    $self->cookie_jar->extract_cookies($r);
    $self->cookie_jar->save($self->cookie_file);
    $self->cookie_jar->scan(\&get_rkm);

    debug("\$cookie_jar = " . $self->cookie_jar->as_string);
}

# get session id.
sub get_rkm {
    # NOTE: no $self
    my ($version, $key, $val) = @_;
    if ($key eq 'rk') {
        $rkm = md5_base64($val);
        debug("\$rkm = " . $rkm);
    }
}

# Logout.
sub logout {
    my $self = shift;
    return unless $self->user_agent;

    # If "cookie" flag is on, and cookie file exists, do not logout.
    if ($self->use_cookie() and -e($self->cookie_file)) {
        puts("Skip logout.");
        return;
    }

    my %form;
    $form{name} = $self->username;
    $form{password} = $self->password;

    puts(sprintf 'Logout from %s as %s.', $self->hatena_url, $form{name});

    $self->user_agent->cookie_jar($self->cookie_jar);
    my $r = $self->user_agent->get($self->hatena_url."/logout");
    debug($r->status_line);

    if (not $r->is_redirect and not $r->is_success) {
        error("Logout: Unexpected response: ", $r->status_line);
    }

    unlink($self->cookie_file);

    puts("Logout OK.");
}

# Update entry.
sub update_diary_entry {
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
sub delete_diary_entry {
    my $self = shift;
    my ($date) = @_;

    # Delete.
    $self->doit_and_retry("delete_diary_entry: DELETE.", sub { return $self->delete_it($date) });
}

# Do the $funcref, and retry if fail.
sub doit_and_retry {
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
        unlink($self->cookie_file);
        puts("Old cookie. Retry login.");
        $self->login();
        $retry++;
    }

    if (not $ok) {
        error("try_it: Check username/password.");
    }
}

# Delete.
sub delete_it {
    my $self = shift;
    my ($date) = @_;

    debug($date);

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
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
    }
    else {
        debug("returns 1 (OK).");
        return 1;
    }
}

sub create_it {
    my $self = shift;
    my ($year, $month, $day) = @_;

    debug("$year-$month-$day.");

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
        HTTP::Request::Common::POST(sprintf('%s/%s/edit', $self->hatena_url, $self->username),
            Content_Type => 'form-data',
            Content => [
                mode => "enter",
                timestamp => $self->get_timestamp(),
                year => $year,
                month => $month,
                day => $day,
                trivial => $self->trivial,
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
    }
    else {
        debug("returns 0 (ERROR).");

        return 0;
    }
}

sub post_it {
    my $self = shift;
    my ($year, $month, $day, $title, $body, $imgfile) = @_;

    debug("$year-$month-$day.");

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
        HTTP::Request::Common::POST(sprintf('%s/%s/edit', $self->hatena_url, $self->username),
            Content_Type => 'form-data',
            Content => [
                mode => "enter",
                timestamp => $self->get_timestamp(),
                year => $year,
                month => $month,
                day => $day,
                title => $title,
                trivial => $self->trivial,
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
    if ($r->header("Location") =~ m{/$year$month$day$}) {
        debug("returns 1 (OK).");
        return 1;
    }
    else {
        debug("returns 0 (ERROR).");
        return 0;
    }
}

# Get "YYYYMMDDhhmmss" for now.
sub get_timestamp {
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
sub read_title_body {
    my $self = shift;
    my ($file) = @_;

    # Execute filter command, if any.
    my $input = $file;
    if ($self->filter_command) {
        $input = sprintf($self->filter_command." |", $file);
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
    if ($self->enable_encode and ($self->client_encoding ne $self->server_encoding)) {
        debug(sprintf 'Convert from %s to %s.',
                $self->client_encoding, $self->server_encoding);
        Encode::from_to($title, $self->client_encoding, $self->server_encoding);
        Encode::from_to($body, $self->client_encoding, $self->server_encoding);
    }

    return($title, $body);
}

# Find image file.
sub find_image_file {
    my $self = shift;
    my ($fulltxt) = @_;
    my ($base, $path, $type) = fileparse($fulltxt, qr/\.txt/);
    for my $ext ('jpg', 'png', 'gif') {
        my $imgfile = "$path$base.$ext";
        if (-e $imgfile) {
            if ($self->target_file) {
                debug("-f option, always update: $imgfile");
                return $imgfile;
            }
            elsif (-e($self->touch_file) and (-M($imgfile) > -M($self->touch_file))) {
                debug("skip $imgfile (not updated).");
                next;
            }
            else {
                debug($imgfile);
                return $imgfile;
            }
        }
    }
    return undef;
}

# Replace "*t*" with timestamp.
sub replace_timestamp {
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

    # default
    my $config_file = $self->config_file;
    # process only '-n' option in @ARGV.
    $self->get_opt_only(
        $self->{args}{options},
        {'n=s' => \$config_file}
    ) or error("arguments error");

    unless (-f $config_file) {
        debug("$config_file was not found. skip to load config...");
        return;
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
        }
        elsif (/^$/) {
            # skip blank line.
        }
        elsif (/^id:([^:]+)$/) {
            $self->username = $1;
            debug("id:".$self->username);
        }
        elsif (/^g:([^:]+)$/) {
            $self->groupname = $1;
            debug("g:".$self->groupname);
        }
        elsif (/^password:(.*)$/) {
            $self->password = $1;
            debug("password:********");
        }
        elsif (/^cookie:(.*)$/) {
            $self->cookie_file = glob($1);
            $self->use_cookie = 1; # If cookie file is specified, Assume '-c' is given.
            debug("cookie:".$self->cookie_file);
        }
        elsif (/^proxy:(.*)$/) {
            $self->http_proxy = $1;
            debug("proxy:".$self->http_proxy);
        }
        elsif (/^client_encoding:(.*)$/) {
            $self->client_encoding = $1;
            debug("client_encoding:".$self->client_encoding);
        }
        elsif (/^server_encoding:(.*)$/) {
            $self->server_encoding = $1;
            debug("server_encoding:".$self->server_encoding);
        }
        elsif (/^filter:(.*)$/) {
            $self->filter_command = $1;
            debug("filter:".$self->filter_command);
        }
        elsif (/^txt_dir:(.*)$/) {
            $self->txt_dir = glob($1);
            debug("txt_dir:".$self->txt_dir);
        }
        elsif (/^touch:(.*)$/) {
            $self->touch_file = glob($1);
            debug("touch:".$self->touch_file);
        }
        else {
            error("Unknown command '$_' in $config_file.");
        }
    }
    close($CONF);
}


# from hateda loader

# Load entry.
sub load_diary_entry {
    my $self = shift;
    my ($year, $month, $day) = @_;

    debug(sprintf '%s/%s/edit?date=%s%s%s', $self->hatena_url, $self->username, $year, $month, $day);

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
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
    if ($self->enable_encode and ($self->client_encoding ne $self->server_encoding)) {
        debug(sprintf 'Convert from %s to %s.', $self->client_encoding, $self->server_encoding);
        Encode::from_to($title, $self->server_encoding, $self->client_encoding);
        Encode::from_to($body, $self->server_encoding, $self->client_encoding);
    }

    debug("OK");
    return ($title, $body);
}

# return entry's path,
# even if specified entry does not exist.
sub get_entrypath {
    my $self = shift;
    my ($year, $month, $day, $headlines) = @_;
    $headlines = [] unless defined $headlines;

    # find entry.
    for my $path ($self->get_entries($self->txt_dir)) {
        my $info = $self->get_entrydate($path);
        return $path
            if $info->{year} eq $year
            && $info->{month} eq $month
            && $info->{day} eq $day;
    }

    # not found entry's path.
    my $datename = sprintf '%04d-%02d-%02d', $year, $month, $day;
    my $filename = $datename.join('-', @$headlines).'.txt';
    return File::Spec->catfile($self->txt_dir, $filename);
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
        $filename = $self->get_entrypath($year, $month, $day, exists $opt{headlines} ? $opt{headlines} : undef);
    }
    else {
        # Original way of passing arguments.
        ($year,$month,$day,$title,$body) = @_;
        $filename = $self->get_entrypath($year, $month, $day);
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

sub backup {
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

sub unescape {
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
