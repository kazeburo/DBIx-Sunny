use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires { 'DBD::SQLite' => 1.31, 'DBIx::Class' => 0.082840, 'DBIx::Tracer' => 0.03 };
use File::Temp qw/tempdir/;
use DBIx::Sunny;
use Data::Dumper;
use lib 't/lib/';
use MyApp::Schema;

my $dir = tempdir( CLEANUP => 1 );
my $fname = "$dir/db.sqlite";

my $schema = MyApp::Schema->connect("dbi:SQLite:dbname=$fname", '', '', {
    RootClass => 'DBIx::Sunny',
    on_connect_do => q{
        CREATE TABLE foo (
            id INTEGER NOT NULL PRIMARY KEY,
            e VARCHAR(10)
        )
    },
});
my @queries;
my $tracer = DBIx::Tracer->new(
    sub {
        my %args = @_;
        push @queries, $args{sql};
    }
);
my @rows = $schema->resultset('Foo')->all;
is 0+@rows, 0;
cmp_ok(0+(grep m{/\* t.06_dbic.t line 31 \*/}, @queries), '>', 0);
note Dumper(\@queries);

done_testing;

