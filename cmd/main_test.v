module main

import os
import readline
import time

// --- format_bytes ---

fn test_format_bytes_b() {
	assert format_bytes(0) == '0 B'
	assert format_bytes(500) == '500 B'
	assert format_bytes(1023) == '1023 B'
}

fn test_format_bytes_kb() {
	assert format_bytes(1024) == '1 KB'
	assert format_bytes(2 * 1024) == '2 KB'
}

fn test_format_bytes_mb() {
	assert format_bytes(1024 * 1024) == '1 MB'
	assert format_bytes(3 * 1024 * 1024) == '3 MB'
}

fn test_format_bytes_gb() {
	assert format_bytes(1024 * 1024 * 1024) == '1 GB'
	assert format_bytes(2 * 1024 * 1024 * 1024) == '2 GB'
}

// --- history_load ---

fn test_history_load_populates_lines() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_hist_load.txt')
	os.write_file(tmp, 'SELECT 1\nSELECT 2\n.tables\n') or { panic(err) }
	defer {
		os.rm(tmp) or {}
	}
	mut rl := readline.Readline{}
	history_load(mut rl, tmp)
	assert rl.previous_lines.len == 3
	assert rl.previous_lines[0].string() == 'SELECT 1'
	assert rl.previous_lines[1].string() == 'SELECT 2'
	assert rl.previous_lines[2].string() == '.tables'
}

fn test_history_load_skips_empty_lines() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_hist_empty.txt')
	os.write_file(tmp, 'SELECT 1\n\n\nSELECT 2\n') or { panic(err) }
	defer {
		os.rm(tmp) or {}
	}
	mut rl := readline.Readline{}
	history_load(mut rl, tmp)
	assert rl.previous_lines.len == 2
}

fn test_history_load_missing_file() {
	mut rl := readline.Readline{}
	history_load(mut rl, '/no/such/path/vsqlite_history.txt')
	assert rl.previous_lines.len == 0
}

fn test_history_load_appends_to_existing() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_hist_append.txt')
	os.write_file(tmp, 'SELECT 3\n') or { panic(err) }
	defer {
		os.rm(tmp) or {}
	}
	mut rl := readline.Readline{}
	rl.previous_lines << 'SELECT 1'.runes()
	rl.previous_lines << 'SELECT 2'.runes()
	history_load(mut rl, tmp)
	assert rl.previous_lines.len == 3
	assert rl.previous_lines[2].string() == 'SELECT 3'
}

// --- history_save ---

fn test_history_save_writes_lines() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_hist_save.txt')
	defer {
		os.rm(tmp) or {}
	}
	mut rl := readline.Readline{}
	rl.previous_lines << 'SELECT 1'.runes()
	rl.previous_lines << 'INSERT INTO foo VALUES (1)'.runes()
	history_save(rl, tmp)
	content := os.read_file(tmp) or { panic(err) }
	lines := content.split('\n').filter(it.len > 0)
	assert lines.len == 2
	assert lines[0] == 'SELECT 1'
	assert lines[1] == 'INSERT INTO foo VALUES (1)'
}

fn test_history_save_empty_history() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_hist_empty_save.txt')
	defer {
		os.rm(tmp) or {}
	}
	rl := readline.Readline{}
	history_save(rl, tmp)
	content := os.read_file(tmp) or { panic(err) }
	assert content.trim_space() == ''
}

// --- last_token_start ---

fn test_last_token_start_whole_word() {
	assert last_token_start('SELECT') == 0
}

fn test_last_token_start_after_space() {
	// 'SELECT * FROM ' — last space at index 13, token starts at 14
	assert last_token_start('SELECT * FROM ') == 14
}

fn test_last_token_start_partial_token() {
	// 'SELECT * FROM u' — space at 13, token 'u' starts at 14
	assert last_token_start('SELECT * FROM u') == 14
}

fn test_last_token_start_after_paren() {
	// 'INSERT INTO t(' — '(' at 13, token starts at 14
	assert last_token_start('INSERT INTO t(') == 14
}

fn test_last_token_start_after_comma() {
	// 'SELECT id,na' — ',' at 9, token starts at 10
	assert last_token_start('SELECT id,na') == 10
}

fn test_last_token_start_empty() {
	assert last_token_start('') == 0
}

