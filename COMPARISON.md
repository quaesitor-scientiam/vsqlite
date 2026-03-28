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
- `.bail on` — stop on first error
- `.echo on` — echo statements before running
- `.log <file>` — log all statements
- `.changes` — show changed rows after each statement
- `ATTACH` database support (`.open`)

---

## Summary

vsqlite is roughly a ~85% feature implementation of sqlite3. Shell quality (readline, multi-line input, tab completion), output richness (all major modes, `.width`, `.nullvalue`, `.separator`, `.output`/`.once`), SQL execution extras (prepared statements, `.timer`, `.explain`, multi-statement input), and import/export (`.dump`, `.load`, robust CSV/TSV with embedded newlines and CRLF) are now largely on par. The remaining gap is **session control** (`.bail on`, `.echo on`, `.log`, `.changes`, `ATTACH`/`.open`). For scripting (`vsqlite db.sqlite "..."` or `-f`), the gap is small.

The sqlite3 binary is ~1.5MB of battle-hardened C. vsqlite is ~1200 lines of V.
