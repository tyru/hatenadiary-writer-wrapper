#!/usr/bin/perl
package HW;

use strict;
use warnings;
use utf8;

our $VERSION = "1.7.8";

use base qw(HWWrapper::Base);

# import all util commands!!
use HWWrapper::Functions;





### set default settings ###
sub new {
    my $self = shift;


    # make default config.
    my %config = (
        username => '',
        password => '',
        groupname => '',

        agent => "HatenaDiaryWriter/$VERSION", # "Mozilla/5.0",
        timeout => 180,

        no_timestamp => 0,
        enable_ssl => 1,    # NOTE: this value always 1.

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

        # login url.
        hatena_sslregister_url => 'https://www.hatena.ne.jp/login',

        enable_encode => eval('use Encode; 1'),

        no_load_config_hw => 0,
    );

    # add hw config to $self->{config}.
    while (my ($k, $v) = each %config) {
        $self->{config}{$k} = $v;
    }

    # move this values from $self->{config}.
    # because avoid to be set in config file.
    # (HWWrapper::load_config() only sees $self->{config})
    $self->{config_file_immutable_ac} = {
        hatena_url => URI->new('http://d.hatena.ne.jp'),
        cookie_jar => undef,
        user_agent => undef,
        trivial => 0,
    };


    # prepare arguments options.
    my %arg_opt = (
        'u|username=s' => \$self->{config}{username},
        'p|password=s' => \$self->{config}{password},
        'a|agent=s' => \$self->{config}{agent},
        'T|timeout=i' => \$self->{config}{timeout},
        'g|group=s' => \$self->{config}{groupname},
        'c|use-cookie' => \$self->{config}{use_cookie},
        'M|no-timestamp' => \$self->{config}{no_timestamp},
        'n|config-hw=s' => \$self->{config}{config_file},
        'no-load-hw' => \$self->{config}{no_load_config_hw},
    );
    while (my ($k, $v) = each %arg_opt) {
        $self->{arg_opt}{$k} = $v;
    }


    # make accessors at base class.
    $self = $self->SUPER::new;


    # Crypt::SSLeay check.
    eval {
        require Crypt::SSLeay;
    };
    if ($@) {
        $self->warning("Crypt::SSLeay is not found, use non-encrypted HTTP mode.");
        $self->{config}{hatena_sslregister_url} = 'http://www.hatena.ne.jp/login';
    }

    return $self;
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

        if (/^id:([^:]+)$/) {
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
            $self->error(sprintf "%s: %d: invalid format",
                        $config_file, $CONF->input_line_number);
        }
    }

    $CONF->close;
}

1;
