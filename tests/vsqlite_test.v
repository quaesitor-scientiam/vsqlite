module main

import vsqlite

// --- DB connection ---

fn test_connect_memory() {
	db := vsqlite.connect(':memory:') or { panic(err) }
	_ = db
}

fn test_connect_bad_path() {
	// SQLite creates the file if it doesn't exist, so test a read-only path
	vsqlite.connect('/no/such/dir/test.db') or { return }
	// If it somehow succeeded, that's also fine on some systems
}

// --- exec / exec_none ---

fn setup() vsqlite.DB {
	mut db := vsqlite.connect(':memory:') or { panic(err) }
	db.exec_none('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)')
	db.exec_none("INSERT INTO users VALUES (1, 'Alice', 30)")
	db.exec_none("INSERT INTO users VALUES (2, 'Bob', 25)")
	db.exec_none("INSERT INTO users VALUES (3, 'Carol', 35)")
	return db
}

fn test_exec_returns_rows() {
	mut db := setup()
	rows := db.exec('SELECT * FROM users') or { panic(err) }
	assert rows.len == 3
}

fn test_exec_column_names_star() {
	mut db := setup()
	rows := db.exec('SELECT * FROM users') or { panic(err) }
	assert rows.len > 0
	assert rows[0].cols == ['id', 'name', 'age']
}

fn test_exec_column_names_explicit() {
	mut db := setup()
	rows := db.exec('SELECT name, age FROM users') or { panic(err) }
	assert rows[0].cols == ['name', 'age']
}

fn test_exec_column_alias() {
	mut db := setup()
	rows := db.exec('SELECT name AS n, age AS a FROM users LIMIT 1') or { panic(err) }
	assert rows[0].cols == ['n', 'a']
}

fn test_exec_values() {
	mut db := setup()
	rows := db.exec('SELECT * FROM users WHERE id = 1') or { panic(err) }
	assert rows.len == 1
	assert rows[0].vals[1] == 'Alice'
	assert rows[0].vals[2] == '30'
}

fn test_exec_empty() {
	mut db := setup()
	rows := db.exec('SELECT * FROM users WHERE id = 999') or { panic(err) }
	assert rows.len == 0
}

fn test_exec_one() {
	mut db := setup()
	row := db.exec_one('SELECT * FROM users WHERE id = 2') or { panic(err) }
	assert row.vals[1] == 'Bob'
}

fn test_exec_one_no_rows() {
	mut db := setup()
	db.exec_one('SELECT * FROM users WHERE id = 999') or { return }
	assert false, 'should have returned error'
}

// --- Row methods ---

fn test_row_get_by_name() {
	mut db := setup()
	row := db.exec_one('SELECT * FROM users WHERE id = 1') or { panic(err) }
	assert row.get('name') == 'Alice'
	assert row.get('age') == '30'
}

fn test_row_get_missing_col() {
	mut db := setup()
	row := db.exec_one('SELECT * FROM users LIMIT 1') or { panic(err) }
	assert row.get('nonexistent') == ''
}

fn test_row_as_map() {
	mut db := setup()
	row := db.exec_one('SELECT * FROM users WHERE id = 1') or { panic(err) }
	m := row.as_map()
	assert m['name'] == 'Alice'
	assert m['age'] == '30'
}

// --- DML ---

fn test_insert_rowid() {
	mut db := setup()
	db.exec_none("INSERT INTO users VALUES (4, 'Dave', 28)")
	assert db.last_insert_rowid() == 4
}

fn test_affected_rows_update() {
	mut db := setup()
	db.exec_none('UPDATE users SET age = 99 WHERE age < 35')
	assert db.affected_rows() == 2
}

fn test_affected_rows_delete() {
	mut db := setup()
	db.exec_none('DELETE FROM users WHERE id = 1')
	assert db.affected_rows() == 1
	rows := db.exec('SELECT * FROM users') or { panic(err) }
	assert rows.len == 2
}

// --- Meta ---

fn test_tables() {
	mut db := setup()
	db.exec_none('CREATE TABLE products (id INTEGER, name TEXT)')
	tables := db.tables()
	assert 'users' in tables
	assert 'products' in tables
}

fn test_tables_empty() {
	mut db := vsqlite.connect(':memory:') or { panic(err) }
	assert db.tables().len == 0
}

fn test_schema() {
	mut db := setup()
	schema := db.schema('users')
	assert schema.contains('CREATE TABLE users')
	assert schema.contains('name TEXT')
}

fn test_schema_all() {
	mut db := setup()
	db.exec_none('CREATE INDEX idx_name ON users(name)')
	schema := db.schema('')
	assert schema.contains('CREATE TABLE users')
	assert schema.contains('CREATE INDEX idx_name')
}

fn test_size() {
	mut db := setup()
	assert db.size() > 0
}

// --- Formatting ---

fn test_format_table() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 2') or { panic(err) }
	out := vsqlite.format(rows, .table, true)
	assert out.contains('Alice')
	assert out.contains('Bob')
	assert out.contains('|')
	assert out.contains('+')
}

fn test_format_csv() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 2') or { panic(err) }
	out := vsqlite.format(rows, .csv, true)
	lines := out.split_into_lines()
	assert lines[0] == 'id,name'
	assert lines[1] == '1,Alice'
}

fn test_format_csv_no_headers() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := vsqlite.format(rows, .csv, false)
	assert out.starts_with('1,Alice')
}

fn test_format_line() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := vsqlite.format(rows, .line, true)
	assert out.contains('id:')
	assert out.contains('name:')
	assert out.contains('Alice')
}

fn test_format_empty() {
	rows := []vsqlite.Row{}
	assert vsqlite.format(rows, .table, true) == ''
	assert vsqlite.format(rows, .csv, true) == ''
	assert vsqlite.format(rows, .line, true) == ''
}

// --- CSV ---

fn test_csv_escape_plain() {
	assert vsqlite.csv_escape('hello') == 'hello'
}

fn test_csv_escape_with_comma() {
	assert vsqlite.csv_escape('a,b') == '"a,b"'
}

fn test_csv_escape_with_quotes() {
	assert vsqlite.csv_escape('say "hi"') == '"say ""hi"""'
}

fn test_parse_csv_line_simple() {
	assert vsqlite.parse_csv_line('a,b,c') == ['a', 'b', 'c']
}

fn test_parse_csv_line_quoted() {
	assert vsqlite.parse_csv_line('"a,b",c') == ['a,b', 'c']
}

fn test_parse_csv_line_escaped_quote() {
	assert vsqlite.parse_csv_line('"say ""hi""",x') == ['say "hi"', 'x']
}
