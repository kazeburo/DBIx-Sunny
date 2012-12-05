use strict;
use warnings;
use Test::More;
use DBIx::Sunny;
use Encode;
use Test::Requires qw/Test::mysqld Test::TCP/;

my $port = Test::TCP::empty_port();

my $mysqld = Test::mysqld->new(
    my_cnf => {
        'port' => $port,
        'bind-address' => '127.0.0.1', # no TCP socket
        'character_set_server' => 'latin1', # for test
    }
) or plan skip_all => $Test::mysqld::errstr;

my $dbh = DBIx::Sunny->connect($mysqld->dsn( dbname => "test" ));

$dbh->do(q{CREATE TABLE foo (
    id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
    e VARCHAR(10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
});

ok( $dbh->query(q{INSERT INTO foo (e) VALUES(?)}, 3) );
is( $dbh->last_insert_id(), 1 );
ok( $dbh->query(q{INSERT INTO foo (e) VALUES(?)}, 4) );
is( $dbh->last_insert_id(), 2 );

is $dbh->select_one(q{SELECT COUNT(*) FROM foo}), 2;
is_deeply $dbh->select_row(q{SELECT * FROM foo ORDER BY e}), { id => 1, e => 3 };
is join('|', map { $_->{e} } @{$dbh->select_all(q{SELECT * FROM foo ORDER BY e})}), '3|4';

subtest 'utf8' => sub {
    use utf8;
    ok( $dbh->query(q{CREATE TABLE bar (
    id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
    x VARCHAR(10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
}));
    ok( $dbh->query(q{INSERT INTO bar (x) VALUES (?)}, "こんにちは") );
    my ($x) = $dbh->selectrow_array(q{SELECT x FROM bar});
    is $x, "こんにちは";
    ok( Encode::is_utf8($x) );
};

eval {
    $dbh->query(q{INSERT INTO bar (e) VALUES (?)}, '1');
};
ok $@;
like $@, qr/for Statement/;
like $@, qr!/\* .+ line \d+ \*/!;

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


