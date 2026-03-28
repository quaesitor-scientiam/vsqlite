module main

import os
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

// --- FormatOptions / new modes ---

fn test_format_opts_nullvalue() {
	rows := [vsqlite.Row{cols: ['a'], vals: ['']}]
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{
		mode:      .csv
		headers:   false
		nullvalue: 'N/A'
	})
	assert out == 'N/A'
}

fn test_format_opts_separator() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{
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
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{
		mode:      .table
		headers:   false
		col_widths: widths
	})
	// The id column should be padded to width 10
	assert out.contains('1         ')
}

fn test_format_box() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 2') or { panic(err) }
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .box, headers: true })
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
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .box, headers: false })
	assert out.contains('┌')
	assert !out.contains('├') // no header separator when headers off
}

fn test_format_markdown() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 2') or { panic(err) }
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .markdown, headers: true })
	lines := out.split_into_lines()
	assert lines.len == 4 // header + separator + 2 data rows
	assert lines[0].starts_with('|')
	assert lines[1].contains('---')
	assert lines[2].contains('Alice')
	assert lines[3].contains('Bob')
}

fn test_format_json() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .json })
	assert out.starts_with('[')
	assert out.ends_with(']')
	assert out.contains('"id"')
	assert out.contains('"name"')
	assert out.contains('"Alice"')
}

fn test_format_json_empty() {
	rows := []vsqlite.Row{}
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .json })
	assert out == '[]'
}

fn test_format_json_null() {
	rows := [vsqlite.Row{cols: ['x'], vals: ['']}]
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .json })
	assert out.contains(':null')
}

fn test_format_html() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .html, headers: true })
	assert out.contains('<table>')
	assert out.contains('</table>')
	assert out.contains('<th>id</th>')
	assert out.contains('<td>Alice</td>')
}

fn test_format_html_escape() {
	rows := [vsqlite.Row{cols: ['x'], vals: ['<b>hi</b>']}]
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .html, headers: false })
	assert out.contains('&lt;b&gt;hi&lt;/b&gt;')
}

fn test_format_insert() {
	mut db := setup()
	rows := db.exec("SELECT id, name FROM users WHERE id = 1") or { panic(err) }
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{
		mode:       .insert
		table_name: 'users'
	})
	assert out.contains("INSERT INTO users(id,name) VALUES('1','Alice');")
}

fn test_format_insert_null() {
	rows := [vsqlite.Row{cols: ['a', 'b'], vals: ['1', '']}]
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .insert, table_name: 'tbl' })
	assert out.contains('NULL')
	assert out.contains("'1'")
}

fn test_format_quote() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .quote, headers: false })
	assert out == "'1','Alice'"
}

fn test_format_quote_with_headers() {
	mut db := setup()
	rows := db.exec('SELECT id, name FROM users LIMIT 1') or { panic(err) }
	out := vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: .quote, headers: true })
	lines := out.split_into_lines()
	assert lines[0] == 'id,name'
	assert lines[1] == "'1','Alice'"
}

fn test_format_all_empty() {
	rows := []vsqlite.Row{}
	for mode in [vsqlite.OutputMode.box, .markdown, .html, .insert, .quote] {
		assert vsqlite.format_opts(rows, vsqlite.FormatOptions{ mode: mode }) == ''
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
	mut db := vsqlite.connect(':memory:') or { panic(err) }
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
	// Dump a database and reload it; the data should be identical.
	mut src := setup()
	script := src.dump()
	mut dst := vsqlite.connect(':memory:') or { panic(err) }
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
	records := vsqlite.parse_csv_records('a,b\n1,2\n', `,`)
	assert records.len == 2
	assert records[0] == ['a', 'b']
	assert records[1] == ['1', '2']
}

fn test_parse_csv_records_crlf() {
	records := vsqlite.parse_csv_records('a,b\r\n1,2\r\n', `,`)
	assert records.len == 2
	assert records[0] == ['a', 'b']
	assert records[1] == ['1', '2']
}

fn test_parse_csv_records_embedded_newline() {
	// A quoted field that contains a literal newline
	content := '"line1\nline2",b\nc,d\n'
	records := vsqlite.parse_csv_records(content, `,`)
	assert records.len == 2
	assert records[0][0] == 'line1\nline2'
	assert records[0][1] == 'b'
	assert records[1][0] == 'c'
	assert records[1][1] == 'd'
}

fn test_parse_csv_records_blank_lines_skipped() {
	records := vsqlite.parse_csv_records('a,b\n\n1,2\n\n', `,`)
	assert records.len == 2
}

fn test_parse_csv_records_no_trailing_newline() {
	records := vsqlite.parse_csv_records('a,b\n1,2', `,`)
	assert records.len == 2
	assert records[1] == ['1', '2']
}

fn test_parse_csv_records_tab_sep() {
	records := vsqlite.parse_csv_records("id\tname\n1\tAlice\n", `\t`)
	assert records.len == 2
	assert records[0] == ['id', 'name']
	assert records[1] == ['1', 'Alice']
}

fn test_parse_csv_line_sep_pipe() {
	assert vsqlite.parse_csv_line_sep('a|b|c', `|`) == ['a', 'b', 'c']
}

fn test_parse_csv_line_sep_tab() {
	assert vsqlite.parse_csv_line_sep('a\tb\tc', `\t`) == ['a', 'b', 'c']
}

fn test_read_csv_sep_tsv() {
	tmp := os.join_path(os.temp_dir(), 'vsqlite_test_tsv.tsv')
	os.write_file(tmp, "id\tname\n1\tAlice\n2\tBob\n") or { panic(err) }
	defer {
		os.rm(tmp) or {}
	}
	headers, rows := vsqlite.read_tsv(tmp) or { panic(err) }
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
	headers, rows := vsqlite.read_csv(tmp) or { panic(err) }
	assert headers == ['name', 'note']
	assert rows[0][1] == 'hello, world'
}
