use warnings;
use strict;
use Module::Build;

Module::Build->new(
    module_name    => 'CGI::Session::Driver::layered',
    license        => 'perl',
    build_requires => {
	'Test::More' => 0,
    },
    requires => {
	'CGI::Session' => 4.00,
    }
)->create_build_script();
