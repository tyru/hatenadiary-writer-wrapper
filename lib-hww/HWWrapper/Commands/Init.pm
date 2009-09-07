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
    };
}


sub run {
    my ($self, $args, $opt) = @_;

    my $cookie_file = 'cookie.txt';
    my $config_file = 'config-hww.txt';
    my $config_file_sample = 'config-hww.txt.sample';

    # delete $cookie_file.
    if (-f $cookie_file) {
        unlink $cookie_file
            or $self->warning("$cookie_file: $!");
    }

    # copy $config_file_sample to $config_file.
    unless (-f $config_file) {
        unless (-f $config_file_sample) {
            $self->warning(
                "$config_file_sample was not found." .
                "skip make $config_file..."
            );
        }
        else {
            $self->require_modules(qw(File::Copy));
            File::Copy::copy($config_file_sample => $config_file)
                or
            $self->warning("Cannot copy $config_file_sample to $config_file");

            chmod 0600, $config_file
                or $self->warning("Cannot chmod 0600 $config_file");
        }
    }
}


1;


