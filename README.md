# vsqlite

A SQLite CLI and library written in [V](https://vlang.io).

## Installation

```sh
git clone https://github.com/quaesitor-scientiam/vsqlite
cd vsqlite
make build
```

Requires V and SQLite development headers (`libsqlite3-dev` on Linux, included on macOS).

---

## CLI

### Open an interactive REPL

```sh
./vsqlite mydb.sqlite
```

Use `:memory:` for a temporary in-memory database:

```sh
./vsqlite :memory:
```

### Run a single statement

```sh
./vsqlite mydb.sqlite "SELECT * FROM users"
./vsqlite mydb.sqlite "INSERT INTO users VALUES (1, 'Alice', 30)"
./vsqlite mydb.sqlite "CREATE TABLE logs (id INTEGER, msg TEXT)"
```

### Execute a SQL file

```sh
./vsqlite mydb.sqlite -f schema.sql
./vsqlite mydb.sqlite -f seed.sql
```

### Pipe queries non-interactively

```sh
echo "SELECT count(*) FROM users" | ./vsqlite mydb.sqlite
printf ".mode csv\nSELECT * FROM users\n" | ./vsqlite mydb.sqlite > out.csv
```

---

## Interactive commands

| Command | Description |
|---|---|
| `.tables` | List all tables |
| `.schema [table]` | Show CREATE statement for a table (or all objects) |
| `.mode table\|csv\|line` | Change output format (default: `table`) |
| `.headers on\|off` | Toggle column headers |
| `.import <file> <table>` | Import a CSV file into a table |
| `.export <file>` | Export the last query result to CSV |
| `.indexes [table]` | List indexes |
| `.databases` | List attached databases |
| `.size` | Show database file size |
| `.help` | Show all commands |
| `.quit` / `.exit` / Ctrl+D | Exit |

### Multi-line statements

The REPL accumulates input until a semicolon (`;`) is entered, just like `sqlite3`:

```
vsqlite> SELECT id, name
     ...> FROM users
     ...> WHERE age > 25;
```

Dot commands (`.tables`, `.mode`, …) execute immediately and do not need a semicolon.

### Line editing

The interactive REPL uses V's built-in `readline` module for a full line-editing experience:

| Key | Action |
|---|---|
| ↑ / ↓ | Walk command history |
| Ctrl+R | Reverse incremental history search |
| ← / → | Move cursor within the line |
| Home / Ctrl+A | Jump to beginning of line |
| End / Ctrl+E | Jump to end of line |
| Ctrl+K | Delete to end of line |
| Backspace / Delete | Delete character |

History is persisted to `~/.vsqlite_history` across sessions.

### Tab completion

Press **Tab** to complete the current token against SQL keywords, table names, column names, and dot commands:

```
vsqlite> SELECT * FROM us<TAB>  →  SELECT * FROM users
vsqlite> .tab<TAB>              →  .tables
vsqlite> SEL<TAB>               →  SELECT
```

Press Tab again to cycle through additional matches. The completion list is refreshed automatically after `CREATE`, `DROP`, and `ALTER` statements.

### Output modes

**table** (default) — aligned ASCII table with bold headers
```
+----+-------+-----+
| id | name  | age |
+----+-------+-----+
| 1  | Alice | 30  |
+----+-------+-----+
```

**csv** — RFC 4180 CSV
```
id,name,age
1,Alice,30
```

**line** — one field per line, useful for wide rows
```
 id: 1
name: Alice
 age: 30
```

---

## Library

Import `vsqlite` in your V project to get column-aware query execution and result formatting.

### Connect

```v
import vsqlite

mut db := vsqlite.connect('mydb.sqlite')!
mut mem := vsqlite.connect(':memory:')!
```

### Query

```v
rows := db.exec('SELECT * FROM users')!

// rows is []vsqlite.Row — each row carries column names + values
for row in rows {
    println(row.get('name'))   // access by column name
    println(row.vals[0])       // access by index
}
```

### Single row

```v
row := db.exec_one('SELECT * FROM users WHERE id = 1')!
println(row.get('email'))
```

### Row as map

```v
row := db.exec_one('SELECT * FROM users LIMIT 1')!
m := row.as_map()   // map[string]string
println(m['name'])
```

### Mutations

```v
db.exec_none('INSERT INTO users VALUES (2, "Bob", 25)')
println(db.last_insert_rowid())  // 2
println(db.affected_rows())
```

### Metadata

```v
tables := db.tables()         // []string
schema := db.schema('users')  // CREATE TABLE ...
size   := db.size()           // i64 bytes
```

### Formatting

```v
rows := db.exec('SELECT * FROM users')!

println(vsqlite.format(rows, .table, true))  // ASCII table with headers
println(vsqlite.format(rows, .csv,   true))  // CSV with headers
println(vsqlite.format(rows, .line,  true))  // line format
```

### CSV utilities

```v
// Read a CSV file
headers, rows := vsqlite.read_csv('data.csv')!

// Write query results to CSV
vsqlite.write_csv('out.csv', rows, true)!

// Parse a single CSV line
fields := vsqlite.parse_csv_line('a,"b,c",d')  // ['a', 'b,c', 'd']
```

---

## Running tests

```sh
make test
```

---

## Comparison with sqlite3

See [COMPARISON.md](COMPARISON.md) for a detailed feature comparison with the official `sqlite3` CLI.
