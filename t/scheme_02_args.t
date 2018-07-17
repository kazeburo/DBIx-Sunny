use strict;
use warnings;
use Test::More;
use Time::localtime;
use DBIx::Sunny;
use Test::Requires { 'DBD::SQLite' => 1.31 };
use lib 't/lib/';
use TestSchema;

my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
my $schema = TestSchema->new(dbh => $dbh);

my $created = localtime;
is( $schema->deflate_args(created=>$created), 'TestTm');

done_testing;

