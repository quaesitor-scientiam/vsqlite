module main

import os
import vsqlite

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
  .quit / .exit / Ctrl+D           Exit'

struct App {
mut:
	db        vsqlite.DB
	mode      vsqlite.OutputMode = .table
	headers   bool               = true
	last_rows []vsqlite.Row
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

	mut app := App{
		db: vsqlite.connect(args[0]) or {
			eprintln('Error: cannot open "${args[0]}": ${err}')
			exit(1)
		}
	}

	if args.len == 1 {
		app.interactive_mode()
	} else if args[1] == '-f' {
		if args.len < 3 {
			eprintln('Error: -f requires a file path')
			exit(1)
		}
		app.exec_file(args[2])
	} else {
		app.run(args[1..].join(' '))
	}
}

fn (mut app App) interactive_mode() {
	println('vsqlite ${version} - Type .help for commands, .quit to exit')
	println('')
	for {
		print('vsqlite> ')
		flush_stdout()
		line := os.get_line()
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
		if trimmed.starts_with('.') {
			app.dot_cmd(trimmed)
		} else {
			app.run(trimmed)
		}
	}
	println('\nBye!')
}

fn (mut app App) run(stmt string) {
	upper := stmt.trim_space().to_upper()
	is_query := upper.starts_with('SELECT') || upper.starts_with('PRAGMA')
		|| upper.starts_with('EXPLAIN') || upper.starts_with('WITH')
		|| upper.starts_with('VALUES')

	if is_query {
		rows := app.db.exec(stmt) or {
			eprintln('Error: ${err}')
			return
		}
		if rows.len == 0 {
			return
		}
		app.last_rows = rows
		println(vsqlite.format(rows, app.mode, app.headers))
		println('(${rows.len} row${if rows.len == 1 { '' } else { 's' }})')
	} else {
		app.db.exec_none(stmt)
		affected := app.db.affected_rows()
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
		eprintln('Error reading "${path}": ${err}')
		exit(1)
	}
	mut count := 0
	for stmt in content.split(';') {
		trimmed := stmt.trim_space()
		if trimmed == '' || trimmed.starts_with('--') {
			continue
		}
		app.run(trimmed)
		count++
	}
	println('Executed ${count} statement(s) from ${path}')
}

fn (mut app App) dot_cmd(cmd string) {
	parts := cmd.split(' ').filter(it != '')
	match parts[0] {
		'.help' {
			println(help_text)
		}
		'.tables' {
			tables := app.db.tables()
			if tables.len == 0 {
				println('(no tables)')
			} else {
				println(tables.join('\n'))
			}
		}
		'.schema' {
			table := if parts.len > 1 { parts[1] } else { '' }
			result := app.db.schema(table)
			if result == '' {
				println('(no schema found)')
			} else {
				println(result)
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
			if app.last_rows.len == 0 {
				eprintln('No previous query results to export')
				return
			}
			vsqlite.write_csv(parts[1], app.last_rows, app.headers) or {
				eprintln('Error: ${err}')
				return
			}
			println('Exported ${app.last_rows.len} rows to ${parts[1]}')
		}
		'.databases' {
			rows := app.db.exec('PRAGMA database_list') or { return }
			for row in rows {
				println('${row.vals[1]}: ${row.vals[2]}')
			}
		}
		'.indexes' {
			filter := if parts.len > 1 { "AND tbl_name='${parts[1]}'" } else { '' }
			rows := app.db.exec("SELECT name, tbl_name FROM sqlite_master WHERE type='index' ${filter} ORDER BY tbl_name, name") or {
				return
			}
			if rows.len == 0 {
				println('(no indexes found)')
			} else {
				for row in rows {
					println('${row.vals[1]}.${row.vals[0]}')
				}
			}
		}
		'.size' {
			println('Database size: ${format_bytes(app.db.size())}')
		}
		else {
			eprintln('Unknown command: ${parts[0]}. Type .help for help.')
		}
	}
}

fn (mut app App) import_csv(file string, table string) {
	headers, rows := vsqlite.read_csv(file) or {
		eprintln('Error: ${err}')
		return
	}
	col_list := headers.join(',')
	app.db.exec_none('BEGIN TRANSACTION')
	for vals in rows {
		quoted := vals.map("'${it.replace("'", "''")}'")
		app.db.exec_none('INSERT INTO ${table} (${col_list}) VALUES (${quoted.join(",")})')
	}
	app.db.exec_none('COMMIT')
	println('Imported ${rows.len} rows into ${table}')
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
