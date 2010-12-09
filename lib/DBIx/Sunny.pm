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
use DBIx::Printf;

our $VERSION = '0.01';
Class::Accessor::Lite->mk_ro_accessors(qw/master slave on_connect/);

sub new {
    my $class = shift;
    my %args = @_;
    my $master = delete $args{master};
    my $slave = delete $args{slave};
    my $on_connect = delete $args{on_connect} || sub {};
    bless {
        master => $master,
        slave => $slave,
        on_connect => $on_connect,
    }, $class;
};

sub master_dbh {
    my $self = shift;
    croak 'This instance has no master database' unless $self->master;
    $self->{_master_dbh} ||= $self->_connect(@{$self->master});
    $self->{_master_dbh};
};

sub slave_dbh {
    my $self = shift;
    return $self->master_dbh unless $self->slave;
    $self->{_slave_dbh} ||= $self->_connect(@{$self->slave});
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
        
        croak("couldn't connect all DB, " .
            join(",", map { $_->[0] } @dsn));
    }

    my @dsn = @_;
    my $dsn_key = _build_dsn_key(\@dsn);     
    my $cached_dbh = _lookup_cache($dsn_key);
    return $cached_dbh if $cached_dbh;

    my ($dsn, $user, $pass, $attr) = @dsn;
    $attr->{AutoInactiveDestroy} = 1;
    $attr->{PrintError} = 0;
    $attr->{RaiseError} = 0;
    $attr->{HandleError} = sub {
        Carp::croak(shift);
    };

    my ($scheme, $driver, $attr_string, $attr_hash, $driver_dsn) = DBI->parse_dsn($dsn);
    if ( $driver eq 'mysql' ) {
        $attr->{mysql_connect_timeout} = 5;
        $attr->{mysql_enable_utf8} = 1;
        $attr->{mysql_auto_reconnect} = 0;
    }
    elsif ( $driver eq 'SQLite' ) {
        $attr->{sqlite_unicode} = 1;
    }
    else {
        Carp::croak( "'$driver' is not supported" );
    }

    debugf("connect to '$dsn'");
    my $dbh = DBI->connect($dsn, $user, $pass, $attr);
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

sub set_comment {
    my $self = shift;
    my $query = shift;

    my $trace;
    my $i = 0;
    while ( my @caller = caller($i) ) {
        $trace = "/* $caller[1] line $caller[2] */"; 
        last if $caller[0] ne ref($self) && $caller[0] ne __PACKAGE__;
        $i++;
    }
    $query =~ s! ! $trace !;
    debugf $query;
    $query;
}

sub select_one {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    my $ret = $self->slave_dbh->selectrow_arrayref($query, undef, @bind);
    return unless $ret;
    return $ret->[0];
}

sub selectf_one {
    my $self = shift;
    my $format = shift;
    $self->select_one(
        $self->slave_dbh->printf($format, @_)
    );
}

sub select_one_from_master {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    my $ret = $self->master_dbh->selectrow_arrayref($query, undef, @bind);
    return unless $ret;
    return $ret->[0];
}

sub selectf_one_from_master {
    my $self = shift;
    my $format = shift;
    $self->select_one_from_master(
        $self->master_dbh->printf($format, @_)
    );
}

sub select_row {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    $self->slave_dbh->selectrow_hashref($query, undef, @bind);
}

sub selectf_row {
    my $self = shift;
    my $format = shift;
    $self->select_row(
        $self->slave_dbh->printf($format, @_)
    );
}

sub select_row_from_master {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    $self->master_dbh->selectrow_hashref($query, undef, @bind);
}

sub selectf_row_from_master {
    my $self = shift;
    my $format = shift;
    $self->select_row_from_master(
        $self->master_dbh->printf($format, @_)
    );
}

sub select_all {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    $self->slave_dbh->selectall_arrayref($query, { Slice=>{} }, @bind);
}

sub selectf_all {
    my $self = shift;
    my $format = shift;
    $self->select_all(
        $self->slave_dbh->printf($format, @_)
    );
}

sub select_all_from_master {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    $self->master_dbh->selectall_arrayref($query, { Slice=>{} }, @bind);
}

sub selectf_all_from_master {
    my $self = shift;
    my $format = shift;
    $self->select_all_from_master(
        $self->master_dbh->printf($format, @_)
    );
}

