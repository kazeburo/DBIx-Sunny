# NAME

DBIx::Sunny - Simple DBI wrapper

# SYNOPSIS

    use DBIx::Sunny;

    my $dbh = DBIx::Sunny->connect(...);

    # or 

    use DBI;

    my $dbh = DBI->connect(.., {
        RootClass => 'DBIx::Sunny',
        PrintError => 0,
        RaiseError => 1,
    });

# DESCRIPTION

DBIx::Sunny is a simple DBI wrapper. It provides better usability for you. This module based on Amon2::DBI.
DBIx::Sunny supports only SQLite and MySQL.

# FEATURES

- Set AutoInactiveDestroy to true.

    DBIx::Sunny sets AutoInactiveDestroy as true.

- \[SQLite/MySQL\] Auto encode/decode utf-8

    DBIx::Sunny sets sqlite\_unicode and mysql\_enable\_utf8 automatically.

- \[SQLite\] Performance tuning

    DBIx::Sunny sets sqlite\_use\_immediate\_transaction to true, and executes these PRAGMA statements

        PRAGMA journal_mode = WAL
        PRAGMA synchronous = NORMAL

- Nested transaction management.

    DBIx::Sunny supports nested transaction management based on RAII like DBIx::Class or DBIx::Skinny. It uses [DBIx::TransactionManager](https://metacpan.org/pod/DBIx::TransactionManager) internally.

- Error Handling

    DBIx::Sunny sets RaiseError and ShowErrorStatement as true. DBIx::Sunny raises exception and shows current statement if your $dbh occurred exception.

- SQL comment

    DBIx::Sunny adds file name and line number as SQL comment that invokes SQL statement.

- Easy access to last\_insert\_id

    DBIx::Sunny's last\_insert\_id needs no arguments. It's shortcut for mysql\_insertid or last\_insert\_rowid.

- Auto expanding arrayref bind parameters

    select\_(one|row|all) and  query methods support auto-expanding arrayref bind parameters.

        $dbh->select_all('SELECT * FROM id IN (?)', [1 2 3])
        #SQL: 'SELECT * FROM id IN (?,?,")'
        #@BIND: (1, 2, 3)

# ADDITIONAL METHODS

- $col = $dbh->select\_one($query, @bind);

    Shortcut for prepare, execute and fetchrow\_arrayref->\[0\]

- $row = $dbh->select\_row($query, @bind);

    Shortcut for prepare, execute and fetchrow\_hashref

- $rows = $dbh->select\_all($query, @bind);

    Shortcut for prepare, execute and selectall\_arrayref(.., { Slice => {} }, ..)

- $dbh->query($query, @bind);

    Shortcut for prepare, execute. 

# AUTHOR

Masahiro Nagano <kazeburo KZBRKZBR@ gmail.com>

# SEE ALSO

[DBI](https://metacpan.org/pod/DBI), [Amon2::DBI](https://metacpan.org/pod/Amon2::DBI)

# LICENSE

Copyright (C) Masahiro Nagano

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
