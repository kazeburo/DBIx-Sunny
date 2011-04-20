use inc::Module::Install;
name 'DBIx-Sunny';
all_from 'lib/DBIx/Sunny.pm';

requires 'parent';
requires 'DBI', 1.615;
requires 'Class::Accessor::Lite', 0.05;
requires 'Class::Data::Inheritable';
requires 'DBIx::TransactionManager';
requires 'Data::Validator';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More', 0.96;
test_requires 'Test::Requires';
test_requires 'DBD::SQLite', 1.27;

test_requires 'Test::mysqld'     if $Module::Install::AUTHOR;

auto_set_repository;
#auto_include;
WriteAll;
