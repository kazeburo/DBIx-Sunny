requires 'Class::Accessor::Lite', '0.05';
requires 'Class::Data::Inheritable';
requires 'DBI', '1.615';
requires 'DBIx::TransactionManager', '0.13';
requires 'Data::Validator';
requires 'Scalar::Util';
requires 'parent';

on test => sub {
    requires 'Capture::Tiny';
    requires 'DBD::SQLite', '1.31';
    requires 'Test::More', '0.98';
    requires 'Test::Requires';
    requires 'Test::TCP';
};
