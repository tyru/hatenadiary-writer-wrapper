use strict;
use warnings;
use Module::Build;

Module::Build->new(
    module_name         => 'HWWrapper',
    license             => 'perl',
    dist_author         => 'tyru <tyru.exe@gmail.com>',
    dist_version_from   => 'lib-hww/HWWrapper.pm',
    requires => {
        # HW.pm
        'LWP::UserAgent' => 0,
        'HTTP::Request::Common' => 0,
        'Crypt::SSLeay' => 0,
        'Class::Accessor::Lvalue' => 0,

        # HWWrapper.pm and HWWrapper/*
        'Date::Manip' => 0,
        'DateTime' => 0,
        'HTML::Template' => 0,
        'HTML::TreeBuilder' => 0,
        'Text::Hatena' => 0,
        'XML::TreePP' => 0,
        'LWP::Authen::Wsse' => 0,
    },
    add_to_cleanup      => [ 'HWWrapper-*' ],
)->create_build_script;

