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
| `.mode <mode> [tbl]` | Change output format (default: `table`) — see modes below |
| `.headers on\|off` | Toggle column headers |
| `.nullvalue <str>` | Set display string for NULL values (default: `NULL`) |
| `.separator <sep>` | Set column separator for csv/quote modes (default: `,`; use `\t` for tab) |
| `.width [N1 N2 …]` | Fix per-column widths in table/box/markdown modes; `.width 0` resets to auto |
| `.output [file\|-]` | Redirect all query output to *file*; no arg or `-` resets to stdout |
| `.once <file>` | Redirect the **next** query result only to *file*, then resume stdout |
| `.timer [on\|off]` | Toggle execution timing; prints elapsed time after each statement |
| `.explain <stmt>` | Show `EXPLAIN QUERY PLAN` as an indented tree for *stmt* |
| `.import <file> <table>` | Import a CSV or TSV file into a table (`.tsv`/`.tab` auto-detected) |
| `.export <file>` | Export the last query result to CSV |
| `.dump [file]` | Dump full SQL schema + data to stdout, or to *file* |
| `.load <file> [entry]` | Load a SQLite extension (`.so`/`.dylib`) |
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

**box** — same as `table` but with Unicode box-drawing characters
```
┌────┬───────┬─────┐
│ id │ name  │ age │
├────┼───────┼─────┤
│ 1  │ Alice │ 30  │
└────┴───────┴─────┘
```

**markdown** — GitHub-Flavored Markdown table
```
| id | name  | age |
| -- | ----- | --- |
| 1  | Alice | 30  |
```

**csv** — RFC 4180 CSV (separator controlled by `.separator`)
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

**json** — JSON array of objects; SQL NULLs become JSON `null`
```json
[{"id":"1","name":"Alice","age":"30"}]
```

**html** — HTML `<table>` with optional `<th>` headers; values are HTML-escaped
```html
<table>
<tr><th>id</th><th>name</th><th>age</th></tr>
<tr><td>1</td><td>Alice</td><td>30</td></tr>
</table>
```

**insert** — SQL `INSERT` statements (table name set via `.mode insert <tbl>`)
```sql
INSERT INTO users(id,name,age) VALUES('1','Alice','30');
```

**quote** — SQL-quoted values, one row per line (separator controlled by `.separator`)
```
'1','Alice','30'
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

### Parameterized queries

Use `?` as a placeholder; pass values as a `[]string`:

```v
rows := db.exec_params('SELECT * FROM users WHERE id = ?', ['1'])!
rows2 := db.exec_params('SELECT * FROM users WHERE age >= ? AND age <= ?', ['25', '35'])!
```

For mutations with parameters:

```v
db.exec_none_params('INSERT INTO users VALUES (?, ?, ?)', ['4', 'Dave', '28'])
db.exec_none_params('UPDATE users SET age = ? WHERE id = ?', ['99', '1'])
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

### Database dump

```v
// Full SQL script (schema + data) as a string
script := db.dump()
os.write_file('backup.sql', script)!
```

The dump is wrapped in `BEGIN TRANSACTION` / `COMMIT` and can be piped straight back into vsqlite or `sqlite3` to recreate the database.

### Loading extensions

```v
db.load_extension('/usr/lib/sqlite3/pcre.so', '')!   // default entry point
db.load_extension('mod.so', 'sqlite3_mod_init')!     // explicit entry point
```

Requires the linked `libsqlite3` to be compiled with `SQLITE_ENABLE_LOAD_EXTENSION`.

### CSV utilities

```v
// Read a CSV file (comma-separated)
headers, rows := vsqlite.read_csv('data.csv')!

// Read a TSV file (tab-separated)
headers, rows := vsqlite.read_tsv('data.tsv')!

// Read with a custom separator
headers, rows := vsqlite.read_csv_sep('data.psv', `|`)!

// Parse a full CSV content string into records
records := vsqlite.parse_csv_records(content, `,`)  // handles embedded newlines, CRLF

// Parse a single line with a custom separator
fields := vsqlite.parse_csv_line_sep('a|b|c', `|`)  // ['a', 'b', 'c']

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
