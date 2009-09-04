package HWWrapper::Commands::Update;

use strict;
use warnings;
use utf8;

use base qw(HWWrapper::Commands::Base);

# export our variables.
use HWWrapper::Commands qw(%HWW_COMMAND);




sub regist_command {
    $HWW_COMMAND{update} = {
        coderef => \&run,
        desc => 'upload entries to hatena diary as trivial',
        option => {
            't|trivial' => {
                desc => "upload entries as trivial",
            },
        },
    };
}


sub run {
    my ($self, $args, $opt) = @_;
    $opt->{'t|trivial'} = 1;
    $self->release($args, $opt);
}


1;
