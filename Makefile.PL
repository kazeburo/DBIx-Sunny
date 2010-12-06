use inc::Module::Install;
name 'DBIx-Sunny';
all_from 'lib/DBIx/Sunny.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
