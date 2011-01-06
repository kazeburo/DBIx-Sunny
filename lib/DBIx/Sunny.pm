package DBIx::Sunny;

use strict;
use warnings;
use Carp;
use parent qw/Class::Data::Inheritable/;
use Class::Accessor::Lite;
use Data::Validator;
use DBIx::TransactionManager;
use DBI qw/:sql_types/;

our $VERSION = '0.01';
Class::Accessor::Lite->mk_ro_accessors(qw/dbh readonly/);

sub new {
    my $class = shift;
    my %args = @_;
    bless {
        readonly => delete $args{readonly},
        dbh => delete $args{dbh},
    }, $class;
};

sub build_one {
    my $class = shift;
    my @args = @_;
    $class->__setup_accessors(
        sub {
            my $sth = shift;
            my $row = $sth->fetchrow_arrayref;
            return unless $row;
            return $row->[0];
        },
        @args;        
    );
}

sub build_row {
    my $class = shift;
    my @args = @_;
    $class->__setup_accessors(
        sub {
            my $sth = shift;
            my $row = $sth->fetchrow_hashref;
            return unless $row;
            return $row;
        },
        @args;
    );
}

sub build_all {
    my $class = shift;
    my @args = @_;
    $class->__setup_accessors(
        sub {
            my $sth = shift;
            my @rows;
            while( my $row = $sth->fetchrow_hashref ) {
                push @rows, $row;
            }
            return \@rows;
        },
        @args;
    );
}

sub build_query {
    my $class = shift;
    my @args = @_;
    $class->__setup_accessors(
        sub {
            my $sth = shift;
            my $ret = shift;
            return $ret;
        },
        @args;
    );
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
    $query;
}

sub __setup_accessors {
    my $class = shift;
    my $cb = shift;
    my $method = shift;
    my $query = pop;
    my @rules = @_;
    
    my $validators = $class->__validators;
    if ( !$validators ) {
        $validators = $class->__validators({});
    }        
    $validators->{$method} = Data::Validator->new(@rules);
    
    my @bind_keys;
    while(my($name, $rule) = splice @rules, 0, 2) {
        push @bind_keys, $name;
    }
    my $bind_keys = $class->__bind_keys;
    if ( !$bind_keys ) {
        $bind_keys = $class->__bind_keys({});
    }
    $bind_keys->{$method} = \@bind_keys;

    my $builder = sub {
        my $self = shift;
        my $validator = $self->__validators->{$method};
        my $args = $validator->validate(@_);
        my $commented_query = $self->set_comment($query);
        my $sth = $self->dbh->prepare($commented_query);
        my $i = 1;
        for my $key ( @{$self->__bind_keys->{$method}} ) {
            my $type = $validator->find_rule($key);
            my $bind_type = $type->is_a_type_of('Int') ? SQL_INTEGER :
                $type->is_a_type_of('Num') ? SQL_FLOAT : undef;
            if ( defined $bind_type ) {
                $sth->bind_param(
                    $i,
                    $args->{$key},
                    $bind_type
                );
            }
            else {
                $sth->bind_param(
                    $i,
                    $args->{$key},
                );
            }
        }
        my $ret = $sth->execute();
        $cb->($sth,$ret);
    };

    {
        no strict 'refs';
        *{"$class\::$method"} = $builder;
    }
}


sub select_one {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    my $ret = $self->dbh->selectrow_arrayref($query, undef, @bind);
    return unless $ret;
    return $ret->[0];
}

sub select_row {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    $self->dbh->selectrow_hashref($query, undef, @bind);
}


sub select_all {
    my $self = shift;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    $self->dbh->selectall_arrayref($query, { Slice=>{} }, @bind);
}

sub query {
    my $self = shift;
    Carp::croak "couldnot use query for readonly database handler" if $self->readonly;
    my $query = shift;
    $query = $self->set_comment($query);
    my @bind = @_;
    $self->dbh->do( $query, undef, @bind);
}

