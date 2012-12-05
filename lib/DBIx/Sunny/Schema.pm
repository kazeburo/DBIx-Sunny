package DBIx::Sunny::Schema;

use strict;
use warnings;
use Carp qw/croak/;
use parent qw/Class::Data::Inheritable/;
use Class::Accessor::Lite;
use Data::Validator;
use DBIx::TransactionManager;
use DBI qw/:sql_types/;

$Carp::Internal{"DBIx::Sunny::Schema"} = 1;

Class::Accessor::Lite->mk_ro_accessors(qw/dbh readonly/);

__PACKAGE__->mk_classdata( '__validators' );
__PACKAGE__->mk_classdata( '__deflaters' );

sub new {
    my $class = shift;
    my %args = @_;
    bless {
        readonly => delete $args{readonly},
        dbh => delete $args{dbh},
    }, $class;
};

sub fill_arrayref {
    my $self = shift;
    my ($query, @bind) = @_;
    return if ! defined $query;
    my @bind_param;
    my $modified_query = $query;
    my $i=1;
    for my $bind ( @bind ) {
        if ( ref($bind) && ref($bind) eq 'ARRAY' ) {
            my $array_query = substr('?,' x scalar(@{$bind}), 0, -1);
            my $search_i=0;
            my $replace_query = sub {
                $search_i++;
                if ( $search_i == $i ) {
                    return $array_query;
                }
                return '?';
            };
            $modified_query =~ s/\?/$replace_query->()/ge;
            push @bind_param, @{$bind};
        }
        else {
            push @bind_param, $bind;
        }
        $i++;
    }
    return ($modified_query, @bind_param);
}


sub select_one {
    my $class = shift;
    if ( ref $class ) {
        my ($query, @bind) = $class->fill_arrayref(@_);
        my $row = $class->dbh->selectrow_arrayref($query, {}, @bind);
        return unless $row;
        return $row->[0];
    }
    my @args = @_;
    $class->__setup_accessor(
        sub {
            my $do_query = shift;
            my $self = shift;
            my ( $sth, $ret ) = $do_query->($self,@_);
            my $row = $sth->fetchrow_arrayref;
            $sth->finish;
            return unless $row;
            return $row->[0];
        },
        @args
    );
}

sub select_row {
    my $class = shift;
    if ( ref $class ) {
        my ($query, @bind) = $class->fill_arrayref(@_);
        my $row = $class->dbh->selectrow_hashref($query, {}, @bind);
        return unless $row;
        return $row;
    }
    my $filter;
    $filter = pop @_ if ref $_[-1] && ref $_[-1] eq 'CODE';
    my @args = @_;
    $class->__setup_accessor(
        sub {
            my $do_query = shift;
            my $self = shift;
            my ( $sth, $ret ) = $do_query->($self,@_);
            my $row = $sth->fetchrow_hashref;
            $sth->finish;
            return unless $row;
            if ( $filter ) {
                $filter->($row, $self);
            }
            return $row;
        },
        @args
    );
}

sub select_all {
    my $class = shift;
    if ( ref $class ) {
        my ($query, @bind) = $class->fill_arrayref(@_);
        my $rows = $class->dbh->selectall_arrayref($query, { Slice => {} }, @bind);
        return $rows;
    }
    my $filter;
    $filter = pop @_ if ref $_[-1] && ref $_[-1] eq 'CODE';
    my @args = @_;
    $class->__setup_accessor(
        sub {
            my $do_query = shift;
            my $self = shift;
            my ( $sth, $ret ) = $do_query->($self,@_);
            my @rows;
            while( my $row = $sth->fetchrow_hashref ) {
                if ( $filter ) {
                    $filter->($row, $self);
                }
                push @rows, $row;
            }
            $sth->finish;
            return \@rows;
        },
        @args
    );
}

