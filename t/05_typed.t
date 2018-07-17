use strict;
use warnings;
use Test::More;
use DBIx::Sunny;
use DBI;
use SQL::Maker::SQLType;
use Test::Requires qw/DBD::SQLite/;

sub sql_int {
    return SQL::Maker::SQLType::sql_type(\$_[0], DBI::SQL_INTEGER);
}

my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
$dbh->do(q{CREATE TABLE foo (
    id INTEGER NOT NULL PRIMARY KEY,
    e INTEGER NOT NULL
)});
ok( $dbh->query(q{INSERT INTO foo (e) VALUES(?), (?)}, sql_int(3), sql_int(4)) );
is $dbh->select_one(q{SELECT e FROM foo WHERE id = ?}, sql_int(1)), 3;
is_deeply $dbh->select_row(q{SELECT * FROM foo WHERE id = ?}, sql_int(1)), { id => 1, e => 3 };
is join('|', map { $_->{e} } @{$dbh->select_all(q{SELECT * FROM foo WHERE id IN (?) ORDER BY e}, [sql_int(1), sql_int(2)])}), '3|4';

done_testing();