// --- make_completer ---

fn test_complete_keyword_prefix() {
	cb := make_completer(['SELECT', 'SET', 'FROM', 'WHERE'])
	results := cb('SE')
	assert 'SELECT' in results
	assert 'SET' in results
	assert 'FROM' !in results
}

fn test_complete_keyword_case_insensitive() {
	cb := make_completer(['SELECT', 'FROM'])
	results := cb('sel')
	assert 'SELECT' in results
}

fn test_complete_mid_line_table_name() {
	cb := make_completer(['SELECT', 'FROM', 'users', 'products'])
	results := cb('SELECT * FROM u')
	assert 'SELECT * FROM users' in results
	assert 'SELECT * FROM products' !in results
}

fn test_complete_after_comma() {
	cb := make_completer(['id', 'name', 'age', 'SELECT'])
	results := cb('SELECT id,na')
	assert 'SELECT id,name' in results
	assert 'SELECT id,age' !in results
}

fn test_complete_dot_command() {
	cb := make_completer(['.tables', '.schema', '.mode', 'SELECT'])
	results := cb('.tab')
	assert '.tables' in results
	assert '.schema' !in results
	assert 'SELECT' !in results
}

fn test_complete_dot_command_with_space_not_treated_as_dot() {
	// '.mode ' has a space — last token is '', so no results
	cb := make_completer(['.tables', '.mode'])
	results := cb('.mode ')
	assert results == []string{}
}

fn test_complete_empty_line_returns_nothing() {
	cb := make_completer(['SELECT', 'FROM'])
	assert cb('') == []string{}
}

fn test_complete_no_match_returns_nothing() {
	cb := make_completer(['SELECT', 'FROM'])
	assert cb('ZZZ') == []string{}
}

fn test_complete_full_replacement() {
	// Verifies each result is a full line, not just the matched word
	cb := make_completer(['users', 'products'])
	results := cb('SELECT * FROM u')
	for r in results {
		assert r.starts_with('SELECT * FROM ')
	}
}

// --- stmt_complete ---

fn test_stmt_complete_single_line_with_semicolon() {
	assert stmt_complete(['SELECT 1;']) == true
}

fn test_stmt_complete_single_line_no_semicolon() {
	assert stmt_complete(['SELECT 1']) == false
}

fn test_stmt_complete_multiline_complete() {
	assert stmt_complete(['SELECT *', 'FROM users', 'WHERE id = 1;']) == true
}

fn test_stmt_complete_multiline_incomplete() {
	assert stmt_complete(['SELECT *', 'FROM users']) == false
}

fn test_stmt_complete_trailing_whitespace() {
	assert stmt_complete(['SELECT 1;   ']) == true
}

fn test_stmt_complete_empty() {
	assert stmt_complete([]) == false
}

// --- split_statements ---

fn test_split_single_no_semicolon() {
	assert split_statements('SELECT 1') == ['SELECT 1']
}

fn test_split_single_with_semicolon() {
	assert split_statements('SELECT 1;') == ['SELECT 1']
}

fn test_split_multiple_statements() {
	stmts := split_statements('SELECT 1; SELECT 2; SELECT 3')
	assert stmts.len == 3
	assert stmts[0] == 'SELECT 1'
	assert stmts[1] == 'SELECT 2'
	assert stmts[2] == 'SELECT 3'
}

fn test_split_multiple_with_trailing_semicolon() {
	stmts := split_statements('SELECT 1; SELECT 2;')
	assert stmts.len == 2
	assert stmts[0] == 'SELECT 1'
	assert stmts[1] == 'SELECT 2'
}

fn test_split_quoted_semicolon_not_split() {
	stmts := split_statements("INSERT INTO t VALUES ('a;b'); SELECT 1")
	assert stmts.len == 2
	assert stmts[0] == "INSERT INTO t VALUES ('a;b')"
	assert stmts[1] == 'SELECT 1'
}

fn test_split_double_quoted_semicolon_not_split() {
	stmts := split_statements('SELECT "col;name" FROM t; SELECT 2')
	assert stmts.len == 2
	assert stmts[0] == 'SELECT "col;name" FROM t'
	assert stmts[1] == 'SELECT 2'
}

