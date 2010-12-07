
use DBIx::Sunny;

my $db = DBIx::Sunny->new(
    master=>[qw!dbi:SQLite:dbname=/tmp/test.db!]
);
$db->query("insert into fuga (data) values (?)","\x{58f9}");
print $db->last_insert_id;
print $db->select_one("select data from fuga order by id desc limit 1");
print "OK";




