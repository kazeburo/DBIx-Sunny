use strict;
use warnings;
use utf8;
use Test::More;
use DBIx::Sunny;
use Test::Requires 'DBD::SQLite';

my $COUNTER = 0;
{
    no warnings 'once';
    my $orig = DBIx::Sunny::db->can('DESTROY') or die;
    *DBIx::Sunny::db::DESTROY = sub {
        $COUNTER++;
        $orig->(@_);
    };
}

subtest 'x' => sub {
    my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
    $dbh->query(q{CREATE TABLE foo (id INT UNSGINED)});
    $dbh->query(q{INSERT INTO foo (id) VALUES (1)});
    {
        my $txn1 = $dbh->txn_scope();
        $dbh->query(q{INSERT INTO foo (id) VALUES (2)});
        {
            my $txn2 = $dbh->txn_scope();
            $dbh->query(q{INSERT INTO foo (id) VALUES (3)});
            $txn2->rollback;
        }
        eval { $txn1->commit };
        ok $@;
        like $@, qr/tried to commit but already rollbacked in nested transaction/;
    }
    my $cnt = $dbh->select_one(q{SELECT COUNT(*) FROM foo});
    is($cnt, 1);
};

subtest 'y' => sub {
    my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
    $dbh->query(q{CREATE TABLE foo (id INT UNSGINED)});
    $dbh->query(q{INSERT INTO foo (id) VALUES (1)});
    {
        my $txn1 = $dbh->txn_scope();
        $dbh->query(q{INSERT INTO foo (id) VALUES (2)});
        {
            my $txn2 = $dbh->txn_scope();
            $dbh->query(q{INSERT INTO foo (id) VALUES (3)});
            $txn2->commit;
        }
        $txn1->rollback;
    }
    my $cnt = $dbh->select_one(q{SELECT COUNT(*) FROM foo});
    is($cnt, 1);
};

cmp_ok($COUNTER, '>=', 2);

done_testing;