sub txn {
    my $self = shift;
    $self->{__txn} ||= DBIx::TransactionManager->new($self->dbh);
    $self->{__txn};
}

sub begin {
    my $self = shift;
   $self->txn->txn_work;
}

sub rollback {
    my $self = shift;
    $self->txn->txn_rollback;
}

sub commit {
    my $self = shift;
    $self->txn->txn_commit;
}

sub txn_scope {
    my $self = shift;
    $self->txn->txn_scope;
}

sub func {
    my $self = shift;
    $self->dbh->func(@_);
}

sub last_insert_id {
    my $self = shift;
    my $driver_name = $self->dbh->{Driver}->{Name};
    if ( $driver_name eq 'mysql' ) {
        return $self->dbh->{mysql_insertid};
    }
    elsif ( $driver_name eq 'SQLite' ) {
        return $self->dbh->sqlite_last_insert_rowid();
    }
}


1;
__END__

=encoding utf-8

=head1 NAME

DBIx::Sunny - Sunny DBI wrapper

=head1 SYNOPSIS

  package MyProj::Data::DB;
  
  use parent qw/DBIx::Sunny/;
  use Mouse::Util::TypeConstraints;
  
  subtype 'Uint'
      => as 'Int'
      => where { $_ >= 0 };
  
  subtype 'Natural'
      => as 'Int'
      => where { $_ = 0 };
  
  enum 'Flag' => qw/1 0/;
  
  __PACKAGE__->build_one(
      'max_id',
      'SELECT max(id) FROM member'
  );
  
  __PACKAGE__->build_row(
      'member',
      'SELECT * FROM member WHERE id=?',
      id => { isa => 'Natural' }
  );
  
  __PACAKGE__->build_all(
      'recent_article',
      'SELECT * FROM articles WHERE public=? ORDER BY created_on LIMIT ?,?',
      public => { isa => 'Flag', default => 1 },
      offset => { isa => 'Uint', default => 0 },
      limit  => { isa => 'Uint', default => 10 },
  );
  
  __PACKAGE__->build_query(
      'add_article',
      'INSERT INTO articles (member_id, public, subject, body, created_on) 
       VALUES ( ?, ?, ?, ?, ?)',
      member_id => { isa => 'Natural' },
      flag => { isa => 'Flag', default => '1' },
      subject => { isa => 'Str' },
      body => { isa => 'Str' },
      created_on => { isa => .. }
  );
  
  __PACKAGE__->build_one(
      'article_count_by_member',
      'SELECT COUNT(*) FROM articles WHERE member_id = ?',
      member_id => { isa => 'Natural' },
  );
  
  __PACKAGE__->build_query(
      'update_member_article_count',
      'UPDATE member SET article_count = ? WHERE id = ?',
      article_count => { isa => 'Uint' },
      id => { isa => 'Natural' }
  );
  
  
  ...
  
  
  package main;
  
  use MyProj::Data::DB;
  use DBI;
  
  my $dbh = DBI->connect(...);
  my $db = MyProj::Data::DB->new(dbh=>$dbh,readonly=>0);
  
  my $max = $db->max_id;
  my $member_hashref = $db->member(id=>100); 
  # my $member = $db->member(id=>'abc');  #validator error
  
  my $article_arrayref = $db->recent_article( offset => 10 );
  
  {
      my $txn = $db->txn_scope;
      $db->add_article(
          member_id => $id,
          subject => $subject,
          body => $body,
          created_on => 
      );
      my $last_insert_id = $db->last_insert_id;
      my $count = $db->article_count_by_member( id => $id );
      $db->update_member_article_count(
          article_count => $count,
          id => $id
      );
      $txn->commit;
  }
  
=head1 DESCRIPTION

=head1 METHODS

=head2 new({ dbh => DBI, readonly => ENUM(0,1) )

=head2 select_one($query, @binds);
 
SQLを実行し、1行目の1つめのカラムを取得。クエリは slave データベースに発行される

=head2 select_row

=head2 select_all

=head2 query

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