sub query {
    my $class = shift;
    if ( ref $class ) {
        my ($query, @bind) = $class->fill_arrayref(@_);
        croak "couldnot use query for readonly database handler" if $class->readonly;
        my $sth = $class->prepare($query);
        return $sth->execute(@bind);
    }
    my @args = @_;
    $class->__setup_accessor(
        sub {
            my $do_query = shift;
            my $self = shift;
            croak "couldnot use query for readonly database handler" if $self->readonly;
            my ( $sth, $ret ) = $do_query->($self, @_);
            $sth->finish;
            return $ret;
        },
        @args
    );
}

sub args {
    my $self = shift;

    my $class = ref $self ? ref $self : $self;
    my $method = [caller(1)]->[3];


    my $validators = $class->__validators;
    if ( !$validators ) {
        $validators = $class->__validators({});
    }
    my $deflaters = $class->__deflaters;
    if ( !$deflaters ) {
        $deflaters = $class->__deflaters({});
    }

    if ( ! exists $validators->{$method} ) {
        my @rules;
        my %deflater;
        while ( my ($name,$rule) = splice @_, 0, 2 ) {
            $rule = ref $rule ? $rule : { isa => $rule };
            if ( my $deflater = delete $rule->{deflater} ) {
                croak("deflater must be CodeRef in rule:$name")
                    if ( !ref($deflater) || ref($deflater) ne 'CODE');
                $deflater{$name} = $deflater;
            }
            push @rules, $name, $rule;
        } 
        $deflaters->{$method} = \%deflater;
        $validators->{$method} = Data::Validator->new(@rules);
    }

    my @caller_args;
    {
        package DB;
        () = caller(1);
        shift @DB::args if $class eq ( ref($DB::args[0]) || $DB::args[0] );
        @caller_args = @DB::args;
    }
    local $Carp::CarpLevel = 3;
    local $Carp::Internal{'Data::Validator'} = 1;   
    my $result = $validators->{$method}->validate(@caller_args);

    if ( my @deflaters = keys %{$deflaters->{$method}} ) {
        &Internals::SvREADONLY($result, 0);
        for ( @deflaters ) {
            $result->{$_} = $deflaters->{$method}->{$_}->($result->{$_});
        }
        &Internals::SvREADONLY($result, 1);
    }
    $result;
}

sub __setup_accessor {
    my $class = shift;
    my $cb = shift;
    my $method = shift;
    my $query = pop;

    my @rules;
    my %deflater;
    my @bind_keys;
    while ( my ($name,$rule) = splice @_, 0, 2 ) {
        $rule = ref $rule ? $rule : { isa => $rule };
        if ( my $deflater = delete $rule->{deflater} ) {
            croak("deflater must be CodeRef in rule:$name")
                if ( !ref($deflater) || ref($deflater) ne 'CODE');
            $deflater{$name} = $deflater;
        }
        push @bind_keys, $name;
        push @rules, $name, $rule;
    } 
    my $validator = Data::Validator->new(@rules);

    my $do_query = sub {
        my $self = shift;
        local $Carp::Internal{'Data::Validator'} = 1;
        my $args = $validator->validate(@_);
        my $modified_query = $query;

        my $i = 1;
        my @bind_params;
        for my $key ( @bind_keys ) {
            my $type = $validator->find_rule($key)->{type};
            if ( $type->is_a_type_of('ArrayRef') ) {
                my $type_parameter_bind_type = $self->type2bind($type->type_parameter);
                my @val = @{$args->{$key}};
                my $array_query = substr('?,' x scalar(@val), 0, -1);
                my $search_i=0;
                my $replace_query = sub {
                    $search_i++;
                    if ( $search_i == $i ) {
                        return $array_query;
                    }
                    return '?';
                };
                $modified_query =~ s/\?/$replace_query->()/ge;
                for my $val ( @val ) {
                    if ( $deflater{$key} ) {
                        $val = $deflater{$key}->($val);
                        $type_parameter_bind_type = undef;
                    }
                    push @bind_params, $type_parameter_bind_type
                        ? [$i, $val, $type_parameter_bind_type]
                        : [$i, $val];
                    $i++;
                }
            }
            else {
                my $bind_type = $self->type2bind($type);
                my $val = $args->{$key};
                if ( $deflater{$key} ) {
                    $val = $deflater{$key}->($val);
                    $bind_type = undef;
                }
                push @bind_params, $bind_type
                     ? [$i, $val, $bind_type]
                     : [$i, $val];
                $i++;
            }
        }

        my $sth = $self->dbh->prepare_cached($modified_query);
        $sth->bind_param(@{$_}) for @bind_params;
        my $ret = $sth->execute;
        return ($sth,$ret);
    };

    {
        no strict 'refs';
        *{"$class\::$method"} = sub {
            $cb->( $do_query, @_ );
        };
    }
}

