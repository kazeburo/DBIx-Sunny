package DBIx::Sunny;

use strict;
use warnings;
use 5.008005;
use DBI 1.615;

our $VERSION = '0.22';

use parent qw/DBI/;

sub connect {
    my $class = shift;
    my ($dsn, $user, $pass, $attr) = @_;
    $attr->{RaiseError} = 1;
    $attr->{PrintError} = 0;
    $attr->{ShowErrorStatement} = 1;
    $attr->{AutoInactiveDestroy} = 1;
    if ($dsn =~ /^(?i:dbi):SQLite:/) {
        $attr->{sqlite_use_immediate_transaction} = 1;
        $attr->{sqlite_unicode} = 1 unless exists $attr->{sqlite_unicode};
    }
    if ($dsn =~ /^(?i:dbi):mysql:/ && ! exists $attr->{mysql_enable_utf8} ) {
        $attr->{mysql_enable_utf8} = 1;
    }
    $class->SUPER::connect($dsn, $user, $pass, $attr);
}

package DBIx::Sunny::db;
our @ISA = qw(DBI::db);

use DBIx::TransactionManager;
use Scalar::Util qw/weaken/;

sub connected {
    my $dbh = shift;
    my ($dsn, $user, $pass, $attr) = @_;
    $dbh->{RaiseError} = 1;
    $dbh->{PrintError} = 0;
    $dbh->{ShowErrorStatement} = 1;
    $dbh->{AutoInactiveDestroy} = 1;
    if ($dsn =~ /^dbi:SQLite:/) {
        $dbh->{sqlite_use_immediate_transaction} = 1;
        $dbh->{sqlite_unicode} = 1 unless exists $attr->{sqlite_unicode};

        $dbh->do("PRAGMA journal_mode = WAL");
        $dbh->do("PRAGMA synchronous = NORMAL");

    }
    if ($dsn =~ /^dbi:mysql:/ && ! exists $attr->{mysql_enable_utf8} ) {
        $dbh->{mysql_enable_utf8} = 1;
        $dbh->do("SET NAMES utf8");
    }
    if ($dsn =~ /^dbi:mysql:/) {
        $dbh->{mysql_auto_reconnect} = 0;
    }
    $dbh->{private_connect_info} = [@_];
    $dbh->SUPER::connected(@_);
}

sub connect_info { $_[0]->{private_connect_info} }

sub txn_scope {
    my $self = shift;
    if ( ! $self->{private_txt_manager} ) {
        $self->{private_txt_manager} = DBIx::TransactionManager->new($self);
        weaken($self->{private_txt_manager}->{dbh});
    } 
    $self->{private_txt_manager}->txn_scope(
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

sub fill_arrayref {
    my $self = shift;
    my ($query, @bind) = @_;
    return if ! defined $query;
    my @bind_param;
    $query =~ s{
        \?
    }{
        my $bind = shift @bind;
        if (ref($bind) && ref($bind) eq 'ARRAY') {
            push @bind_param, @$bind;
            join ',', ('?') x @$bind;
        } else {
            push @bind_param, $bind;
            '?';
        }
    }gex;
    return ( $query, @bind_param );
}

sub select_one {
    my $self = shift;
    my ($query, @bind) = $self->fill_arrayref(@_);
    my $row = $self->selectrow_arrayref($query, {}, @bind);
    return unless $row;
    return $row->[0];
}

sub select_row {
    my $self = shift;
    my ($query, @bind) = $self->fill_arrayref(@_);
    my $row = $self->selectrow_hashref($query, {}, @bind);
    return unless $row;
    return $row;
}

sub select_all {
    my $self = shift;
    my ($query, @bind) = $self->fill_arrayref(@_);
    my $rows = $self->selectall_arrayref($query, { Slice => {} }, @bind);
    return $rows;
}

sub query {
    my $self = shift;
    my ($query, @bind) = $self->fill_arrayref(@_);
    my $sth = $self->prepare($query);
    $sth->execute(@bind);
}

sub last_insert_id {
    my $self = shift;
    my $dsn = $self->connect_info->[0];
    if ($dsn =~ /^(?i:dbi):SQLite:/) {
        return $self->func('last_insert_rowid');
    }
    elsif ( $dsn =~ /^(?i:dbi):mysql:/) {
        return $self->{mysql_insertid};
    }
    $self->SUPER::last_insert_id(@_);
}

package DBIx::Sunny::st; # statement handler
our @ISA = qw(DBI::st);

1;

__END__

=encoding utf8

=head1 NAME

DBIx::Sunny - Simple DBI wrapper

=head1 SYNOPSIS

    use DBIx::Sunny;

    my $dbh = DBIx::Sunny->connect(...);

    # or 

    use DBI;

    my $dbh = DBI->connect(.., {
        RootClass => 'DBIx::Sunny',
        PrintError => 0,
        RaiseError => 1,
    });

=head1 DESCRIPTION

DBIx::Sunny is a simple DBI wrapper. It provides better usability for you. This module based on Amon2::DBI.
DBIx::Sunny supports only SQLite and MySQL.

=head1 FEATURES

=over 4

=item Set AutoInactiveDestroy to true.

DBIx::Sunny sets AutoInactiveDestroy as true.

=item [SQLite/MySQL] Auto encode/decode utf-8

DBIx::Sunny sets sqlite_unicode and mysql_enable_utf8 automatically.

=item [SQLite] Performance tuning

DBIx::Sunny sets sqlite_use_immediate_transaction to true, and executes these PRAGMA statements

  PRAGMA journal_mode = WAL
  PRAGMA synchronous = NORMAL

=item Nested transaction management.

DBIx::Sunny supports nested transaction management based on RAII like DBIx::Class or DBIx::Skinny. It uses L<DBIx::TransactionManager> internally.

=item Error Handling

DBIx::Sunny sets RaiseError and ShowErrorStatement as true. DBIx::Sunny raises exception and shows current statement if your $dbh occurred exception.

=item SQL comment

DBIx::Sunny adds file name and line number as SQL comment that invokes SQL statement.

=item Easy access to last_insert_id

DBIx::Sunny's last_insert_id needs no arguments. It's shortcut for mysql_insertid or last_insert_rowid.

=item Auto expanding arrayref bind parameters

select_(one|row|all) and  query methods support auto-expanding arrayref bind parameters.

  $dbh->select_all('SELECT * FROM id IN (?)', [1 2 3])
  #SQL: 'SELECT * FROM id IN (?,?,")'
  #@BIND: (1, 2, 3)

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

Masahiro Nagano E<lt>kazeburo KZBRKZBR@ gmail.comE<gt>

=head1 SEE ALSO

L<DBI>, L<Amon2::DBI>

=head1 LICENSE

Copyright (C) Masahiro Nagano

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
