# vsqlite vs sqlite3

## What vsqlite does that sqlite3 also does

### Interactive shell
- REPL with readline: history (↑/↓), Ctrl+R reverse search, full cursor movement
- Multi-line statement editing; continuation prompt `...>` until `;`
- Tab completion for SQL keywords, table names, column names, and dot commands; list refreshes after DDL
- Command history persisted to `~/.vsqlite_history`
- Single-statement execution from CLI (`vsqlite db.sqlite "SELECT ..."`)
- Execute SQL from file (`vsqlite db.sqlite -f schema.sql`)
- Pipe queries non-interactively (`echo "SELECT 1" | vsqlite db.sqlite`)

### Output modes
| Mode | Description |
|---|---|
| `table` | Aligned ASCII table with bold headers (default) |
| `box` | Unicode box-drawing table |
| `markdown` | GitHub-Flavored Markdown table |
| `csv` | RFC 4180 CSV |
| `line` | One field per line |
| `json` | JSON array of objects; NULLs become `null` |
| `html` | HTML `<table>` with escaped values |
| `insert` | SQL `INSERT` statements |
| `quote` | SQL-quoted values, one row per line |

### Display control
- `.headers on|off` — toggle column headers
- `.nullvalue <str>` — customize NULL display string
- `.separator <sep>` — custom column delimiter (`\t` for tab)
- `.width [N1 N2 …]` — per-column fixed widths; `.width 0` resets to auto
- `.output [file|-]` — redirect all query output to a file
- `.once <file>` — redirect the next query result only, then revert to stdout

### Dot commands
- `.tables` — list all tables
- `.schema [table]` — show CREATE statements (table, index, view, trigger)
- `.indexes [table]` — list indexes
- `.databases` — list attached databases
- `.import <file> <table>` — CSV/TSV import; RFC 4180 quoting, embedded newlines, CRLF; auto-detects `.tsv`/`.tab`
- `.dump [file]` — full SQL dump (schema + data) wrapped in `BEGIN`/`COMMIT`
- `.load <file> [entry]` — load a SQLite extension (`.so`/`.dylib`)
- `.bail on|off` — stop on first SQL error
- `.echo on|off` — print each statement before executing
- `.log [file|off]` — append every executed statement to a log file
- `.changes on|off` — print `Changes: N` after each INSERT/UPDATE/DELETE
- `.open <file>` — open or switch to a different database file
- `.timer on|off` — print execution time after each statement
- `.explain <stmt>` — run `EXPLAIN QUERY PLAN` and render as an indented tree
- `.mode <mode> [tbl]` — change output format
- `.read <file>` — execute a SQL file from within the interactive REPL
- `.show` — print a snapshot of all current settings (mode, headers, nullvalue, separator, etc.)
- `.print [string…]` — print literal text; useful inside `.read` scripts
- `.prompt MAIN [CONTINUE]` — customize the `vsqlite>` and `...>` prompt strings
- `.eqp on|off` — automatically run `EXPLAIN QUERY PLAN` before every SELECT
- `.trace [file|stderr|off]` — trace every SQL statement to a file or stderr as it executes
- `.timeout <ms>` — set busy-wait timeout for locked databases
- `.shell` / `.system <cmd args…>` — run an OS command from the REPL
- `.backup <file>` — backup database via `VACUUM INTO`
- `.fullschema` — full schema including `sqlite_stat*` tables
- `.dbinfo` — page count, encoding, `application_id`, `user_version`, file size
- `.stats` — page statistics and per-table row counts
- `.lint` — report potential schema issues (missing indexes on FK columns)
- `.cd [directory]` — change or show the working directory
- `.help` / `.quit` / `.exit` / Ctrl+D

---

## What vsqlite does that sqlite3 does NOT

- `.export <file>` — export the last query result to CSV in one command
- `.size` — show database file size in human-readable form (B / KB / MB / GB)

---

## What sqlite3 has that vsqlite lacks

### Backup & restore
- `.backup ?DB? FILE` / `.save FILE` — online hot backup via `sqlite3_backup` API (vsqlite uses `VACUUM INTO` which requires no active readers/writers)
- `.restore ?DB? FILE` — restore a database from a backup file
- `.clone NEWDB` — copy schema and data into a new database

### Advanced / rarely used
- `.crlf on|off` — control `\r\n` vs `\n` line endings in output
- `.dbconfig ?op? ?val?` — low-level `sqlite3_db_config()` options
- `.expert` — suggest indexes for a query (experimental)
- `.intck` — incremental integrity check
- `.limit ?LIMIT? ?VAL?` — display/change `SQLITE_LIMIT_*` values
- `.parameter CMD` — manage named SQL parameters (`:name`, `$name`, `@name`)
- `.recover` — recover as much data as possible from a corrupt database
- `.scanstats on|off` — `sqlite3_stmt_scanstatus()` metrics
- `.session NAME CMD` — create and manage SQLite session/changeset objects
- `.sha3sum` — compute a SHA3 hash of database content
- `.vfsinfo` / `.vfslist` / `.vfsname` — VFS stack introspection
- `.archive`, `.auth`, `.check`, `.connection`, `.dbtotxt`, `.excel`, `.filectrl`, `.nonce`, `.progress`, `.www` — niche/platform-specific commands

---

## Summary

vsqlite covers the vast majority of everyday sqlite3 usage:

| Area | Status |
|---|---|
| Interactive shell (readline, multi-line, tab completion, history) | ✅ Full parity |
| Output modes (table, box, markdown, csv, line, json, html, insert, quote) | ✅ Full parity |
| Display control (headers, nullvalue, separator, width, output, once) | ✅ Full parity |
| Session control (bail, echo, log, changes, open, timer) | ✅ Full parity |
| Import / export (dump, load, CSV/TSV with edge cases) | ✅ Full parity |
| Schema introspection (tables, schema, indexes, databases) | ✅ Full parity |
| Interactive file execution (`.read`) | ✅ Implemented |
| Settings snapshot (`.show`) | ✅ Implemented |
| Scripting helpers (`.print`, `.prompt`, `.eqp`, `.trace`, `.timeout`, `.shell`) | ✅ Implemented |
| Schema diagnostics (`.fullschema`, `.dbinfo`, `.lint`, `.stats`) | ✅ Implemented |
| Working directory (`.cd`) | ✅ Implemented |
| Backup via VACUUM INTO (`.backup`) | ✅ Implemented |
| Backup / restore via backup API (`.restore`, `.clone`) | ❌ Not implemented |
| Advanced internals (`.expert`, `.recover`, `.session`, `.parameter`, VFS, etc.) | ❌ Not implemented |

The sqlite3 binary is ~1.5 MB of battle-hardened C. vsqlite is ~1600 lines of V.
