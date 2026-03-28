# vsqlite vs sqlite3

## What vsqlite does that sqlite3 also does
- Interactive REPL with dot commands
- Single-statement execution from CLI
- Execute SQL from file (`-f` vs `.read`)
- Table, CSV, and line output modes
- `.tables`, `.schema`, `.mode`, `.headers`, `.import`, `.export`
- Reports affected rows / last insert rowid

---

## What sqlite3 has that vsqlite lacks

### Shell quality
- ~~Readline/libedit: history (↑↓), Ctrl+R search, cursor movement~~ — **implemented** via V's `readline` module; history persisted to `~/.vsqlite_history`
- ~~Multi-line statement editing (sqlite3 waits for `;` before executing)~~ — **implemented**; continuation prompt `...>` shown until `;` is entered
- Tab completion for table/column names

### Output
- `.width` — set per-column widths
- `.nullvalue` — customize NULL display string
- `.separator` — custom delimiters
- `box`, `markdown`, `json`, `html`, `insert`, `quote` output modes
- `.once <file>` / `.output <file>` — redirect output to file mid-session

### SQL execution
- Prepared statements / parameter binding
- `.timer on` — query execution timing
- `.explain` — formatted EXPLAIN output
- Proper multi-statement input (`;` separated, across lines)

### Import/Export
- `.dump` — full SQL dump of the database
- `.load <ext>` — load extensions (.so/.dylib)
- Proper CSV/TSV import with quoting edge cases

### Meta
- `.bail on` — stop on first error
- `.echo on` — echo statements before running
- `.log <file>` — log all statements
- `.changes` — show changed rows after each statement
- `ATTACH` database support (`.open`)

---

## Summary

vsqlite is roughly a ~30% feature implementation of sqlite3. The biggest remaining practical gap is **tab completion** (table/column name hints). Multi-line input and readline support (history, cursor movement, Ctrl+R search) are now on par with sqlite3. For scripting (`vsqlite db.sqlite "..."` or `-f`), the gap is smaller.

The sqlite3 binary is ~1.5MB of battle-hardened C. vsqlite is ~500 lines of V.
