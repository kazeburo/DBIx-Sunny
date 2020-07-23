use strict;
use warnings;
use Test::More;
use Test::Warn;
use DBIx::Sunny::Util qw/expand_placeholder/;

my $exp_warn = qr/Num of binds doesn't match/;

subtest 'no placeholder' => sub {
    my $sql = q{SELECT * FROM foo};

    warning_is { expand_placeholder($sql) } undef, 'exact';
    warning_like { expand_placeholder($sql, 1) } $exp_warn, 'too many';
    warning_like { expand_placeholder($sql, undef) } $exp_warn, 'too many';
};

subtest 'scalar' => sub {
    my $sql = q{SELECT * FROM foo WHERE id = ?};

    warning_like { expand_placeholder($sql) } $exp_warn, 'too few';
    warning_is { expand_placeholder($sql, 1) } undef, 'exact';
    warning_is { expand_placeholder($sql, undef) } undef, 'exact';
    warning_like { expand_placeholder($sql, 1, 2) } $exp_warn, 'too many';
    warning_like { expand_placeholder($sql, 1, undef) } $exp_warn, 'too many';
};

subtest 'has array' => sub {
    my $sql = q{SELECT * FROM foo WHERE id IN (?)};

    warning_like { expand_placeholder($sql) } $exp_warn, 'too few';
    warning_is { expand_placeholder($sql, [1, 2]) } undef, 'exact';
    warning_is { expand_placeholder($sql, [undef]) } undef, 'exact';
    warning_like { expand_placeholder($sql, [1, 2], 3) } $exp_warn, 'too many';
    warning_like { expand_placeholder($sql, [1, 2], undef) } $exp_warn, 'too many';
};

done_testing;
