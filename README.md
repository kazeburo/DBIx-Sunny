[![Build Status](https://travis-ci.org/kazeburo/DBIx-Sunny.svg?branch=master)](https://travis-ci.org/kazeburo/DBIx-Sunny) [![MetaCPAN Release](https://badge.fury.io/pl/DBIx-Sunny.svg)](https://metacpan.org/release/DBIx-Sunny)
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

- \[SQLite/MySQL/Pg\] Auto encode/decode UTF-8

    DBIx::Sunny sets sqlite\_unicode, mysql\_enable\_utf8 and pg\_enable\_utf8 automatically.

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
        #SQL: 'SELECT * FROM id IN (?,?,?)'
        #@BIND: (1, 2, 3)

- Named placeholder

    select\_(one|row|all) and query methods support named placeholder.

        $dbh->select_all('SELECT * FROM users WHERE id IN (:ids) AND status = :status', {
            ids    => [1,2,3],
            status => 'active',
        });
        #SQL: 'SELECT * FROM users WHERE id IN (?,?,?) AND status = ?'
        #@BIND: (1, 2, 3, 'active')

- Typed bind parameters

    DBIx::Sunny allows you to specify data types of bind parameters. If a bind parameter is [SQL::Maker::SQLType](https://metacpan.org/pod/SQL::Maker::SQLType) object, its value is passed as its type, otherwise it is passed as default type (VARCHAR).

        use SQL::Maker::SQLType qw/sql_type/;
        use DBI qw/:sql_types/

        $dbh->query(
            'INSERT INTO bin_table (bin_col) VALUES (?)',
            sql_type(\"\xDE\xAD\xBE\xEF", SQL_BINARY)),
        );

# ADDITIONAL METHODS

- `$col = $dbh->select_one($query, @bind);`

    Shortcut for prepare, execute and fetchrow\_arrayref->\[0\]

- `$row = $dbh->select_row($query, @bind);`

    Shortcut for prepare, execute and fetchrow\_hashref

- `$rows = $dbh->select_all($query, @bind);`

    Shortcut for prepare, execute and `selectall_arrayref(.., { Slice => {} }, ..)`

- `$dbh->query($query, @bind);`

    Shortcut for prepare, execute. 

# AUTHOR

Masahiro Nagano &lt;kazeburo KZBRKZBR@ gmail.com>

# SEE ALSO

[DBI](https://metacpan.org/pod/DBI), [Amon2::DBI](https://metacpan.org/pod/Amon2::DBI)

# LICENSE

Copyright (C) Masahiro Nagano

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
