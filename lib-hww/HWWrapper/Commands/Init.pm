package HWWrapper::Commands::Init;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{init} = {
        coderef => \&run,
        desc => 'set up hww environment',
        option => {
            'c|config' => {
                desc => "apply config's settings",
            },
            'd|delete' => {
                desc => "delete cookie file",
            },
        },
    };
}


sub run {
    my ($self, $args, $opt) = @_;

    my $opt_config = $opt->{'c|config'};
    my $opt_delete = $opt->{'d|delete'};

    my $txt_dir = 'text';
    my $config_file = 'config.txt';
    my $hww_config_file = 'config-hww.txt';
    my $cookie_file = 'cookie.txt';

    my $dir = shift @$args;
    if (defined $dir) {
        $txt_dir = $dir;
    }
    elsif ($opt_config) {
        $txt_dir = $self->txt_dir;
        $config_file = $self->config_file;
        $hww_config_file = $self->config_hww_file;
        $cookie_file = $self->cookie_file;
    }

    my $config_data = <<EOT;
id:yourid
txt_dir:$txt_dir
touch:@{[ File::Spec->catfile($txt_dir, 'touch.txt') ]}
client_encoding:utf-8
server_encoding:euc-jp
EOT

    if ($opt_delete && -f $cookie_file) {
        unlink $cookie_file
            or $self->warning("$cookie_file: $!")
    }


    # text dir
    if (-d $txt_dir) {
        puts("directory $txt_dir already exists.");
    }
    else {
        mkdir $txt_dir or $self->warning("$txt_dir: $!");
        puts("mkdir $txt_dir.");
    }

    # hw config file
    my $made_config_file;
    if (-f $config_file) {
        puts("file $config_file already exists.");
    }
    else {
        my $FH = FileHandle->new($config_file, 'w');
        if (defined $FH) {
            $FH->print($config_data);
            $FH->close;
        }
        else {
            $self->warning("$config_file: $!");
        }

        puts("create $config_file.");
        $made_config_file = 1;
    }
    puts("chmod 0600 $config_file");
    chmod 0600, $config_file or $self->warning($!);

    # hww config file
    if (-f $hww_config_file) {
        # make this private
        # because it may contain username and password.
        puts("chmod 0600 $hww_config_file");
        chmod 0600, $hww_config_file or $self->warning($!);
    }

    # cookie file
    if (-f $cookie_file) {
        puts("chmod 0600 $cookie_file");
        chmod 0600, $cookie_file or $self->warning($!);
    }


    if ($made_config_file) {
        puts("\nplease edit your id in $config_file.");
    }
}


1;


