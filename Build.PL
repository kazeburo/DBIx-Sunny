use strict;
use warnings FATAL => 'all';
use Module::Build;

my $build = Module::Build->new(
    license              => 'perl',
    recursive_test_files => 1,
    dynamic_config       => 0,
    build_requires       => {
        'Test::Requires' => '0',
        'Test::More'     => '0.98',
        'Test::TCP'      => '0',
        'Capture::Tiny'  => '0',
        'DBD::SQLite'    => '1.31',
    },
    configure_requires => { 'Module::Build' => '0.38' },
    requires           => {
        'Scalar::Util'             => '0',
        'parent'                   => '0',
        'DBIx::TransactionManager' => '0',
        'Class::Accessor::Lite'    => '0.05',
        'perl'                     => '5.008005',
        'Class::Data::Inheritable' => '0',
        'Data::Validator'          => '0',
        'DBI'                      => '1.615'
    },
    no_index    => { 'directory' => [ 'inc', 't', 'xt' ] },
    name        => 'DBIx-Sunny',
    module_name => 'DBIx::Sunny',

    test_files => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',

    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();
