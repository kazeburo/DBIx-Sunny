
use DBIx::Sunny;

my $db = DBIx::Sunny->new(
    master=>[qw!dbi:mysql:test!]
);

print $db->select_one("select version()");

$db->query("insert into fuga (data) values (?)","\x{58f9}");
print $db->last_insert_id;
print $db->select_one("select data from fuga order by id desc limit 1");
print "OK";

$db->queryf("insert into fuga (data) values (%s)","\x{5f10}");
print $db->selectf_one("select data from fuga order by id desc limit %d",1);
print "OK";



