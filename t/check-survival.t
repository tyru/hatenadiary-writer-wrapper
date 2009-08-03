use Test::More;
use Test::Exception;
plan 'no_plan';

use HWWrapper;
my $wrapper = HWWrapper->new;


dies_ok {
    $wrapper->arg_error;
};

dies_ok {
    HWW->arg_error;
};

dies_ok {
    $wrapper->error("error!");
};

lives_ok {
    HWWrapper::UtilSub->import('dump');
    dump("dumping...");
};
