use strict;
use warnings;
use Test::More;
use DBIx::Sunny;
use Test::Requires { 'DBD::SQLite' => 1.27 };
use t::TestSchema;

my $dbh = DBIx::Sunny->connect('dbi:SQLite::memory:', '', '');
my $schema = t::TestSchema->new(dbh => $dbh);
ok($schema);

ok($schema->create_foo_t);
ok($schema->insert_foo( e => 3));
ok($schema->insert_foo( e => 4));

eval {
    $schema->insert_foo( e => 'bar');
};
ok($@);

is $schema->count_foo(), 2;
is_deeply $schema->select_row_foo(), { e => 3 };
is join('|', map { $_->{e} } @{$schema->select_all_foo()}), '3|4';
is_deeply $schema->select_all_foo(limit=>1), [{ e => 3 }];

done_testing();
