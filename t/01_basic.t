use strict;
use warnings;
use Test::More 0.98;
use DBIx::Sunny;
use Encode;
use Test::Requires { 'DBD::SQLite' => 1.31 };

eval {
    DBIx::Sunny->connect('dbi:unknown:', '', '');
};
ok $@, "dies with unknown driver, automatically.";

my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
$dbh->do(q{CREATE TABLE foo (
    id INTEGER NOT NULL PRIMARY KEY,
    e VARCHAR(10)
)});
ok( $dbh->query(q{INSERT INTO foo (e) VALUES(?)}, 3) );
is( $dbh->last_insert_id, 1 );
ok( $dbh->query(q{INSERT INTO foo (e) VALUES(?)}, 4) );
is( $dbh->last_insert_id, 2 );
is $dbh->select_one(q{SELECT COUNT(*) FROM foo}), 2;
is_deeply $dbh->select_row(q{SELECT * FROM foo ORDER BY e}), { id => 1, e => 3 };
is join('|', map { $_->{e} } @{$dbh->select_all(q{SELECT * FROM foo ORDER BY e})}), '3|4';
is join('|', map { $_->{e} } @{$dbh->select_all(q{SELECT * FROM foo WHERE e IN (?)},[3,4])}), '3|4';


{
    package Foo;
    sub new {
        my ($class, %args) = @_;
        bless \%args, $class;
    }
}

subtest 'select_row_as' => sub {
    my $foo = $dbh->select_row_as('Foo', q{SELECT e FROM foo WHERE id=?}, 1);
    isa_ok $foo, 'Foo';
    is $foo->{e}, 3;
};

subtest 'select_all_as' => sub {
    my $foos = $dbh->select_all_as('Foo', q{SELECT * FROM foo ORDER BY e});
    isa_ok $foos->[0], 'Foo';
    is $foos->[0]->{e}, 3;

    isa_ok $foos->[1], 'Foo';
    is $foos->[1]->{e}, 4;
};

subtest 'utf8' => sub {
    use utf8;
    ok( $dbh->query(q{CREATE TABLE bar (x varchar(10))}) );
    ok( $dbh->query(q{INSERT INTO bar (x) VALUES (?)}, "こんにちは") );
    my ($x) = $dbh->selectrow_array(q{SELECT x FROM bar});
    is $x, "こんにちは";
    ok( Encode::is_utf8($x) );
};

eval {
    $dbh->query(q{INSERT INTO bar (e) VALUES (?)}, '1');
};
ok $@;
#XXX like $@, qr/for Statement/;
#XXX like $@, qr!/\* .+ line \d+ \*/!;

my @func = qw/selectall_arrayref selectrow_arrayref selectrow_array/;
for my $func (@func) {
    eval {
        $dbh->$func('select e from bar where e=?',{},'bar');
    };
    ok $@;
    #XXX like $@, qr/for Statement/;
    #XXX like $@, qr!/\* .+ line \d+ \*/!;
}

is $dbh->connect_info->[0], 'dbi:SQLite::memory:';

my ($query, @binds) = $dbh->fill_arrayref(
    'SELECT * FROM foo WHERE e IN (?) OR e IN (?)',
    [ 'a', 'b' ],
    [ 'x', 'y', 'z' ],
);

is $query, 'SELECT * FROM foo WHERE e IN (?,?) OR e IN (?,?,?)';
is_deeply \@binds, [ 'a', 'b', 'x', 'y', 'z' ];

done_testing();

