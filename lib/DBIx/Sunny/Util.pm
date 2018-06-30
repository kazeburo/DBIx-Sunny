package DBIx::Sunny::Util;

use strict;
use warnings;

use Exporter 'import';
use Scalar::Util qw/blessed/;
use SQL::NamedPlaceholder 0.10;

our @EXPORT_OK = qw/bind_and_execute/;

sub bind_and_execute {
    my ($sth, @bind) = @_;
    my $i = 0;
    for my $bind ( @bind ) {
        if ( blessed($bind) && $bind->can('value_ref') && $bind->can('type') ) {
            # If $bind is an SQL::Maker::SQLType or compatible object, use its type info.
            $sth->bind_param(++$i, ${ $bind->value_ref }, $bind->type);
        } else {
            $sth->bind_param(++$i, $bind);
        }
    }
    return $sth->execute;
}

1;
