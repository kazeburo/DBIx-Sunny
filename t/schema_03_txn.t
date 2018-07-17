use strict;
use warnings;
use Test::More;
use Test::Requires { 'DBD::SQLite' => 1.31 };
use DBIx::Sunny;
use lib 't/lib/';
use TestSchema;


subtest 'x' => sub {
    my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
    my $schema = TestSchema->new(dbh => $dbh);
    $schema->create_foo_t();
    $schema->insert_foo(e=>1);
    {
        my $txn1 = $schema->txn_scope();
        $schema->insert_foo(e=>2);
        {
            my $txn2 = $schema->txn_scope();
            $schema->insert_foo(e=>3);
            $txn2->rollback;
        }
        eval { $txn1->commit };
        ok $@;
        like $@, qr/tried to commit but already rollbacked in nested transaction/;
    }
    my $cnt = $schema->count_foo();
    is($cnt, 1);
};


done_testing;

