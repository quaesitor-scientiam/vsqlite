module main

import db.sqlite
import os
import term

const version = '0.1.0'

const help_text = 'vsqlite ${version} - SQLite CLI written in V

Usage:
  vsqlite <database>               Open database in interactive mode
  vsqlite <database> <stmt>        Execute a single SQL statement
  vsqlite <database> -f <file>     Execute SQL from a file
  vsqlite --help                   Show this help
  vsqlite --version                Show version

Interactive mode commands:
  .tables                          List all tables
  .schema [table]                  Show schema for table(s)
  .mode [table|csv|line]           Change output mode (default: table)
  .headers [on|off]                Toggle column headers
  .import <file> <table>           Import CSV into table
  .export <file>                   Export last query to CSV
  .databases                       List attached databases
  .indexes [table]                 List indexes
  .size                            Show database file size
  .quit / .exit / Ctrl+D           Exit

Examples:
  vsqlite mydb.sqlite
  vsqlite mydb.sqlite "SELECT * FROM users LIMIT 10"
  vsqlite mydb.sqlite -f queries.sql'

enum OutputMode {
	table
	csv
	line
}

struct App {
mut:
	db        sqlite.DB
	mode      OutputMode = .table
	headers   bool       = true
	last_rows []sqlite.Row
	last_cols []string
}

fn main() {
	args := os.args[1..]

	if args.len == 0 || args[0] in ['--help', '-h'] {
		println(help_text)
		return
	}

	if args[0] in ['--version', '-v'] {
		println('vsqlite ${version}')
		return
	}

	db_path := args[0]
	db := sqlite.connect(db_path) or {
		eprintln('Error: cannot open database "${db_path}": ${err}')
		exit(1)
	}

	mut app := App{
		db: db
	}

	app.db.exec_none('PRAGMA journal_mode=WAL')
	app.db.exec_none('PRAGMA foreign_keys=ON')

	if args.len == 1 {
		app.interactive_mode()
	} else if args[1] == '-f' {
		if args.len < 3 {
			eprintln('Error: -f requires a file path')
			exit(1)
		}
		app.exec_file(args[2])
	} else {
		app.exec_query(args[1..].join(' '))
	}
}

fn (mut app App) interactive_mode() {
	println('vsqlite ${version} - Type .help for commands, .quit to exit')
	println('')

	for {
		print('vsqlite> ')
		flush_stdout()
		line := os.get_line()
		// EOF / Ctrl+D
		if line == '' {
			break
		}
		trimmed := line.trim_space()
		if trimmed == '' {
			continue
		}
		if trimmed in ['.quit', '.exit', 'quit', 'exit'] {
			break
		}
		app.handle_input(trimmed)
	}

	println('\nBye!')
}

fn (mut app App) handle_input(input string) {
	if input.starts_with('.') {
		app.handle_dot_command(input)
	} else {
		app.exec_query(input)
	}
}

fn (mut app App) handle_dot_command(cmd string) {
	parts := cmd.split(' ').filter(it != '')
	match parts[0] {
		'.help' {
			println(help_text)
		}
		'.tables' {
			rows := app.db.exec("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name") or {
				eprintln('Error: ${err}')
				return
			}
			if rows.len == 0 {
				println('(no tables)')
				return
			}
			for row in rows {
				println(row.vals[0])
			}
		}
		'.schema' {
			filter := if parts.len > 1 { "AND name='${parts[1]}'" } else { '' }
			rows := app.db.exec("SELECT sql FROM sqlite_master WHERE type IN ('table','index','view','trigger') ${filter} ORDER BY type,name") or {
				eprintln('Error: ${err}')
				return
			}
			if rows.len == 0 {
				println('(no schema found)')
				return
			}
			for row in rows {
				if row.vals[0] != '' {
					println(row.vals[0])
					println('')
				}
			}
		}
		'.mode' {
			if parts.len < 2 {
				println('Current mode: ${app.mode}')
				return
			}
			match parts[1] {
				'table' { app.mode = .table }
				'csv' { app.mode = .csv }
				'line' { app.mode = .line }
				else { eprintln('Unknown mode: ${parts[1]}. Use: table, csv, line') }
			}
			println('Mode set to: ${app.mode}')
		}
		'.headers' {
			if parts.len < 2 {
				println('Headers: ${if app.headers { "on" } else { "off" }}')
				return
			}
			match parts[1] {
				'on' { app.headers = true }
				'off' { app.headers = false }
				else { eprintln('Use: .headers on|off') }
			}
		}
		'.import' {
			if parts.len < 3 {
				eprintln('Usage: .import <file> <table>')
				return
			}
			app.import_csv(parts[1], parts[2])
		}
		'.export' {
			if parts.len < 2 {
				eprintln('Usage: .export <file>')
				return
			}
			app.export_csv(parts[1])
		}
		'.databases' {
			rows := app.db.exec('PRAGMA database_list') or {
				eprintln('Error: ${err}')
				return
			}
			for row in rows {
				println('${row.vals[1]}: ${row.vals[2]}')
			}
		}
		'.indexes' {
			filter := if parts.len > 1 { "AND tbl_name='${parts[1]}'" } else { '' }
			rows := app.db.exec("SELECT name, tbl_name FROM sqlite_master WHERE type='index' ${filter} ORDER BY tbl_name, name") or {
				eprintln('Error: ${err}')
				return
			}
			if rows.len == 0 {
				println('(no indexes found)')
				return
			}
			for row in rows {
				println('${row.vals[1]}.${row.vals[0]}')
			}
		}
		'.size' {
			rows_pc := app.db.exec('PRAGMA page_count') or { return }
			rows_ps := app.db.exec('PRAGMA page_size') or { return }
			if rows_pc.len > 0 && rows_ps.len > 0 {
				pages := rows_pc[0].vals[0].i64()
				page_size := rows_ps[0].vals[0].i64()
				println('Database size: ${format_bytes(pages * page_size)}')
			}
		}
		else {
			eprintln('Unknown command: ${parts[0]}. Type .help for help.')
		}
	}
}

