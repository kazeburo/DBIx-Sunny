package DBIx::Sunny;

use strict;
use warnings;
use 5.008001;
use DBI 1.615;

our $VERSION = '0.01';

use parent qw/DBI/;

package DBIx::Sunny::dr;
our @ISA = qw(DBI::dr);

package DBIx::Sunny::db;
our @ISA = qw(DBI::db);

use DBIx::TransactionManager;

sub connected {
    my $dbh = shift;
    my ($dsn, $user, $pass, $attr) = @_;
    $dbh->{RaiseError} = 1;
    $dbh->{PrintError} = 0;
    $dbh->{ShowErrorStatement} = 1;
    $dbh->{AutoInactiveDestroy} = 1;
    if ($dsn =~ /^dbi:SQLite:/) {
        $dbh->{sqlite_unicode} = 1 unless exists $attr->{sqlite_unicode};
    }
    if ($dsn =~ /^dbi:mysql:/ && ! exists $attr->{mysql_enable_utf8} ) {
        $dbh->{mysql_enable_utf8} = 1;
        $dbh->do("SET NAMES utf8");
    }
    $dbh->{private_connect_info} = [@_];
    $dbh->SUPER::connected(@_);
}

sub connect_info { $_[0]->{private_connect_info} }

sub _txn_manager {
    my $self = shift;
    if (!defined $self->{private_txn_manager}) {
        $self->{private_txn_manager} = DBIx::TransactionManager->new($self);
    }
    return $self->{private_txn_manager};
}

sub txn_scope {
    my $self = shift;
    $self->_txn_manager->txn_scope(
        caller => [caller(0)]
    );
}

sub __set_comment {
    my $self = shift;
    my $query = shift;

    my $trace;
    my $i = 0;
    while ( my @caller = caller($i) ) {
        my $file = $caller[1];
        $file =~ s!\*/!*\//!g;
        $trace = "/* $file line $caller[2] */"; 
        last if $caller[0] ne ref($self) && $caller[0] !~ /^(:?DBIx?|DBD)\b/;
        $i++;
    }
    $query =~ s! ! $trace !;
    $query;
}

sub prepare {
    my $self = shift;
    my $query = shift;
    $self->SUPER::prepare($self->__set_comment($query), @_);
}

sub do {
    my $self = shift;
    my ($query, $attr, @bind) = @_;
    $self->SUPER::do($self->__set_comment($query), $attr, @bind);
}

sub select_one {
    my ($self, $query, @bind) = @_;
    my $row = $self->selectrow_arrayref($query, {}, @bind);
    return unless $row;
    return $row->[0];
}

sub select_row {
    my ($self, $query, @bind) = @_;
    my $row = $self->selectrow_hashref($query, {}, @bind);
    return unless $row;
    return $row;
}

sub select_all {
    my ($self, $query, @bind) = @_;
    my $rows = $self->selectall_arrayref($query, { Slice => {} }, @bind);
    return $rows;
}

sub query {
    my ($self, $query, @bind) = @_;
    my $sth = $self->prepare($query);
    $sth->execute(@bind);
}


package DBIx::Sunny::st; # statement handler
our @ISA = qw(DBI::st);

1;

__END__

=encoding utf8

=head1 NAME

DBIx::Sunny - Simple but practical DBI wrapper

=head1 SYNOPSIS

    use DBIx::Sunny;

    my $dbh = DBIx::Sunny->connect(...);

    # or 

    use DBI;

    my $dbh = DBI->connect(.., { RootClass => 'DBIx::Sunny' });

=head1 DESCRIPTION

DBIx::Sunny is a simple but practical DBI wrapper. It provides better usability for you. This module based on Amon2::DBI.

=head1 FEATURES

=over 4

=item Set AutoInactiveDestroy to true.

DBIx::Sunny set AutoInactiveDestroy as true.

=item Set sqlite_unicode and mysql_enable_utf8 automatically

DBIx::Sunny set sqlite_unicode and mysql_enable_utf8 automatically.

=item Nested transaction management.

DBIx::Sunny supports nested transaction management based on RAII like DBIx::Class or DBIx::Skinny. It uses L<DBIx::TransactionManager> internally.

=item Error Handling

DBIx::Sunny set RaiseError and ShowErrorStatement as true. DBIx::Sunny raises exception and shows current statement if your $dbh occurred exception.

=item SQL comment

DBIx::Sunny adds file name and line number as SQL commnet that invokes SQL statement.

=back

=head1 ADDITIONAL METHODS

=over 4

=item $col = $dbh->select_one($query, @bind);

Shortcut for prepare, execute and fetchrow_arrayref->[0]

=item $row = $dbh->select_row($query, @bind);

Shortcut for prepare, execute and fetchrow_hashref

=item $rows = $dbh->select_all($query, @bind);

Shortcut for prepare, execute and selectall_arrayref(.., { Slice => {} }, ..)

=item $dbh->query($query, @bind);

Shortcut for prepare, execute. 

=back

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

L<DBI>, L<Amon2::DBI>

=head1 LICENSE

Copyright (C) Masahiro Nagano

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
