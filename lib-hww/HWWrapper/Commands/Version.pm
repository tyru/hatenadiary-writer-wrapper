package HWWrapper::Commands::Version;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;





sub regist_command {
    $HWW_COMMAND{version} = {
        coderef => \&run,
        desc => 'display version information about hww',
    };
}


sub run {
    # hw
    print <<EOD;
Hatena Diary Writer(+Loader) Version $HW::VERSION
Copyright (C) 2004,2005,2007,2009 by Hiroshi Yuki / +Loader by Kengo Koseki.

EOD
    # hww
    print <<EOD;
Hatena Diary Writer Wrapper version v$HWWrapper::VERSION
EOD
}



1;
