use inc::Module::Install;
name 'DBIx-Sunny';
all_from 'lib/DBIx/Sunny.pm';

# requires '';
requires 'Log::Minimal', 0.03;
requires 'Scope::Container', 0.04;
requires 'Data::Util';
requires 'List::Util';
requires 'DBI', 1.615;
requires 'DBD::SQLite', 1.31;
requires 'Data::MessagePack';
requires 'Class::Accessor::Lite', 0.05;


tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
