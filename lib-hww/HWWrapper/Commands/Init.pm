package HWWrapper::Commands::Init;

use strict;
use warnings;
use utf8;

use base qw(HWWrapper::Commands::Base);

# export our variables.
use HWWrapper::Commands qw(%HWW_COMMAND);
# export sub who does not take $self.
use HWWrapper::Functions;




sub regist_command {
    $HWW_COMMAND{init} = {
        coderef => \&run,
        desc => 'set up hww environment',
        option => {
            'c|config' => {
                desc => "apply config's settings",
            },
            'd|delete' => {
                desc => "delete config file and cookie file, and make new ones",
            },
        },
    };
}


sub run {
    my ($self, $args, $opt) = @_;

    my $read_config = $opt->{'c|config'};
    my $del_config  = $opt->{'d|delete'};

    my $txt_dir = 'text';
    my $config_file = 'config.txt';
    my $cookie_file = 'cookie.txt';

    my $dir = shift @$args;
    if (defined $dir) {
        $txt_dir = $dir;
    }
    elsif ($read_config) {
        $txt_dir = $self->txt_dir;
        $config_file = $self->config_file,
        $cookie_file = $self->cookie_file;
    }

    my $config_data = <<EOT;
id:yourid
txt_dir:$txt_dir
touch:@{[ File::Spec->catfile($txt_dir, 'touch.txt') ]}
client_encoding:utf-8
server_encoding:euc-jp
EOT

    if ($del_config) {
        for ($config_file, $cookie_file) {
            next unless -f;
            unlink $_ or $self->warning("$_: $!")
        }
    }


    # text dir
    if (-d $txt_dir) {
        puts("directory $txt_dir already exists.");
    }
    else {
        mkdir $txt_dir or $self->error("$txt_dir: $!");
        puts("mkdir $txt_dir.");
    }

    # config file
    my $made_config_file;
    if (-f $config_file) {
        puts("file $config_file already exists.");
    }
    else {
        my $FH = FileHandle->new($config_file, 'w')
                    or $self->error("$config_file: $!");
        $FH->print($config_data);
        $FH->close;

        puts("create $config_file.");
        $made_config_file = 1;
    }

    # cookie file
    if (-f $cookie_file) {
        puts("chmod 0600 $cookie_file");
        chmod 0600, $cookie_file
            or $self->error($!);
    }


    if ($made_config_file) {
        puts("\nplease edit your id in $config_file.");
    }
}


1;
