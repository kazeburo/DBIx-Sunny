package MyApp::Schema::Result::Foo;
use strict;
use warnings;
use utf8;

use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('foo');
__PACKAGE__->add_columns(qw/ id e /);
__PACKAGE__->set_primary_key('id');

1;