fn test_split_empty_input() {
	assert split_statements('') == []string{}
}

fn test_split_only_semicolons() {
	assert split_statements(';;;') == []string{}
}

fn test_split_multiline_statement() {
	src := 'SELECT id,\nname\nFROM users\nWHERE id = 1; SELECT 2'
	stmts := split_statements(src)
	assert stmts.len == 2
	assert stmts[0].contains('FROM users')
	assert stmts[1] == 'SELECT 2'
}

fn test_split_whitespace_between() {
	stmts := split_statements('  SELECT 1 ;  SELECT 2  ;  ')
	assert stmts.len == 2
	assert stmts[0] == 'SELECT 1'
	assert stmts[1] == 'SELECT 2'
}

// --- format_duration ---

fn test_format_duration_microseconds() {
	d := time.Duration(500 * 1000) // 500 µs
	assert format_duration(d) == '500 µs'
}

fn test_format_duration_milliseconds() {
	d := time.Duration(2_500 * 1000) // 2500 µs = 2.500 ms
	result := format_duration(d)
	assert result.contains('ms')
	assert result.contains('2.')
}

fn test_format_duration_zero() {
	d := time.Duration(0)
	assert format_duration(d) == '0 µs'
}

// --- roundtrip ---

// --- log_stmt ---

fn test_log_stmt_writes_statement() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_log_write.sql')
	defer {
		os.rm(tmp) or {}
	}
	mut db := connect(':memory:') or { panic(err) }
	mut app := App{ db: db, log_path: tmp }
	app.log_stmt('SELECT 1')
	content := os.read_file(tmp) or { panic(err) }
	assert content.contains('SELECT 1;')
}

fn test_log_stmt_appends_multiple() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_log_multi.sql')
	defer {
		os.rm(tmp) or {}
	}
	mut db := connect(':memory:') or { panic(err) }
	mut app := App{ db: db, log_path: tmp }
	app.log_stmt('SELECT 1')
	app.log_stmt('SELECT 2')
	content := os.read_file(tmp) or { panic(err) }
	assert content.contains('SELECT 1;')
	assert content.contains('SELECT 2;')
}

fn test_log_stmt_disabled_when_no_path() {
	// No log_path set — must not panic or write any file
	mut db := connect(':memory:') or { panic(err) }
	mut app := App{ db: db }
	app.log_stmt('SELECT 1') // should be a no-op
	assert app.log_path == ''
}

// --- App defaults ---

fn test_app_defaults_bail_off() {
	mut db := connect(':memory:') or { panic(err) }
	app := App{ db: db }
	assert app.bail == false
}

fn test_app_defaults_echo_off() {
	mut db := connect(':memory:') or { panic(err) }
	app := App{ db: db }
	assert app.echo == false
}

fn test_app_defaults_changes_off() {
	mut db := connect(':memory:') or { panic(err) }
	app := App{ db: db }
	assert app.changes == false
}

fn test_app_defaults_log_path_empty() {
	mut db := connect(':memory:') or { panic(err) }
	app := App{ db: db }
	assert app.log_path == ''
}

// --- roundtrip ---

fn test_history_roundtrip() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_hist_roundtrip.txt')
	defer {
		os.rm(tmp) or {}
	}
	mut rl := readline.Readline{}
	rl.previous_lines << 'SELECT * FROM users'.runes()
	rl.previous_lines << '.tables'.runes()
	rl.previous_lines << '.mode csv'.runes()
	history_save(rl, tmp)
	mut rl2 := readline.Readline{}
	history_load(mut rl2, tmp)
	assert rl2.previous_lines.len == 3
	assert rl2.previous_lines[0].string() == 'SELECT * FROM users'
	assert rl2.previous_lines[1].string() == '.tables'
	assert rl2.previous_lines[2].string() == '.mode csv'
}

// =============================================================================
// DB / Row / format / CSV tests (moved from tests/vsqlite_test.v)
// =============================================================================

fn setup() DB {
	mut db := connect(':memory:') or { panic(err) }
	db.exec_none('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)')
	db.exec_none("INSERT INTO users VALUES (1, 'Alice', 30)")
	db.exec_none("INSERT INTO users VALUES (2, 'Bob', 25)")
	db.exec_none("INSERT INTO users VALUES (3, 'Carol', 35)")
	return db
}

