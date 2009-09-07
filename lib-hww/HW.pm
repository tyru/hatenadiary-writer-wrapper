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
use utf8;

our $VERSION = "1.7.8";

use base qw(HWWrapper::Base);

# import all util commands!!
use HWWrapper::Functions;



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


    # make default config.
    my %config = (
        username => '',
        password => '',
        groupname => '',
        target_file => '',
        hatena_url => URI->new('http://d.hatena.ne.jp'),

        agent => "HatenaDiaryWriter/$VERSION", # "Mozilla/5.0",
        timeout => 180,

        no_timestamp => 0,
        enable_ssl => 1,    # NOTE: this value always 1.

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

        no_load_config_hw => 0,
    );

    # add hw config to $self->{config}.
    while (my ($k, $v) = each %config) {
        $self->{config}{$k} = $v;
    }


    # prepare arguments options.
    my %arg_opt = (
        'u|username=s' => \$self->{config}{username},    # "username" option.
        'p|password=s' => \$self->{config}{password},    # "password" option.
        'a|agent=s' => \$self->{config}{agent},    # "agent" option.
        'T|timeout=i' => \$self->{config}{timeout},    # "timeout" option.
        'g|group=s' => \$self->{config}{groupname},    # "groupname" option.
        'M|no-timestamp' => \$self->{config}{no_timestamp},    # "no timestamp" flag.
        'n|config-hw=s' => \$self->{config}{config_file},    # "config file" option.
        'no-load-hw' => \$self->{config}{no_load_config_hw},
    );
    while (my ($k, $v) = each %arg_opt) {
        $self->{arg_opt}{$k} = $v;
    }


    # Crypt::SSLeay check.
    eval {
        require Crypt::SSLeay;
    };
    if ($@) {
        $self->warning("Crypt::SSLeay is not found, use non-encrypted HTTP mode.");
        $self->{config}{hatena_sslregister_url} = 'http://www.hatena.ne.jp/login';
    }


    # make accessors at base class.
    $self->SUPER::new;
}



### set arguments settings ###
sub parse_opt {
    my $self = shift;

    # change the URL to hatena group's URL if '-g' option was given.
    if (length $self->groupname) {
        my $tmp = $self->hatena_url;
        $self->hatena_url = URI->new(
            sprintf 'http://%s.g.hatena.ne.jp', $self->groupname
        );
        $self->debug(sprintf 'hatena_url: %s -> %s', $tmp, $self->hatena_url);
    }
}



### set config file settings ###
sub load_config {
    my $self = shift;

    if ($self->no_load_config_hw) {
        $self->debug("'--no-load-hw' was given...skip");
        return;
    }

    my $config_file = $self->config_file;
    unless (-f $config_file) {
        $self->debug("$config_file was not found. skip to load config...");
        return;
    }


    $self->debug("Loading config file ($config_file).");

    my $CONF = FileHandle->new($config_file, 'r')
                or $self->error("Can't open $config_file.");

    while (<$CONF>) {
        next if /^#/ or /^\s*$/;
        chomp;

        if (/^id: \s* ([^:]+)$/x) {
            $self->username = $1;
            $self->debug("id:".$self->username);
        }
        elsif (/^g: \s* ([^:]+)$/x) {
            $self->groupname = $1;
            $self->debug("g:".$self->groupname);
        }
        elsif (/^password: \s* (.*)$/x) {
            $self->password = $1;
            $self->debug("password:********");
        }
        elsif (/^cookie: \s* (.*)$/x) {
            $self->cookie_file = glob($1);
            $self->debug("cookie:".$self->cookie_file);
        }
        elsif (/^proxy: \s* (.*)$/x) {
            $self->http_proxy = $1;
            $self->debug("proxy:".$self->http_proxy);
        }
        elsif (/^client_encoding: \s* (.*)$/x) {
            $self->client_encoding = $1;
            $self->debug("client_encoding:".$self->client_encoding);
        }
        elsif (/^server_encoding: \s* (.*)$/x) {
            $self->server_encoding = $1;
            $self->debug("server_encoding:".$self->server_encoding);
        }
        elsif (/^filter: \s* (.*)$/x) {
            $self->filter_command = $1;
            $self->debug("filter:".$self->filter_command);
        }
        elsif (/^txt_dir: \s* (.*)$/x) {
            $self->txt_dir = glob($1);
            $self->debug("txt_dir:".$self->txt_dir);
        }
        elsif (/^touch: \s* (.*)$/x) {
            $self->touch_file = glob($1);
            $self->debug("touch:".$self->touch_file);
        }
        else {
            $self->error(sprintf "%s: %d: invalid format",
                        $config_file, $CONF->input_line_number);
        }
    }

    $CONF->close;
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
