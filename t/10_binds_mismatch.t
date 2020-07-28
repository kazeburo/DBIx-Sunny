use strict;
use warnings;
use Test::More;
use Test::Exception;
use DBIx::Sunny::Util qw/expand_placeholder/;

my $exp_throw = qr/Num of binds doesn't match/;

subtest 'no placeholder' => sub {
    my $sql = q{SELECT * FROM foo};

    lives_ok { expand_placeholder($sql) } 'exact';
    throws_ok { expand_placeholder($sql, 1) } $exp_throw, 'too many';
    throws_ok { expand_placeholder($sql, undef) } $exp_throw, 'too many';
};

subtest 'scalar' => sub {
    my $sql = q{SELECT * FROM foo WHERE id = ?};

    throws_ok { expand_placeholder($sql) } $exp_throw, 'too few';
    lives_ok { expand_placeholder($sql, 1) } 'exact';
    lives_ok { expand_placeholder($sql, undef) } 'exact';
    throws_ok { expand_placeholder($sql, 1, 2) } $exp_throw, 'too many';
    throws_ok { expand_placeholder($sql, 1, undef) } $exp_throw, 'too many';
};

subtest 'has array' => sub {
    my $sql = q{SELECT * FROM foo WHERE id IN (?)};

    throws_ok { expand_placeholder($sql) } $exp_throw, 'too few';
    lives_ok { expand_placeholder($sql, [1, 2]) } 'exact';
    lives_ok { expand_placeholder($sql, [undef]) } 'exact';
    throws_ok { expand_placeholder($sql, [1, 2], 3) } $exp_throw, 'too many';
    throws_ok { expand_placeholder($sql, [1, 2], undef) } $exp_throw, 'too many';
};

done_testing;