// --- connect ---

fn test_connect_memory() {
	db := connect(':memory:') or { panic(err) }
	_ = db
}

fn test_connect_bad_path() {
	connect('/no/such/dir/test.db') or { return }
}

// --- exec / exec_none ---

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
	mut db := connect(':memory:') or { panic(err) }
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

fn test_columns() {
	mut db := setup()
	cols := db.columns('users')
	assert cols == ['id', 'name', 'age']
}

fn test_columns_unknown_table() {
	mut db := setup()
	assert db.columns('no_such_table') == []string{}
}

// --- Formatting ---

fn test_format_table() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 2') or { panic(err) }
	out := format(rows, .table, true)
	assert out.contains('Alice')
	assert out.contains('Bob')
	assert out.contains('|')
	assert out.contains('+')
}

fn test_format_csv() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 2') or { panic(err) }
	out := format(rows, .csv, true)
	lines := out.split_into_lines()
	assert lines[0] == 'id,name'
	assert lines[1] == '1,Alice'
}

fn test_format_csv_no_headers() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := format(rows, .csv, false)
	assert out.starts_with('1,Alice')
}

fn test_format_line() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := format(rows, .line, true)
	assert out.contains('id:')
	assert out.contains('name:')
	assert out.contains('Alice')
}

fn test_format_empty() {
	rows := []Row{}
	assert format(rows, .table, true) == ''
	assert format(rows, .csv, true) == ''
	assert format(rows, .line, true) == ''
}

// --- CSV ---

fn test_csv_escape_plain() {
	assert csv_escape('hello') == 'hello'
}

fn test_csv_escape_with_comma() {
	assert csv_escape('a,b') == '"a,b"'
}

fn test_csv_escape_with_quotes() {
	assert csv_escape('say "hi"') == '"say ""hi"""'
}

fn test_parse_csv_line_simple() {
	assert parse_csv_line('a,b,c') == ['a', 'b', 'c']
}

fn test_parse_csv_line_quoted() {
	assert parse_csv_line('"a,b",c') == ['a,b', 'c']
}

fn test_parse_csv_line_escaped_quote() {
	assert parse_csv_line('"say ""hi""",x') == ['say "hi"', 'x']
}

// --- FormatOptions / new modes ---

fn test_format_opts_nullvalue() {
	rows := [Row{cols: ['a'], vals: ['']}]
	out := format_opts(rows, FormatOptions{
		mode:      .csv
		headers:   false
		nullvalue: 'N/A'
	})
	assert out == 'N/A'
}

fn test_format_opts_separator() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := format_opts(rows, FormatOptions{
		mode:      .csv
		headers:   false
		separator: '|'
	})
	assert out == '1|Alice'
}

fn test_format_opts_col_widths() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	mut widths := map[int]int{}
	widths[0] = 10
	out := format_opts(rows, FormatOptions{
		mode:      .table
		headers:   false
		col_widths: widths
	})
	assert out.contains('1         ')
}

fn test_format_box() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 2') or { panic(err) }
	out := format_opts(rows, FormatOptions{ mode: .box, headers: true })
	assert out.contains('┌')
	assert out.contains('┐')
	assert out.contains('└')
	assert out.contains('┘')
	assert out.contains('Alice')
	assert out.contains('Bob')
}

fn test_format_box_no_headers() {
	mut db := setup()
	rows := db.exec('SELECT id FROM users LIMIT 1') or { panic(err) }
	out := format_opts(rows, FormatOptions{ mode: .box, headers: false })
	assert out.contains('┌')
	assert !out.contains('├')
}

fn test_format_markdown() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 2') or { panic(err) }
	out := format_opts(rows, FormatOptions{ mode: .markdown, headers: true })
	lines := out.split_into_lines()
	assert lines.len == 4
	assert lines[0].starts_with('|')
	assert lines[1].contains('---')
	assert lines[2].contains('Alice')
	assert lines[3].contains('Bob')
}

fn test_format_json() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := format_opts(rows, FormatOptions{ mode: .json })
	assert out.starts_with('[')
	assert out.ends_with(']')
	assert out.contains('"id"')
	assert out.contains('"name"')
	assert out.contains('"Alice"')
}