sub query {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    $self->master_dbh->do( $query, undef, @bind);
}

sub queryf {
    my $self = shift;
    my $format = shift;
    $self->query(
        $self->master_dbh->printf($format, @_)
    );
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
}


1;
__END__

=encoding utf-8

=head1 NAME

DBIx::Sunny - Sunny DBI wrapper

=head1 SYNOPSIS

  use DBIx::Sunny;
  use Scope::Container;

  {
      my $sc = start_scope_container();
      my $sunny = DBIx::Sunny->new({
          master => ["dbi:mysql:mydb;host=dbm1","user","password"],
          slave  => [
              ["dbi:mysql:mydb;host=dbs1","user","password"],
              ["dbi:mysql:mydb;host=dbs2","user","password"],
              ["dbi:mysql:mydb;host=dbs3","user","password"],
          ],
      });

      my $result = $sunny->query("INSERT INTO member (user_id,name) VALUES (?,?)",
                                 "kazeburo", "Masahiro Nagano");

      my $id = $sunny->last_insert_id;

      my $count = $sunny->select_one("SELECT count(*) FROM member");

      my $row = $sunny->select_row("SELECT * FROM member WHERE id = ?", $id);

      my $rows = $sunny->select_all("SELECT * FROM member ORDER BY id desc LIMIT 10");
  }

=head1 DESCRIPTION

DBIx::Sunny は O/R MapperではなくシンプルなDBIのラッパーです。Scope::Containerによる接続の管理
レプリケーションなどによるmaster/slave構成をサポート、UTF8テキスト文字列の自動変換などを行います。
MySQLとSQLiteのみをサポートしています。

=head1 METHODS

=head2 new({ master => Arrayref, slave => Arrayref, on_connect => Subref )

DBIx::Sunnyのインスタンスを作ります。master、slave、on_connectのオプションを受け取ります。

=head3 master: Arrayref

master データベースの接続に必要な情報です。Arrayrefでdsn,username,passwordを渡します。

  master => ["dbi:mysql:database=mydb","user","password"]

データベースに接続する際には、DBIx::Sunnyモジュールにてエラーハンドリングのオプションを付加します。
PrintErrorと RaiseErrorは無効にされ、 HandleErrorに例外を返すコールバックが指定されます。 
また、MySQLの場合、 mysql_connect_timeout を5秒に、 mysql_auto_reconnectを無効にし、 
mysql_enable_utf8を有効にします。
SQLiteの場合は、 sqlite_unicodeを有効にします。

=head3 slave: Arrayref

slave データベースの情報を渡します。複数のslaveサーバがある場合は、Arrayrefにて指定します。複数個のdsnが
渡された場合、ランダムに選び出し接続可能なdsnを利用します。

  slave => [
      ["dbi:mysql:mydb;host=dbs1","user","password"],
      ["dbi:mysql:mydb;host=dbs2","user","password"],
      ["dbi:mysql:mydb;host=dbs3","user","password"],
  ],

=head3 on_connect: Subref

データベースに接続した際に呼ばれます。

  on_connect => sub {
      my $dbh = shift;
      ...
  },

第一引数に接続が完了したdbhが渡されます

=head2 master_dbh

接続済みのmasterデータベースのdbh

=head2 slave_dbh

接続済みのslaveデータベースのdbh。slaveが指定されていない場合は、masterが返る

=head2 select_one($query, @binds);

SQLを実行し、1行目の1つめのカラムを取得。クエリは slave データベースに発行される

=head2 selectf_one($format, @values);

DBIx::Printfにてクエリを生成し、select_oneを実行

=head2 select_one_from_master

select_oneと同じ。ただし master データベースに発行される

=head2 selectf_one_from_master

selectf_oneと同じ。ただし master データベースに発行される

=head2 select_row

=head2 selectf_row

=head2 select_row_from_master

=head2 selectf_row_from_master

=head2 select_all

=head2 selectf_all

=head2 select_all_from_master

=head2 selectf_all_from_master

=head2 query

=head2 queryf

=head2 begin_work

=head2 commit

=head2 rollback

=head2 last_insert_id

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

C<DBI>, C<DBIx::Printf>, C<DBD::mysql>, C<DBD::SQLite>, C<Scope::Container>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
