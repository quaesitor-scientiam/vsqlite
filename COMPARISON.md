# vsqlite vs sqlite3

## What vsqlite does that sqlite3 also does
- Interactive REPL with dot commands
- Single-statement execution from CLI
- Execute SQL from file (`-f` vs `.read`)
- Table, CSV, line, box, markdown, JSON, HTML, insert, and quote output modes
- `.tables`, `.schema`, `.mode`, `.headers`, `.import`, `.export`
- `.nullvalue`, `.separator`, `.width` — display customisation
- `.output <file>` / `.once <file>` — redirect query output to a file
- `.indexes`, `.databases`, `.size`
- `.timer on/off` — query execution timing
- `.explain <stmt>` — EXPLAIN QUERY PLAN rendered as an indented tree
- Prepared statements / parameter binding via `exec_params` / `exec_none_params`
- Proper multi-statement input — `;`-separated statements, both in the REPL and in `-f` files, respecting quoted semicolons
- Reports affected rows / last insert rowid
- Multi-line statement editing; continuation prompt `...>` until `;`
- Tab completion for SQL keywords, table names, column names, and dot commands
- Command history persisted to `~/.vsqlite_history`
- `.bail on` — exit on first SQL error (interactive and batch)
- `.echo on` — print each statement before executing
- `.log <file>` — append all executed statements to a file
- `.changes on` — show row-change count after each DML statement
- `.open <file>` — switch to a different database file mid-session

---

## What sqlite3 has that vsqlite lacks

### Shell quality
- ~~Readline/libedit: history (↑↓), Ctrl+R search, cursor movement~~ — **implemented** via V's `readline` module; history persisted to `~/.vsqlite_history`
- ~~Multi-line statement editing (sqlite3 waits for `;` before executing)~~ — **implemented**; continuation prompt `...>` shown until `;` is entered
- ~~Tab completion for table/column names~~ — **implemented**; Tab completes SQL keywords, table names, column names, and dot commands; list refreshes after DDL

### Output
- ~~`.width` — set per-column widths~~ — **implemented**
- ~~`.nullvalue` — customize NULL display string~~ — **implemented**
- ~~`.separator` — custom delimiters~~ — **implemented**
- ~~`box`, `markdown`, `json`, `html`, `insert`, `quote` output modes~~ — **implemented**
- ~~`.once <file>` / `.output <file>` — redirect output to file mid-session~~ — **implemented**

### SQL execution
- ~~Prepared statements / parameter binding~~ — **implemented** via `exec_params` / `exec_none_params` (uses `?` placeholders)
- ~~`.timer on` — query execution timing~~ — **implemented**; `.timer on/off` prints execution time after each statement
- ~~`.explain` — formatted EXPLAIN output~~ — **implemented**; `.explain <stmt>` runs `EXPLAIN QUERY PLAN` and renders a tree
- ~~Proper multi-statement input (`;` separated, across lines)~~ — **implemented**; `split_statements` splits on `;` respecting quoted strings; both interactive REPL and `-f` file mode execute each statement individually

### Import/Export
- ~~`.dump` — full SQL dump of the database~~ — **implemented**; `.dump [file]` generates a `BEGIN/COMMIT`-wrapped SQL script (DDL + INSERTs) to stdout or a file
- ~~`.load <ext>` — load extensions (.so/.dylib)~~ — **implemented**; `.load <file> [entry-point]` calls SQLite's `load_extension()` SQL function (requires `SQLITE_ENABLE_LOAD_EXTENSION` in the linked libsqlite3)
- ~~Proper CSV/TSV import with quoting edge cases~~ — **implemented**; `parse_csv_records` is now content-based (handles embedded newlines in quoted fields, CRLF, bare CR); `read_tsv` / `read_csv_sep` added; `.import` auto-detects `.tsv`/`.tab` files

### Meta
- ~~`.bail on` — stop on first error~~ — **implemented**; `.bail on/off` calls `exit(1)` on SQL query errors
- ~~`.echo on` — echo statements before running~~ — **implemented**; `.echo on/off` prints each statement before executing
- ~~`.log <file>` — log all statements~~ — **implemented**; `.log <file>` appends every executed statement; `.log off` disables
- ~~`.changes` — show changed rows after each statement~~ — **implemented**; `.changes on/off` prints `Changes: N` after each DML
- ~~`ATTACH` database support (`.open`)~~ — **implemented**; `.open <file>` opens a new database and replaces the current connection

---

## Summary

vsqlite is roughly a ~95% feature implementation of sqlite3. Shell quality (readline, multi-line input, tab completion), output richness (all major modes, `.width`, `.nullvalue`, `.separator`, `.output`/`.once`), SQL execution extras (prepared statements, `.timer`, `.explain`, multi-statement input), import/export (`.dump`, `.load`, robust CSV/TSV), and session control (`.bail`, `.echo`, `.log`, `.changes`, `.open`) are all implemented. For scripting (`vsqlite db.sqlite "..."` or `-f`), the gap with `sqlite3` is very small.

The sqlite3 binary is ~1.5MB of battle-hardened C. vsqlite is ~1400 lines of V.
