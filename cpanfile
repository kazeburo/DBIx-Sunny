requires 'Class::Accessor::Lite', '0.05';
requires 'Class::Data::Inheritable';
requires 'DBI', '1.615';
requires 'DBIx::TransactionManager', '0.13';
requires 'Data::Validator';
requires 'SQL::Maker::SQLType';
requires 'SQL::NamedPlaceholder', '0.10';
requires 'Scalar::Util';
requires 'parent';
requires 'perl', '5.008005';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on test => sub {
    requires 'Capture::Tiny';
    requires 'Test::More', '0.98';
    requires 'Test::Requires';
};

on develop => sub {
    requires 'DBD::SQLite', '1.31';
    requires 'DBIx::Class', '0.082840';
    requires 'DBIx::Tracer', '0.03';
    requires 'Test::PostgreSQL';
    requires 'Test::TCP';
    requires 'Test::mysqld';
};
