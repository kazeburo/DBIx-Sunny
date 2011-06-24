use strict;
use warnings;
use Test::More;
use Time::localtime;
use DBIx::Sunny;
use Test::Requires { 'DBD::SQLite' => 1.27 };
use t::TestSchema;

my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
my $schema = t::TestSchema->new(dbh => $dbh);

my $created = localtime;
is( $schema->deflate_args(created=>$created), 'TestTm');

done_testing;

