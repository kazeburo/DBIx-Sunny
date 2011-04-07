use inc::Module::Install;
name 'DBIx-Sunny';
all_from 'lib/DBIx/Sunny.pm';

# requires '';
requires 'DBI', 1.615;
requires 'Class::Accessor::Lite', 0.05;
requires 'Class::Data::Inheritable';
requires 'DBIx::TransactionManager';
requires 'Data::Validator';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
#auto_include;
WriteAll;