fn test_format_json_empty() {
	rows := []Row{}
	out := format_opts(rows, FormatOptions{ mode: .json })
	assert out == '[]'
}

fn test_format_json_null() {
	rows := [Row{cols: ['x'], vals: ['']}]
	out := format_opts(rows, FormatOptions{ mode: .json })
	assert out.contains(':null')
}

fn test_format_html() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := format_opts(rows, FormatOptions{ mode: .html, headers: true })
	assert out.contains('<table>')
	assert out.contains('</table>')
	assert out.contains('<th>id</th>')
	assert out.contains('<td>Alice</td>')
}

fn test_format_html_escape() {
	rows := [Row{cols: ['x'], vals: ['<b>hi</b>']}]
	out := format_opts(rows, FormatOptions{ mode: .html, headers: false })
	assert out.contains('&lt;b&gt;hi&lt;/b&gt;')
}

fn test_format_insert() {
	mut db := setup()
	rows := db.exec("SELECT id, name FROM users WHERE id = 1") or { panic(err) }
	out := format_opts(rows, FormatOptions{
		mode:       .insert
		table_name: 'users'
	})
	assert out.contains("INSERT INTO users(id,name) VALUES('1','Alice');")
}

fn test_format_insert_null() {
	rows := [Row{cols: ['a', 'b'], vals: ['1', '']}]
	out := format_opts(rows, FormatOptions{ mode: .insert, table_name: 'tbl' })
	assert out.contains('NULL')
	assert out.contains("'1'")
}

fn test_format_quote() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := format_opts(rows, FormatOptions{ mode: .quote, headers: false })
	assert out == "'1','Alice'"
}

fn test_format_quote_with_headers() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := format_opts(rows, FormatOptions{ mode: .quote, headers: true })
	lines := out.split_into_lines()
	assert lines[0] == 'id,name'
	assert lines[1] == "'1','Alice'"
}

fn test_format_all_empty() {
	rows := []Row{}
	for mode in [OutputMode.box, .markdown, .html, .insert, .quote] {
		assert format_opts(rows, FormatOptions{ mode: mode }) == ''
	}
}

// --- exec_params ---

fn test_exec_params_single_bind() {
	mut db := setup()
	rows := db.exec_params('SELECT * FROM users WHERE id = ?', ['1']) or { panic(err) }
	assert rows.len == 1
	assert rows[0].get('name') == 'Alice'
}

fn test_exec_params_multiple_binds() {
	mut db := setup()
	rows := db.exec_params('SELECT * FROM users WHERE age >= ? AND age <= ?', ['25', '30']) or {
		panic(err)
	}
	assert rows.len == 2
}

fn test_exec_params_no_rows() {
	mut db := setup()
	rows := db.exec_params('SELECT * FROM users WHERE id = ?', ['999']) or { panic(err) }
	assert rows.len == 0
}

fn test_exec_params_string_bind() {
	mut db := setup()
	rows := db.exec_params("SELECT * FROM users WHERE name = ?", ['Bob']) or { panic(err) }
	assert rows.len == 1
	assert rows[0].get('age') == '25'
}

fn test_exec_none_params_insert() {
	mut db := setup()
	db.exec_none_params('INSERT INTO users VALUES (?, ?, ?)', ['4', 'Dave', '28'])
	assert db.last_insert_rowid() == 4
	rows := db.exec('SELECT * FROM users WHERE id = 4') or { panic(err) }
	assert rows.len == 1
	assert rows[0].get('name') == 'Dave'
}

fn test_exec_none_params_update() {
	mut db := setup()
	db.exec_none_params('UPDATE users SET age = ? WHERE id = ?', ['99', '1'])
	rows := db.exec('SELECT age FROM users WHERE id = 1') or { panic(err) }
	assert rows[0].vals[0] == '99'
}

fn test_exec_none_params_delete() {
	mut db := setup()
	db.exec_none_params('DELETE FROM users WHERE id = ?', ['2'])
	rows := db.exec('SELECT * FROM users') or { panic(err) }
	assert rows.len == 2
}

// --- dump ---

fn test_dump_contains_create() {
	mut db := setup()
	text := db.dump()
	assert text.contains('CREATE TABLE users')
}

