package t::TestSchema;

use strict;
use warnings;
use parent 'DBIx::Sunny::Schema';

__PACKAGE__->query(
    'create_foo_t',
    q{CREATE TABLE foo (
    id INTEGER NOT NULL PRIMARY KEY,
    e VARCHAR(10)
) }
);

__PACKAGE__->query(
    'insert_foo',
    e => 'Int',
    q{INSERT INTO foo (e) VALUES(?)}
);

__PACKAGE__->select_one(
    'count_foo',
    q{SELECT COUNT(*) FROM foo},
);

__PACKAGE__->select_row(
    'select_row_foo',
    q{SELECT * FROM foo ORDER BY e}
);

__PACKAGE__->select_one(
    'select_one_foo',
    q{SELECT e FROM foo ORDER BY e}
);

__PACKAGE__->select_all(
    'select_all_foo',
    limit => { isa => 'Int', default => 2 },
    q{SELECT * FROM foo ORDER BY e LIMIT ?}
);

sub retrieve_all_foo {
    my $self = shift;
    my $args = $self->args(
        limit => { isa => 'Int', default => 2 },
    );
    $self->select_all(q{SELECT * FROM foo ORDER BY e LIMIT ?}, $args->{limit});
}

1;

