package HWWrapper::Commands::Base;

use strict;
use warnings;
use utf8;

use Exporter;


sub import {
    # 'use ...' at caller package.
    #
    # Note that Exporter::export_to_level() call these module's import().
    # so if import() is not found in these module, it will fail to export.
    Exporter::export_to_level('HWWrapper::Commands', 1);
    Exporter::export_to_level('HWWrapper::Functions', 1);
}


1;
