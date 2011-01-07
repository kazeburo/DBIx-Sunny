use strict;
use warnings;

package MyProj::Data;

use parent 'DBIx::Sunny';
use Mouse::Util::TypeConstraints;
  
subtype 'Natural'
    => as 'Int'
    => where { $_ > 0 };

subtype 'Uint'
    => as 'Int'
    => where { $_ >= 0 };

no Mouse::Util::TypeConstraints;

__PACKAGE__->select_one(
    'version',
    'SELECT VERSION()'
);

__PACKAGE__->query(
    'init_table',
    <<SQL);
CREATE TABLE IF NOT EXISTS fuga (
  id INT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY,
  data VARCHAR(12)
)
SQL

__PACKAGE__->query(
    'add_data',
    data => 'Str',
    'INSERT INTO fuga (data) VALUES (?)',
);

__PACKAGE__->select_row(
    'get_data',
    id => 'Natural',
    'SELECT * FROM fuga WHERE id = ?'
);

__PACKAGE__->select_all(
    'get_recent_data',
    offset => { isa => 'Uint', default => 0 },
    limit => { isa => 'Uint', default => 10 },
    'SELECT * FROM fuga ORDER BY id DESC LIMIT ?,?'
);


package main;

use Log::Minimal;

local $Log::Minimal::AUTODUMP = 1;
local $Log::Minimal::PRINT = sub {
    my ( $time, $type, $message, $trace) = @_;
    print "$time [$type] $message at $trace\n";
};

my $db = MyProj::Data->new(
    dbh => DBI->connect('dbi:mysql(RaiseError=>1,PrintError=>0):test')
);

print "OK" if $db->init_table;
print $db->version;

my $ret;

$ret = $db->add_data( data => 'fugafuga' );
print "OK" if $ret > 0;
my $last_insert_id = $db->last_insert_id;
print $last_insert_id;

my $row;
$row = $db->get_data( id => $last_insert_id );
infof($row);

eval {
    $row = $db->get_data( id => 'abc' );
};
print $@;

eval {
    $row = $db->get_data( id => 0 );
};
print $@;

$row = $db->get_recent_data( limit => 20 );
infof($row);

$row = $db->get_recent_data( offset => 10 );
infof($row);


#$db->query("insert into fuga (data) values (?)","\x{58f9}");
#print $db->last_insert_id;
#print $db->select_one("select data from fuga order by id desc limit 1");
#print "OK";
#
#$db->queryf("insert into fuga (data) values (%s)","\x{5f10}");
#print $db->selectf_one("select data from fuga order by id desc limit %d",1);
#print "OK";
#


