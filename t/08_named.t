use strict;
use warnings;
use utf8;
use Test::More;
use DBIx::Sunny;
use Test::Requires { 'DBD::SQLite' => 1.31 };

my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
$dbh->do(q{CREATE TABLE foo (
    id INTEGER NOT NULL PRIMARY KEY,
    e VARCHAR(10)
)});
ok( $dbh->query(q{INSERT INTO foo (e) VALUES(?)}, 'hogee') );

is_deeply
    $dbh->select_row(q{SELECT * FROM foo WHERE e = :e}, {
        e => 'hogee',
    }),
    { id => 1, e => 'hogee' };

eval {
    $dbh->query(q{SELECT * FROM foo WHERE e = :e}, {
        ee => 'hogee',
    });
};
ok $@;
like $@, qr/'e' does not exist in bind hash at /;

done_testing;
