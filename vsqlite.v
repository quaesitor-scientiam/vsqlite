module vsqlite

import db.sqlite

// Row holds a query result row with column names and values paired together.
pub struct Row {
pub:
	cols []string
	vals []string
}

// get returns the value for a column by name, or empty string if not found.
pub fn (r Row) get(col string) string {
	for i, c in r.cols {
		if c == col {
			return r.vals[i]
		}
	}
	return ''
}

// as_map returns the row as a map of column name to value.
pub fn (r Row) as_map() map[string]string {
	mut m := map[string]string{}
	for i, c in r.cols {
		m[c] = r.vals[i]
	}
	return m
}

// DB wraps a SQLite connection with column-aware query execution.
pub struct DB {
mut:
	conn sqlite.DB
}

// connect opens (or creates) a SQLite database at path.
// Use ':memory:' for an in-memory database.
pub fn connect(path string) !DB {
	conn := sqlite.connect(path)!
	mut db := DB{conn: conn}
	db.conn.exec_none('PRAGMA journal_mode=WAL')
	db.conn.exec_none('PRAGMA foreign_keys=ON')
	return db
}

// exec runs a query and returns rows with column names resolved.
pub fn (mut db DB) exec(stmt string) ![]Row {
	raw := db.conn.exec(stmt)!
	if raw.len == 0 {
		return []Row{}
	}
	cols := db.column_names(stmt)
	return raw.map(Row{
		cols: cols
		vals: it.vals
	})
}

// exec_one runs a query and returns the first row, or an error if no rows.
pub fn (mut db DB) exec_one(stmt string) !Row {
	rows := db.exec(stmt)!
	if rows.len == 0 {
		return error('exec_one: no rows returned')
	}
	return rows[0]
}

// exec_none runs a statement that returns no rows (INSERT, UPDATE, DELETE, DDL).
pub fn (mut db DB) exec_none(stmt string) {
	db.conn.exec_none(stmt)
}

// last_insert_rowid returns the rowid of the last INSERT.
pub fn (db DB) last_insert_rowid() i64 {
	return db.conn.last_insert_rowid()
}

// affected_rows returns the number of rows changed by the last statement.
pub fn (db DB) affected_rows() int {
	return db.conn.get_affected_rows_count()
}

// tables returns a list of all table names in the database.
pub fn (mut db DB) tables() []string {
	rows := db.conn.exec("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name") or {
		return []string{}
	}
	return rows.map(it.vals[0])
}

// schema returns the CREATE statement(s) for the given table (or all objects if empty).
pub fn (mut db DB) schema(table string) string {
	filter := if table != '' { "AND name='${table}'" } else { '' }
	rows := db.conn.exec("SELECT sql FROM sqlite_master WHERE type IN ('table','index','view','trigger') ${filter} AND sql IS NOT NULL ORDER BY type,name") or {
		return ''
	}
	return rows.map(it.vals[0]).join('\n\n')
}

// size returns the database file size in bytes.
pub fn (mut db DB) size() i64 {
	rows_pc := db.conn.exec('PRAGMA page_count') or { return 0 }
	rows_ps := db.conn.exec('PRAGMA page_size') or { return 0 }
	if rows_pc.len == 0 || rows_ps.len == 0 {
		return 0
	}
	return rows_pc[0].vals[0].i64() * rows_ps[0].vals[0].i64()
}

// columns returns the column names for a table.
pub fn (mut db DB) columns(table string) []string {
	rows := db.conn.exec('PRAGMA table_info(${table})') or { return []string{} }
	return rows.map(it.vals[1])
}

// exec_params runs a parameterized query with ? placeholders and returns rows.
// Example: db.exec_params('SELECT * FROM users WHERE id = ?', ['1'])!
pub fn (mut db DB) exec_params(stmt string, params []string) ![]Row {
	raw := db.conn.exec_param_many(stmt, params)!
	if raw.len == 0 {
		return []Row{}
	}
	cols := db.column_names(stmt)
	return raw.map(Row{
		cols: cols
		vals: it.vals
	})
}

// exec_none_params runs a parameterized DML/DDL statement with ? placeholders.
// Example: db.exec_none_params('INSERT INTO t VALUES (?, ?)', ['1', 'Alice'])
pub fn (mut db DB) exec_none_params(stmt string, params []string) {
	db.conn.exec_param_many(stmt, params) or {}
}

// column_names resolves column names for a SELECT statement.
// For SELECT *, it falls back to PRAGMA table_info.
fn (mut db DB) column_names(stmt string) []string {
	upper := stmt.trim_space().to_upper()
	if !upper.starts_with('SELECT') {
		return []string{}
	}
	from_idx := upper.index(' FROM ') or { return []string{} }
	select_part := stmt[7..from_idx].trim_space()

	if select_part == '*' || select_part.contains('*') {
		table_name := extract_table_name(upper)
		if table_name == '' {
			return []string{}
		}
		rows := db.conn.exec('PRAGMA table_info(${table_name})') or { return []string{} }
		return rows.map(it.vals[1])
	}

	mut cols := []string{}
	for col in select_part.split(',') {
		trimmed := col.trim_space()
		upper_col := trimmed.to_upper()
		if upper_col.contains(' AS ') {
			parts := trimmed.split_nth(' ', 3)
			if parts.len >= 3 {
				cols << parts[2].trim_space()
				continue
			}
		}
		if trimmed.contains('.') {
			cols << trimmed.split('.').last().trim_space()
			continue
		}
		cols << trimmed
	}
	return cols
}

fn extract_table_name(upper_stmt string) string {
	from_idx := upper_stmt.index(' FROM ') or { return '' }
	after_from := upper_stmt[from_idx + 6..].trim_space()
	end := after_from.index_any(' ,();')
	if end < 0 {
		return after_from.to_lower()
	}
	return after_from[..end].to_lower()
}