fn test_dump_contains_data() {
	mut db := setup()
	text := db.dump()
	assert text.contains('Alice')
	assert text.contains('Bob')
	assert text.contains('Carol')
}

fn test_dump_transaction_wrapped() {
	mut db := setup()
	text := db.dump()
	assert text.contains('BEGIN TRANSACTION;')
	assert text.contains('COMMIT;')
}

fn test_dump_insert_statements() {
	mut db := setup()
	text := db.dump()
	assert text.contains('INSERT INTO "users"')
	assert text.contains('"id"')
	assert text.contains('"name"')
	assert text.contains('"age"')
}

fn test_dump_empty_db() {
	mut db := connect(':memory:') or { panic(err) }
	text := db.dump()
	assert text.contains('BEGIN TRANSACTION;')
	assert text.contains('COMMIT;')
	assert !text.contains('INSERT')
}

fn test_dump_includes_indexes() {
	mut db := setup()
	db.exec_none('CREATE INDEX idx_name ON users(name)')
	text := db.dump()
	assert text.contains('CREATE INDEX idx_name')
}

fn test_dump_roundtrip() {
	mut src := setup()
	script := src.dump()
	mut dst := connect(':memory:') or { panic(err) }
	for stmt in script.split(';') {
		s := stmt.trim_space()
		if s != '' && !s.starts_with('--') {
			dst.exec_none(s)
		}
	}
	rows := dst.exec('SELECT * FROM users ORDER BY id') or { panic(err) }
	assert rows.len == 3
	assert rows[0].get('name') == 'Alice'
	assert rows[1].get('name') == 'Bob'
	assert rows[2].get('name') == 'Carol'
}

// --- parse_csv_records / read_csv_sep / read_tsv ---

fn test_parse_csv_records_basic() {
	records := parse_csv_records('a,b\n1,2\n', `,`)
	assert records.len == 2
	assert records[0] == ['a', 'b']
	assert records[1] == ['1', '2']
}

fn test_parse_csv_records_crlf() {
	records := parse_csv_records('a,b\r\n1,2\r\n', `,`)
	assert records.len == 2
	assert records[0] == ['a', 'b']
	assert records[1] == ['1', '2']
}

fn test_parse_csv_records_embedded_newline() {
	content := '"line1\nline2",b\nc,d\n'
	records := parse_csv_records(content, `,`)
	assert records.len == 2
	assert records[0][0] == 'line1\nline2'
	assert records[0][1] == 'b'
	assert records[1][0] == 'c'
	assert records[1][1] == 'd'
}

fn test_parse_csv_records_blank_lines_skipped() {
	records := parse_csv_records('a,b\n\n1,2\n\n', `,`)
	assert records.len == 2
}

fn test_parse_csv_records_no_trailing_newline() {
	records := parse_csv_records('a,b\n1,2', `,`)
	assert records.len == 2
	assert records[1] == ['1', '2']
}

fn test_parse_csv_records_tab_sep() {
	records := parse_csv_records("id\tname\n1\tAlice\n", `\t`)
	assert records.len == 2
	assert records[0] == ['id', 'name']
	assert records[1] == ['1', 'Alice']
}

fn test_parse_csv_line_sep_pipe() {
	assert parse_csv_line_sep('a|b|c', `|`) == ['a', 'b', 'c']
}

fn test_parse_csv_line_sep_tab() {
	assert parse_csv_line_sep('a\tb\tc', `\t`) == ['a', 'b', 'c']
}

fn test_read_csv_sep_tsv() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_test_tsv.tsv')
	os.write_file(tmp, "id\tname\n1\tAlice\n2\tBob\n") or { panic(err) }
	defer {
		os.rm(tmp) or {}
	}
	headers, rows := read_tsv(tmp) or { panic(err) }
	assert headers == ['id', 'name']
	assert rows.len == 2
	assert rows[0][1] == 'Alice'
	assert rows[1][1] == 'Bob'
}

fn test_read_csv_quoted_comma() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_test_qc.csv')
	os.write_file(tmp, 'name,note\nAlice,"hello, world"\n') or { panic(err) }
	defer {
		os.rm(tmp) or {}
	}
	headers, rows := read_csv(tmp) or { panic(err) }
	assert headers == ['name', 'note']
	assert rows[0][1] == 'hello, world'
}