fn (mut app App) exec_query(stmt string) {
	upper := stmt.trim_space().to_upper()
	is_select := upper.starts_with('SELECT') || upper.starts_with('PRAGMA')
		|| upper.starts_with('EXPLAIN') || upper.starts_with('WITH')
		|| upper.starts_with('VALUES')

	if is_select {
		rows := app.db.exec(stmt) or {
			eprintln('Error: ${err}')
			return
		}
		if rows.len == 0 {
			return
		}

		col_names := extract_column_names(app.db, stmt)
		app.last_rows = rows
		app.last_cols = col_names

		app.print_rows(rows, col_names)
		println('(${rows.len} row${if rows.len == 1 { '' } else { 's' }})')
	} else {
		app.db.exec_none(stmt)
		affected := app.db.get_affected_rows_count()
		last_id := app.db.last_insert_rowid()
		if upper.starts_with('INSERT') {
			println('Inserted 1 row (rowid: ${last_id})')
		} else if upper.starts_with('UPDATE') || upper.starts_with('DELETE') {
			println('${affected} row${if affected == 1 { '' } else { 's' }} affected')
		} else {
			println('OK')
		}
	}
}

fn (mut app App) exec_file(path string) {
	content := os.read_file(path) or {
		eprintln('Error reading file "${path}": ${err}')
		exit(1)
	}
	stmts := content.split(';')
	mut count := 0
	for stmt in stmts {
		trimmed := stmt.trim_space()
		if trimmed == '' || trimmed.starts_with('--') {
			continue
		}
		app.exec_query(trimmed)
		count++
	}
	println('Executed ${count} statement(s) from ${path}')
}

fn (mut app App) print_rows(rows []sqlite.Row, col_names []string) {
	match app.mode {
		.table { app.print_table(rows, col_names) }
		.csv { app.print_csv(rows, col_names) }
		.line { app.print_line(rows, col_names) }
	}
}

fn (mut app App) print_table(rows []sqlite.Row, col_names []string) {
	if rows.len == 0 {
		return
	}
	ncols := rows[0].vals.len

	cols := resolve_cols(col_names, ncols)

	// Compute column widths
	mut widths := []int{len: ncols, init: cols[index].len}
	for row in rows {
		for i, val in row.vals {
			if i < ncols {
				v := if val == '' { 'NULL' } else { val }
				if v.len > widths[i] {
					widths[i] = v.len
				}
			}
		}
	}

	// Build separator line
	mut sep := '+'
	for w in widths {
		sep += '-'.repeat(w + 2) + '+'
	}

	if app.headers {
		println(sep)
		mut header := '|'
		for i, col in cols {
			header += ' ' + term.bold(str_pad(col.limit(widths[i]), widths[i])) + ' |'
		}
		println(header)
	}
	println(sep)

	for row in rows {
		mut line_out := '|'
		for i, val in row.vals {
			if i >= ncols {
				break
			}
			v := if val == '' { 'NULL' } else { val }
			line_out += ' ' + str_pad(v.limit(widths[i]), widths[i]) + ' |'
		}
		println(line_out)
	}
	println(sep)
}

fn (mut app App) print_csv(rows []sqlite.Row, col_names []string) {
	if rows.len == 0 {
		return
	}
	ncols := rows[0].vals.len
	cols := resolve_cols(col_names, ncols)

	if app.headers {
		println(cols.map(csv_escape(it)).join(','))
	}
	for row in rows {
		println(row.vals.map(csv_escape(it)).join(','))
	}
}

fn (mut app App) print_line(rows []sqlite.Row, col_names []string) {
	if rows.len == 0 {
		return
	}
	ncols := rows[0].vals.len
	cols := resolve_cols(col_names, ncols)

	mut max_col_len := 0
	for col in cols {
		if col.len > max_col_len {
			max_col_len = col.len
		}
	}

	for i, row in rows {
		if i > 0 {
			println('')
		}
		for j, val in row.vals {
			if j >= ncols {
				break
			}
			v := if val == '' { 'NULL' } else { val }
			println('${str_pad_left(cols[j], max_col_len)}: ${v}')
		}
	}
}