sub type2bind {
    my $self = shift;
    my $type = shift;
    return $type->is_a_type_of('Int') ? SQL_INTEGER :
        $type->is_a_type_of('Num') ? SQL_FLOAT : undef;
}

sub txn_scope {
    my $self = shift;
    $self->{__txn} ||= DBIx::TransactionManager->new($self->dbh);
    $self->{__txn}->txn_scope( caller => [caller(0)] );
}

sub prepare {
    my $self = shift;
    $self->dbh->prepare(@_);
}

sub do {
    my $self = shift;
    $self->dbh->do(@_);
}

sub func {
    my $self = shift;
    $self->dbh->func(@_);
}

sub last_insert_id {
    my $self = shift;
    $self->dbh->last_insert_id(@_);
}


1;
__END__

=encoding utf-8

=head1 NAME

DBIx::Sunny::Schema - SQL Class Builder

=head1 SYNOPSIS

  package MyProj::Data::DB;
  
  use parent qw/DBIx::Sunny::Schema/;
  use Mouse::Util::TypeConstraints;
  
  subtype 'Uint'
      => as 'Int'
      => where { $_ >= 0 };
  
  subtype 'Natural'
      => as 'Int'
      => where { $_ > 0 };
  
  enum 'Flag' => qw/1 0/;
  
  no Mouse::Util::TypeConstraints;

  __PACKAGE__->select_one(
      'max_id',
      'SELECT max(id) FROM member'
  );
  
  __PACKAGE__->select_row(
      'member',
      id => { isa => 'Natural' }
      'SELECT * FROM member WHERE id=?',
  );
  
  __PACAKGE__->select_all(
      'recent_article',
      public => { isa => 'Flag', default => 1 },
      offset => { isa => 'Uint', default => 0 },
      limit  => { isa => 'Uint', default => 10 },
      'SELECT * FROM articles WHERE public=? ORDER BY created_on LIMIT ?,?',
  );

  __PACAKGE__->select_all(
      'recent_article',
      id  => { isa => 'ArrayRef[Uint]' },
      'SELECT * FROM articles WHERE id IN(?)',
  );
  # This method rewrites query like 'id IN (?,?..)' with Array's value number
  
  __PACKAGE__->query(
      'add_article',
      member_id => 'Natural',
      flag => { isa => 'Flag', default => '1' },
      subject => 'Str',
      body => 'Str',
      created_on => { isa => .. },
      <<SQL);
  INSERT INTO articles (member_id, public, subject, body, created_on) 
  VALUES ( ?, ?, ?, ?, ?)',
  SQL
  
  __PACKAGE__->select_one(
      'article_count_by_member',
      member_id => 'Natural',
      'SELECT COUNT(*) FROM articles WHERE member_id = ?',
  );
  
  __PACKAGE__->query(
      'update_member_article_count',
      article_count => 'Uint',
      id => 'Natural'
      'UPDATE member SET article_count = ? WHERE id = ?',
  );
    
  ...
  
  package main;
  
  use MyProj::Data::DB;
  use DBIx::Sunny;
  
  my $dbh = DBIx::Sunny->connect(...);
  my $db = MyProj::Data::DB->new(dbh=>$dbh,readonly=>0);
  
  my $max = $db->max_id;
  my $member_hashref = $db->member(id=>100); 
  # my $member = $db->member(id=>'abc');  #validator error
  
  my $article_arrayref = $db->recent_article( offset => 10 );
  
  {
      my $txn = $db->dbh->txn_scope;
      $db->add_article(
          member_id => $id,
          subject => $subject,
          body => $body,
          created_on => 
      );
      my $last_insert_id = $db->dbh->last_insert_id;
      my $count = $db->article_count_by_member( id => $id );
      $db->update_member_article_count(
          article_count => $count,
          id => $id
      );
      $txn->commit;
  }
  
