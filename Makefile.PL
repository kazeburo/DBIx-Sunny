use inc::Module::Install;
name 'DBIx-Sunny';
all_from 'lib/DBIx/Sunny.pm';

# requires '';
requires 'DBI', 1.615;
requires 'DBD::SQLite', 1.31;
requires 'DBD::mysql', 4.008;
requires 'Class::Accessor::Lite', 0.05;
requires 'Class::Data::Inheritable';
requires 'DBIx::TransactionManager';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
