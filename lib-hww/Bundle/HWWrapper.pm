package Bundle::HWWrapper;

our $VERSION = '0.0.3';


1;
__END__

=head1 NAME

Bundle::HWWrapper - Bundling Modules of HWWrapper


=head1 SYNOPSIS

perl -MCPAN -e 'install Bundle::HWWrapper'


=head1 CONTENTS

# for HWWrapper::Base
List::MoreUtils

# for HW
LWP::UserAgent
HTTP::Request::Common
Crypt::SSLeay
URI
IO::Prompt

# for HWWrapper
Date::Manip
DateTime
HTML::Template
HTML::TreeBuilder
Text::Hatena
XML::TreePP
LWP::Authen::Wsse
IO::String


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
