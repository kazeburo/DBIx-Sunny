package DBIx::Sunny;

use strict;
use warnings;
use Carp;
use Log::Minimal;
use Scope::Container;
use List::Util qw/shuffle/;
use Data::Dumper;
use Class::Accessor::Lite;
use DBI;

our $VERSION = '0.01';
Class::Accessor::Lite->mk_ro_accessors(qw/master slave on_connect/);

sub new {
    my $class = shift;
    my %args = @_;
    my $master = delete $args{master};
    my $slave = delete $args{slave};
    my $on_connect = delete $args{on_connect} // sub {};
    bless {
        master => $master,
        slave => $slave,
        on_connect => $on_connect,
    }, $class;
};

sub master_dbh {
    my $self = shift;
    croak 'This instance has no master database' unless $self->master;
    $self->{_master_dbh} //= $self->_connect(@{$self->master});
    $self->{_master_dbh};
};

sub slave_dbh {
    my $self = shift;
    return $self->master_dbh unless $self->slave;
    $self->{_slave_dbh} //= $self->_connect(@{$self->slave});
    $self->{_slave_dbh};
};

sub _connect {
    my $self = shift;
    if ( @_ && (ref $_[0] || '' eq 'ARRAY') ) {
        my @dsn = @_;
        my $dbi;
        my $dsn_key = _build_dsn_key(@dsn);
        my $dbh = _lookup_container($dsn_key);
        return $dbh if $dbh;

        for my $s_dsn ( shuffle(@dsn) ) {
            eval {
                ($dbh, $dbi) = $self->_connect(@$s_dsn);
            };
            infof("Connection failed: " . $@) if $@;
            last if ( $dbh );
        }

        if ( $dbh ) {
            _save_container($dsn_key, $dbi);
            return wantarray ? ( $dbh, $dbi) : $dbh;
        }
        
        croak("couldnt connect all DB, " .
            join(",", map { $_->[0] } @dsn));
    }

    my @dsn = @_;
    my $dsn_key = _build_dsn_key(\@dsn);     
    my $cached_dbh = _lookup_cache($dsn_key);
    return $cached_dbh if $cached_dbh;

    my ($dsn, $user, $pass, $attr) = @dsn;
    $attr->{PrintError} = 0;
    $attr->{RaiseError} = 0;
    $attr->{HandleError} = sub {
        Carp::croak(shift);
    };

    my $dbh = DBI->connect($dsn, $user, $pass, $attr);
    $dbh->STORE(AutoInactiveDestroy => 1);

    my $driver_name = $dbh->{Driver}->{Name};
    if ( $driver_name eq 'mysql' ) {
        $dbh->{mysql_enable_utf8} = 1;
        $dbh->do("SET NAMES utf8");
    }
    elsif ( $driver_name eq 'SQLite' ) {
        $dbh->{sqlite_unicode} = 1;
    }

    $self->on_connect->($dbh);
    my $dbi = {
        dbh => $dbh,
        pid => $$,
    };

    _save_cache($dsn_key, $dbi);
    return wantarray ? ( $dbh, $dbi ) : $dbh;
    
};

sub _build_dsn_key {
    my @dsn = @_;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 0;
    my $key = Data::Dumper::Dumper(\@dsn);
    "dbix::sunny::".$key;
}

sub _lookup_cache {
    my $key = shift;
    return unless in_scope_container();
    my $dbi = scope_container($key);
    return if !$dbi;
    my $dbh = $dbi->{dbh};
    if ( $dbi->{pid} != $$ ) {
        $dbh->STORE(InactiveDestroy => 1);
        return;
    }
    return $dbh if $dbh->FETCH('Active') && $dbh->ping;
    return;
}

sub _save_cache {
    my $key = shift;
    return unless in_scope_container();
    scope_container($key, shift);
}

sub select_one {
    my $self = shift;
    my $query = shift;
    my @bind = @_;
    my $ret = $self->slave_dbh->selectrow_arrayref($query, undef, @bind);
    return unless $ret;
    return $ret->[0];
}

sub select_one_from_master {
    my $self = shift;
    my $query = shift;
    my @bind = @_;
    my $ret = $self->master_dbh->selectrow_arrayref($query, undef, @bind);
    return unless $ret;
    return $ret->[0];
}

sub select_row {
    my $self = shift;
    my $query = shift;
    my @bind = @_;
    $self->slave_dbh->selectrow_hashref($query, undef, @bind);
}

sub select_row_from_master {
    my $self = shift;
    my $query = shift;
    my @bind = @_;
    $self->master_dbh->selectrow_hashref($query, undef, @bind);
}

sub select_all {
    my $self = shift;
    my $query = shift;
    my @bind = @_;
    $self->slave_dbh->selectall_arrayref($query, { Slice=>{} }, @bind);
}

sub select_all_from_master {
    my $self = shift;
    my $query = shift;
    my @bind = @_;
    $self->master_dbh->selectall_arrayref($query, { Slice=>{} }, @bind);
}

sub query {
    my $self = shift;
    my $query = shift;
    my @bind = @_;
    $self->master_dbh->do( $query, undef, @bind);
}

sub begin_work {
    my $self = shift;
   $self->master_dbh->begin_work;
}

sub rollback {
    my $self = shift;
    $self->master_dbh->rollback;
}

sub commit {
    my $self = shift;
    $self->master_dbh->commit;
}

sub func {
    my $self = shift;
    $self->master_dbh->func(@_);
}

sub last_insert_id {
    my $self = shift;
    my $driver_name = $self->master_dbh->{Driver}->{Name};
    if ( $driver_name eq 'mysql' ) {
        return $self->master_dbh->{mysql_insertid};
    }
    elsif ( $driver_name eq 'SQLite' ) {
        return $self->master_dbh->sqlite_last_insert_rowid();
    }
    return $self->master_dbh->last_insert_id;
}

sub query_to_slave {
    my $self = shift;
    my $query = shift;
    my @bind = @_;
    $self->slave_dbh->do($query,undef,@bind);
}

sub begin_work_to_slave {
    my $self = shift;
    $self->slave_dbh->begin_work;
}

sub rollback_to_slave {
    my $self = shift;
    $self->slave_dbh->rollback;
}

sub commit_to_slave {
    my $self = shift;
    $self->slave_dbh->commit;
}

sub func_to_slave {
    my $self = shift;
    $self->slave_dbh->func(@_);
}

sub last_insert_id_from_slave {
    my $self = shift;
    my $driver_name = $self->slave_dbh->{Driver}->{Name};
    if ( $driver_name eq 'mysql' ) {
        return $self->slave_dbh->{mysql_insertid};
    }
    elsif ( $driver_name eq 'SQLite' ) {
        return $self->slave_dbh->sqlite_last_insert_rowid();
    }
    $self->slave_dbh->last_insert_id;
}


1;
__END__

=head1 NAME

DBIx::Sunny - OreOre DBI wrapper

=head1 SYNOPSIS

  use DBIx::Sunny;

=head1 DESCRIPTION

DBIx::Sunny is

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
