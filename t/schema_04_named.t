use strict;
use warnings;
use Test::More;
use Capture::Tiny qw/capture_merged/;
use DBIx::Sunny;
use Test::Requires { 'DBD::SQLite' => 1.31 };
use lib 't/lib/';
use TestSchemaNamed;

my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
my $schema = TestSchemaNamed->new(dbh => $dbh);
ok($schema);

ok($schema->create_foo_t);
ok($schema->insert_foo( e => 3));
is( $schema->last_insert_id, 1 );
ok($schema->insert_foo( e => 4));
is( $schema->last_insert_id, 2 );

eval {
    $schema->insert_foo( e => 'bar');
};
ok($@);

is $schema->count_foo(), 2;

is $schema->select_one_foo(), 3;
ok ! capture_merged { $schema->select_one_foo() };

is_deeply $schema->select_row_foo(), { id=>1, e => 3 };
ok ! capture_merged { $schema->select_row_foo() };

is_deeply $schema->select_row_foo_filter(), { id=>1, e => 9, ref => 'TestSchemaNamed' };

is join('|', map { $_->{e} } @{$schema->select_all_foo()}), '3|4';
is_deeply $schema->select_all_foo(limit=>1), [{ id=>1, e => 3 }];
ok ! capture_merged { $schema->select_all_foo(limit=>1) };

is join('|', map { $_->{e} } @{$schema->select_all_foo_filter()}), '9|16';
is join('|', map { $_->{e} } @{$schema->select_all_foo_deflater()}), '3';

is join('|', map { $_->{e} } @{$schema->select_all_in(ids=>[1,2])}), '3|4';
is_deeply $schema->select_all_in(ids=>[1,2,3], limit=>1), [{ id=>1, e => 3 }];

is_deeply $schema->select_all_in_deflater(ids=>[1,2,3], limit=>10), [{ id=>1, e => 3 }];

is_deeply $schema->retrieve_all_foo(limit=>1), [{ id=>1, e => 3 }];
eval {
    $schema->retrieve_all_foo( limit => 'bar');
};
ok($@);

eval {
    $schema->retrieve_all_foo('limit');
};
ok($@);

done_testing();