=head1 DESCRIPTION

=head1 BUILDER CLASS METHODS

=over 4

=item __PACKAGE__->select_one( $method_name, @validators, $sql );

build a select_one method named $method_name with validator. validators arguments are passed for Data::Validator. you can use Mouse's type constraint. Type constraint are also used for SQL's bind type determination. 

=item __PACKAGE__->select_row( $method_name, @validators, $sql, [\&filter] );

build a select_row method named $method_name with validator. If a last argument is CodeRef, this coderef will be applied for a result row.

=item __PACKAGE__->select_all( $method_name, @validators, $sql, [\&filter] );

build a select_all method named $method_name with validator. If a last argument is CodeRef, this coderef will be applied for all result row.

=item __PACKAGE__->query( $method_name, @validators, $sql );

build a query method named $method_name with validator.  

=back

=head1 FILTERING and DEFLATING

=over 4

=item FILTERING

If you passed CodeRef to builder, this CodeRef will be applied for results.

  __PACAKGE__->select_all(
      'recent_article',
      limit  => { isa => 'Uint', default => 10 },
      'SELECT * FROM articles WHERE ORDER BY created_on LIMIT ?',
      sub {
          my ($row,$self)= @_;
          $row->{created_on} = DateTime::Format::MySQL->parse_datetime($row->{created_on});
          $row->{created_on}->set_time_zone("Asia/Tokyo");
      }
  );

Second argument of filter CodeRef is instance object of your SQL class.

=item DEFLATING

If you want to deflate argument before execute SQL, you can it with adding deflater argument to validator rule.

  __PACKAGE__->query(
      'add_article',
      subject => 'Str',
      body => 'Str',
      created_on => { isa => 'DateTime', deflater => sub { shift->strftime('%Y-%m-%d %H:%M:%S')  },
      <<SQL);
  INSERT INTO articles (subject, body, created_on) 
  VALUES ( ?, ?, ?)',
  SQL

=back

=head1 METHODS

=over 4

=item new({ dbh => DBI, readonly => ENUM(0,1) ) :DBIx::Sunny::Schema

create instance of schema. if readonly is true, query method's will raise exception.

=item dbh :DBI

readonly accessor for DBI database handler. 

=item select_one($query, @bind) :Str

Shortcut for prepare, execute and fetchrow_arrayref->[0]

=item select_row($query, @bind) :HashRef

Shortcut for prepare, execute and fetchrow_hashref

=item select_all($query, @bind) :ArrayRef[HashRef]

Shortcut for prepare, execute and selectall_arrayref(.., { Slice => {} }, ..)

=item query($query, @bind) :Str

Shortcut for prepare, execute. 

=item txn_scope() :DBIx::TransactionManager::Guard

return DBIx::TransactionManager::Guard object

=item do(@args) :Str

Shortcut for $self->dbh->do()

=item prepare(@args) :DBI::st

Shortcut for $self->dbh->prepare()

=item func(@args) :Str

Shortcut for $self->dbh->func()

=item last_insert_id(@args) :Str

Shortcut for $self->dbh->last_insert_id()

=item args(@rule) :HashRef

Shortcut for using Data::Validator. Optional deflater arguments can be used.
Data::Validator instance will cache at first time.

  sub retrieve_user {
      my $self = shift;
      my $args = $self->args(
          id => 'Int',
          created_on => {
              isa => 'DateTime',
              deflater => sub { shift->strftime('%Y-%m-%d %H:%M:%S')
          },
      );
      $arg->{id} ...
  }

$args is validated arguments. @_ is not needed.

=back

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo KZBRKZBR@ gmail.comE<gt>

=head1 SEE ALSO

C<DBI>, C<DBIx::TransactionManager>, C<Data::Validator>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
