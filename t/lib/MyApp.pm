package MyApp;
use strict;
use warnings;
use utf8;

sub foo_all {
    my ($class, $schema) = @_;
    $schema->resultset('Foo')->all;
}

1;
