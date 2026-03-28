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
| `.bail on\|off` | Stop on first SQL error; `off` (default) continues |
| `.echo on\|off` | Echo each statement to stdout before executing |
| `.log <file>\|off` | Append every executed statement to *file*; `off` disables |
| `.changes on\|off` | Print `Changes: N` after each INSERT/UPDATE/DELETE |
| `.open <file>` | Open a new database file (replaces the current connection) |
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

## Running tests

```sh
make test
```

---

## Comparison with sqlite3

See [COMPARISON.md](COMPARISON.md) for a detailed feature comparison with the official `sqlite3` CLI.
