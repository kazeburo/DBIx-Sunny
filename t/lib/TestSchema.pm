package TestSchema;

use strict;
use warnings;
use parent 'DBIx::Sunny::Schema';

__PACKAGE__->query(
    'create_foo_t',
    q{CREATE TABLE foo (
    id INTEGER NOT NULL PRIMARY KEY,
    e VARCHAR(10)
)}
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

__PACKAGE__->select_row(
    'select_row_foo_filter',
    q{SELECT * FROM foo ORDER BY e},
    sub {
        my $row = shift;
        $row->{e} = $row->{e} * $row->{e};
        $row->{ref} = ref $_[0];
    }
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

__PACKAGE__->select_all(
    'select_all_foo_filter',
    limit => { isa => 'Int', default => 2 },
    q{SELECT * FROM foo ORDER BY e LIMIT ?},
    sub {
        my $row = shift;
        $row->{e} = $row->{e} * $row->{e};
        $row->{ref} = ref $_[0];
    }
);

__PACKAGE__->select_all(
    'select_all_foo_deflater',
    limit => { isa => 'Int', default => 2, deflater => sub { 1 } },
    q{SELECT * FROM foo ORDER BY e LIMIT ?},
);

__PACKAGE__->select_all(
    'select_all_in',
    ids => { isa => 'ArrayRef[Int]' },
    limit => { isa => 'Int', default => 2},
    q{SELECT * FROM foo WHERE id IN (?) ORDER BY e LIMIT ?}
);

__PACKAGE__->select_all(
    'select_all_in_deflater',
    ids => { isa => 'ArrayRef[Int]' },
    limit => { isa => 'Int', default => 2, deflater => sub {1} },
    q{SELECT * FROM foo WHERE id IN (?) ORDER BY e LIMIT ?}
);


sub retrieve_all_foo {
    my $self = shift;
    my $args = $self->args(
        limit => { isa => 'Int', default => 2 },
    );
    $self->select_all(q{SELECT * FROM foo ORDER BY e LIMIT ?}, $args->{limit});
}

sub deflate_args {
    my $self = shift;
    my $args = $self->args(
        created => {
            isa => 'Time::tm',
            deflater => sub { 'TestTm' }
        },
    );
    $args->{created};
}

1;

package t::TestObject;

1;

