use strict;
use warnings;
use Test::More;
use DBIx::Sunny;
use Encode;
use DBI;
use SQL::Maker::SQLType;
use Test::Requires qw/Test::PostgreSQL Test::TCP/;

my $pg = Test::PostgreSQL->new
    or plan skip_all => $Test::PostgreSQL::errstr;

my $dbh = DBIx::Sunny->connect($pg->dsn( dbname => "test" ));

$dbh->do(q{CREATE TABLE foo (
    id SERIAL NOT NULL PRIMARY KEY,
    e VARCHAR(10)
)});

my @last_insert_id_args = (undef, undef, undef, undef, {sequence => join('_', 'foo', 'id', 'seq')});

ok( $dbh->query(q{INSERT INTO foo (e) VALUES(?)}, 3) );
is( $dbh->last_insert_id(@last_insert_id_args), 1 );
ok( $dbh->query(q{INSERT INTO foo (e) VALUES(?)}, 4) );
is( $dbh->last_insert_id(@last_insert_id_args), 2 );

is $dbh->select_one(q{SELECT COUNT(*) FROM foo}), 2;
is_deeply $dbh->select_row(q{SELECT * FROM foo ORDER BY e}), { id => 1, e => 3 };
is join('|', map { $_->{e} } @{$dbh->select_all(q{SELECT * FROM foo ORDER BY e})}), '3|4';

subtest 'utf8' => sub {
    use utf8;
    ok( $dbh->query(q{CREATE TABLE bar (
    id SERIAL NOT NULL PRIMARY KEY,
    x VARCHAR(10)
)}));
    ok( $dbh->query(q{INSERT INTO bar (x) VALUES (?)}, "こんにちは") );
    my ($x) = $dbh->selectrow_array(q{SELECT x FROM bar});
    is $x, "こんにちは";
    ok( Encode::is_utf8($x) );
};

my @func = qw/selectall_arrayref selectrow_arrayref selectrow_array/;
for my $func (@func) {
    eval {
        $dbh->$func('select e from bar where e=?',{},'bar');
    };
    ok $@;
    like $@, qr/for Statement/;
    like $@, qr!/\* .+ line \d+ \*/!;
}

done_testing();
