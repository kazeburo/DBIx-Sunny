package DBIx::Sunny;

use strict;
use warnings;
use 5.008005;
use DBI 1.615;

our $VERSION = '0.24';

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
    if ($dsn =~ /^(?i:dbi):mysql:/ && ! exists $attr->{mysql_enable_utf8} && ! exists $attr->{mysql_enable_utf8mb4} ) {
        $attr->{mysql_enable_utf8} = 1;
    }
    $class->SUPER::connect($dsn, $user, $pass, $attr);
}

package DBIx::Sunny::db;
our @ISA = qw(DBI::db);

use DBIx::TransactionManager;
use Scalar::Util qw/weaken blessed/;

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
    if ($dsn =~ /^dbi:mysql:/ && ! exists $attr->{mysql_enable_utf8} && ! exists $attr->{mysql_enable_utf8mb4} ) {
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
        last if $caller[0] ne ref($self) && $caller[0] !~ /^(:?DBIx?|DBD|Try::Tiny|Context::Preserve)\b/;
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

sub __fill_arrayref {
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
    my $maybe_typed = scalar(grep { ref($_) } @bind_param);
    return ( $query, $maybe_typed, @bind_param );
}

sub fill_arrayref {
    my $self = shift;
    my ($query, undef, @bind) = $self->__fill_arrayref(@_);
    return ( $query, @bind );
}

sub __prepare_and_execute {
    my $self = shift;
    my ($query, @bind) = @_;
    my $sth = $self->prepare($query);
    my $i = 0;
    for my $bind ( @bind ) {
        if ( blessed($bind) && $bind->can('value_ref') && $bind->can('type') ) {
            # If $bind is an SQL::Maker::SQLType or compatible object, use its type info.
            $sth->bind_param(++$i, ${ $bind->value_ref }, $bind->type);
        } else {
            $sth->bind_param(++$i, $bind);
        }
    }
    my $ret = $sth->execute;
    return ( $sth, $ret );
}

sub select_one {
    my $self = shift;
    my ($query, $maybe_typed, @bind) = $self->__fill_arrayref(@_);
    my $row;
    if ( $maybe_typed ) {
        my ($sth, $ret) = $self->__prepare_and_execute($query, @bind);
        $row = $ret && $sth->fetchrow_arrayref;
    } else {
        $row = $self->selectrow_arrayref($query, {}, @bind);
    }
    return unless $row;
    return $row->[0];
}

sub select_row {
    my $self = shift;
    my ($query, $maybe_typed, @bind) = $self->__fill_arrayref(@_);
    my $row;
    if ( $maybe_typed ) {
        my ($sth, $ret) = $self->__prepare_and_execute($query, @bind);
        $row = $ret && $sth->fetchrow_hashref;
    } else {
        $row = $self->selectrow_hashref($query, {}, @bind);
    }
    return unless $row;
    return $row;
}

sub select_all {
    my $self = shift;
    my ($query, $maybe_typed, @bind) = $self->__fill_arrayref(@_);
    my $rows;
    if ( $maybe_typed ) {
        my ($sth, $ret) = $self->__prepare_and_execute($query, @bind);
        $rows = $ret && $sth->fetchall_arrayref({});
    } else {
        $rows = $self->selectall_arrayref($query, { Slice => {} }, @bind);
    }
    return $rows;
}

sub query {
    my $self = shift;
    my ($query, $maybe_typed, @bind) = $self->__fill_arrayref(@_);
    my $ret;
    if ( $maybe_typed ) {
        (undef, $ret) = $self->__prepare_and_execute($query, @bind);
    } else {
        my $sth = $self->prepare($query);
        $ret = $sth->execute(@bind);
    }
    return $ret;
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

=item Typed bind parameters

DBIx::Sunny allows you to specify data types of bind parameters. If a bind parameter is L<SQL::Maker::SQLType> object, its value is passed as its type, otherwise it is passed as default type (VARCHAR).

  use SQL::Maker::SQLType qw/sql_type/;
  use DBI qw/:sql_types/

  $dbh->query(
      'INSERT INTO bin_table (bin_col) VALUES (?)',
      sql_type(\"\xDE\xAD\xBE\xEF", SQL_BINARY)),
  );

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