fn (mut app App) import_csv(file string, table string) {
	content := os.read_file(file) or {
		eprintln('Error reading file "${file}": ${err}')
		return
	}
	lines := content.split_into_lines()
	if lines.len == 0 {
		eprintln('Error: file is empty')
		return
	}

	headers := parse_csv_line(lines[0])
	col_list := headers.join(',')

	mut count := 0
	app.db.exec_none('BEGIN TRANSACTION')
	for line in lines[1..] {
		trimmed := line.trim_space()
		if trimmed == '' {
			continue
		}
		vals := parse_csv_line(trimmed)
		quoted := vals.map("'${it.replace("'", "''")}'")
		insert_stmt := 'INSERT INTO ${table} (${col_list}) VALUES (${quoted.join(",")})'
		app.db.exec_none(insert_stmt)
		count++
	}
	app.db.exec_none('COMMIT')
	println('Imported ${count} rows into ${table}')
}

fn (mut app App) export_csv(file string) {
	if app.last_rows.len == 0 {
		eprintln('No previous query results to export')
		return
	}
	mut lines := []string{}
	if app.headers && app.last_cols.len > 0 {
		lines << app.last_cols.map(csv_escape(it)).join(',')
	}
	for row in app.last_rows {
		lines << row.vals.map(csv_escape(it)).join(',')
	}
	os.write_file(file, lines.join('\n') + '\n') or {
		eprintln('Error writing file "${file}": ${err}')
		return
	}
	println('Exported ${app.last_rows.len} rows to ${file}')
}

// Extract column names by parsing the SELECT clause
fn extract_column_names(db sqlite.DB, stmt string) []string {
	upper := stmt.trim_space().to_upper()
	if !upper.starts_with('SELECT') {
		return []string{}
	}

	from_idx := upper.index(' FROM ') or { return []string{} }
	select_part := stmt[7..from_idx].trim_space()

	if select_part == '*' || select_part.contains('*') {
		// Fall back to PRAGMA table_info if we can parse the table name
		table_name := extract_table_name(upper)
		if table_name != '' {
			rows := db.exec('PRAGMA table_info(${table_name})') or { return []string{} }
			return rows.map(it.vals[1])
		}
		return []string{}
	}

	raw_cols := select_part.split(',')
	mut cols := []string{}
	for col in raw_cols {
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
			dot_parts := trimmed.split('.')
			cols << dot_parts.last().trim_space()
			continue
		}
		cols << trimmed
	}
	return cols
}

fn extract_table_name(upper_stmt string) string {
	from_idx := upper_stmt.index(' FROM ') or { return '' }
	after_from := upper_stmt[from_idx + 6..].trim_space()
	// Take first token (stop at space, comma, paren, semicolon)
	end := after_from.index_any(' ,();')
	if end < 0 {
		return after_from.to_lower()
	}
	return after_from[..end].to_lower()
}

// Returns col_names if length matches ncols, else generates generic names
fn resolve_cols(col_names []string, ncols int) []string {
	if col_names.len == ncols {
		return col_names
	}
	mut generated := []string{cap: ncols}
	for i in 0 .. ncols {
		generated << 'col${i}'
	}
	return generated
}

// Pad string s to width w with spaces on the right
fn str_pad(s string, w int) string {
	if s.len >= w {
		return s
	}
	return s + ' '.repeat(w - s.len)
}

// Pad string s to width w with spaces on the left
fn str_pad_left(s string, w int) string {
	if s.len >= w {
		return s
	}
	return ' '.repeat(w - s.len) + s
}

fn csv_escape(s string) string {
	if s.contains(',') || s.contains('"') || s.contains('\n') {
		return '"' + s.replace('"', '""') + '"'
	}
	return s
}

fn parse_csv_line(line string) []string {
	mut fields := []string{}
	mut field := ''
	mut in_quotes := false
	mut i := 0
	bytes := line.bytes()
	for i < bytes.len {
		c := bytes[i]
		if in_quotes {
			if c == `"` {
				if i + 1 < bytes.len && bytes[i + 1] == `"` {
					field += '"'
					i += 2
					continue
				} else {
					in_quotes = false
				}
			} else {
				field += c.ascii_str()
			}
		} else {
			if c == `"` {
				in_quotes = true
			} else if c == `,` {
				fields << field
				field = ''
			} else {
				field += c.ascii_str()
			}
		}
		i++
	}
	fields << field
	return fields
}

fn format_bytes(n i64) string {
	if n < 1024 {
		return '${n} B'
	} else if n < 1024 * 1024 {
		return '${n / 1024} KB'
	} else if n < 1024 * 1024 * 1024 {
		return '${n / (1024 * 1024)} MB'
	} else {
		return '${n / (1024 * 1024 * 1024)} GB'
	}
}
