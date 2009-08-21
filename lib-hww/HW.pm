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

our $VERSION = "1.7.7";

use base qw(HWWrapper::Base);

# import builtin func's hooks
use HWWrapper::Hook::BuiltinFunc;

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


    ### make default config - begin ###

    my %ua_option = (
        agent => "HatenaDiaryWriter/$VERSION", # "Mozilla/5.0",
        timeout => 180,
    );

    my %config = (
        username => '',
        password => '',
        groupname => '',
        target_file => '',
        hatena_url => URI->new('http://d.hatena.ne.jp'),

        %ua_option,

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
    );

    # add $self->{config} to %config
    %config = (
        %config,
        %{ $self->{config} },    # override
    );
    # stash config into myself
    $self->{config} = \%config;

    ### make default config - end ###


    # TODO do this at base class.
    #
    # prepare arguments options.
    my %arg_opt = (
        t => 'trivial',    # "trivial" flag.
        trivial => 'trivial',

        'u=s' => 'username',    # "username" option.
        'username=s' => 'username',

        'p=s' => 'password',    # "password" option.
        'password=s' => 'password',

        'a=s' => 'agent',    # "agent" option.
        'agent=s' => 'agent',

        'T=s' => 'timeout',    # "timeout" option.
        'timeout=s' => 'timeout',

        'g=s' => 'groupname',    # "groupname" option.
        'group=s' => 'groupname',

        M => 'no_timestamp',    # "no timestamp" flag.
        'no-replace' => 'no_timestamp',

        'n=s' => 'config_file',    # "config file" option.
        'config-hw=s' => 'config_file',
    );
    $self->{arg_opt}{HW} = {map {
        # arg option => config value
        ($_ => \$self->{config}{ $arg_opt{$_} })
    } keys %arg_opt};


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

    # get options
    $self->get_opt(
        $self->{args}{options},
        $self->{arg_opt}{HW}
    ) or do {
        $self->warning("arguments error");
        sleep 1;
        $self->dispatch('help');
        exit -1;
    };

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

    # default
    my $config_file = $self->config_file;
    # process only '-n' option in @ARGV.
    $self->get_opt_only($self->{args}{options}, {
        'n=s' => \$config_file,
        'config-hw=s' => \$config_file,
    }) or $self->error("arguments error");

    unless (-f $config_file) {
        $self->debug("$config_file was not found. skip to load config...");
        return;
    }


    $self->debug("Loading config file ($config_file).");

    my $CONF;
    if (not open($CONF, '<', $config_file)) {
        $self->error("Can't open $config_file.");
    }

    # TODO make dispatch table
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
            $self->debug("id:".$self->username);
        }
        elsif (/^g:([^:]+)$/) {
            $self->groupname = $1;
            $self->debug("g:".$self->groupname);
        }
        elsif (/^password:(.*)$/) {
            $self->password = $1;
            $self->debug("password:********");
        }
        elsif (/^cookie:(.*)$/) {
            $self->cookie_file = glob($1);
            $self->debug("cookie:".$self->cookie_file);
        }
        elsif (/^proxy:(.*)$/) {
            $self->http_proxy = $1;
            $self->debug("proxy:".$self->http_proxy);
        }
        elsif (/^client_encoding:(.*)$/) {
            $self->client_encoding = $1;
            $self->debug("client_encoding:".$self->client_encoding);
        }
        elsif (/^server_encoding:(.*)$/) {
            $self->server_encoding = $1;
            $self->debug("server_encoding:".$self->server_encoding);
        }
        elsif (/^filter:(.*)$/) {
            $self->filter_command = $1;
            $self->debug("filter:".$self->filter_command);
        }
        elsif (/^txt_dir:(.*)$/) {
            $self->txt_dir = glob($1);
            $self->debug("txt_dir:".$self->txt_dir);
        }
        elsif (/^touch:(.*)$/) {
            $self->touch_file = glob($1);
            $self->debug("touch:".$self->touch_file);
        }
        else {
            $self->error("Unknown command '$_' in $config_file.");
        }
    }
    close($CONF);
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
