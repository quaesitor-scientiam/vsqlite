module main

import os
import readline
import time
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
  .mode [table|csv|line|box|       Change output mode (default: table)
        markdown|json|html|
        insert [tbl]|quote]
  .headers [on|off]                Toggle column headers
  .nullvalue [str]                 Set NULL display string (default: NULL)
  .separator [sep]                 Set column separator (default: ,)
  .width [N1 N2 ...]               Set per-column widths (0 = reset to auto)
  .output [file|-]                 Redirect output to file (no arg = stdout)
  .once <file>                     Redirect next query result to file
  .timer [on|off]                  Toggle query execution timing (default: off)
  .explain <stmt>                  Show EXPLAIN QUERY PLAN tree for a statement
  .import <file> <table>           Import CSV/TSV into table (auto-detects .tsv/.tab)
  .export <file>                   Export last query to CSV
  .dump [file]                     Dump full SQL schema+data to stdout or file
  .load <file> [entry]             Load a SQLite extension (.so/.dylib)
  .bail [on|off]                   Stop on first error (default: off)
  .echo [on|off]                   Echo each statement before executing (default: off)
  .log [file|off]                  Log all statements to a file; off to disable
  .changes [on|off]                Show row-change count after each statement (default: off)
  .open <file>                     Open (or switch to) a different database file
  .databases                       List attached databases
  .indexes [table]                 List indexes
  .size                            Show database file size
  .quit / .exit / Ctrl+D           Exit'

const history_file = os.join_path(os.home_dir(), '.vsqlite_history')

struct App {
mut:
	db           vsqlite.DB
	rl           readline.Readline
	mode         vsqlite.OutputMode = .table
	headers      bool               = true
	last_rows    []vsqlite.Row
	nullvalue    string             = 'NULL'
	separator    string             = ','
	col_widths   map[int]int
	output_path  string // '' = stdout; non-empty = path to write query results
	output_once  bool   // if true, reset output_path after the next query result
	insert_table string = 'tbl'
	timer        bool   // if true, print execution time after each statement
	bail         bool   // if true, exit(1) on first SQL error
	echo         bool   // if true, print each statement before executing
	log_path     string // '' = logging off; non-empty = path to append statements
	changes      bool   // if true, print row-change count after each DML
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
	app.rl.skip_empty = true
	app.load_history()
	app.refresh_completions()
	mut buf := []string{}
	for {
		prompt := if buf.len == 0 { 'vsqlite> ' } else { '     ...> ' }
		line := app.rl.read_line(prompt) or {
			if buf.len > 0 {
				eprintln('Incomplete statement discarded.')
			}
			break
		} // EOF / Ctrl+D
		trimmed := line.trim_space()
		if trimmed == '' {
			continue
		}
		// Dot commands and exit keywords need no semicolon — execute immediately
		if buf.len == 0 {
			if trimmed in ['.quit', '.exit', 'quit', 'exit'] {
				break
			}
			if trimmed.starts_with('.') {
				app.dot_cmd(trimmed)
				continue
			}
		}
		buf << line
		if stmt_complete(buf) {
			full := buf.join('\n').trim_space()
			for s in split_statements(full) {
				if s != '' {
					app.run(s)
				}
			}
			buf = []string{}
		}
	}
	app.save_history()
	println('\nBye!')
}

// stmt_complete reports whether the lines accumulated so far form a complete
// SQL statement, i.e. the joined text ends with a semicolon.
fn stmt_complete(lines []string) bool {
	return lines.join('\n').trim_space().ends_with(';')
}

fn (mut app App) load_history() {
	history_load(mut app.rl, history_file)
}

fn (app App) save_history() {
	history_save(app.rl, history_file)
}

fn history_load(mut rl readline.Readline, path string) {
	content := os.read_file(path) or { return }
	for line in content.split('\n') {
		if line.len > 0 {
			rl.previous_lines << line.runes()
		}
	}
}

fn history_save(rl readline.Readline, path string) {
	lines := rl.previous_lines.map(it.string()).filter(it.len > 0)
	os.write_file(path, lines.join('\n') + '\n') or {}
}

// make_format_opts builds a FormatOptions from the current App settings.
fn (app App) make_format_opts() vsqlite.FormatOptions {
	return vsqlite.FormatOptions{
		mode:       app.mode
		headers:    app.headers
		nullvalue:  app.nullvalue
		separator:  app.separator
		col_widths: app.col_widths
		table_name: app.insert_table
	}
}

// write_out writes s to the configured output destination (file or stdout).
// Does NOT reset output_once — call finish_output() after the full result.
fn (mut app App) write_out(s string) {
	if app.output_path != '' {
		os.write_file(app.output_path, os.read_file(app.output_path) or { '' } + s + '\n') or {
			eprintln('Error: cannot write to "${app.output_path}": ${err}')
		}
	} else {
		println(s)
	}
}

// finish_output resets output_once after a full query result has been written.
fn (mut app App) finish_output() {
	if app.output_once {
		app.output_path = ''
		app.output_once = false
	}
}

// log_stmt appends stmt to the log file when logging is enabled.
fn (mut app App) log_stmt(stmt string) {
	if app.log_path == '' {
		return
	}
	existing := os.read_file(app.log_path) or { '' }
	os.write_file(app.log_path, existing + stmt + ';\n') or {}
}

fn (mut app App) run(stmt string) bool {
	if app.echo {
		println(stmt)
	}
	app.log_stmt(stmt)
	upper := stmt.trim_space().to_upper()
	is_query := upper.starts_with('SELECT') || upper.starts_with('PRAGMA')
		|| upper.starts_with('EXPLAIN') || upper.starts_with('WITH')
		|| upper.starts_with('VALUES')

	t0 := time.now()

	if is_query {
		rows := app.db.exec(stmt) or {
			eprintln('Error: ${err}')
			if app.bail {
				exit(1)
			}
			return false
		}
		elapsed := time.since(t0)
		if rows.len == 0 {
			app.finish_output()
			if app.timer {
				println('Run time: ${format_duration(elapsed)}')
			}
			return true
		}
		app.last_rows = rows
		app.write_out(vsqlite.format_opts(rows, app.make_format_opts()))
		app.write_out('(${rows.len} row${if rows.len == 1 { '' } else { 's' }})')
		app.finish_output()
		if app.timer {
			println('Run time: ${format_duration(elapsed)}')
		}
	} else {
		app.db.exec_none(stmt)
		elapsed := time.since(t0)
		affected := app.db.affected_rows()
		last_id := app.db.last_insert_rowid()
		if upper.starts_with('INSERT') {
			println('Inserted 1 row (rowid: ${last_id})')
		} else if upper.starts_with('UPDATE') || upper.starts_with('DELETE') {
			println('${affected} row${if affected == 1 { '' } else { 's' }} affected')
		} else {
			println('OK')
		}
		if app.changes {
			println('Changes: ${affected}')
		}
		if app.timer {
			println('Run time: ${format_duration(elapsed)}')
		}
		// Schema may have changed — rebuild completions.
		if upper.starts_with('CREATE') || upper.starts_with('DROP')
			|| upper.starts_with('ALTER') {
			app.refresh_completions()
		}
	}
	return true
}

fn (mut app App) exec_file(path string) {
	content := os.read_file(path) or {
		eprintln('Error reading "${path}": ${err}')
		exit(1)
	}
	mut count := 0
	for stmt in split_statements(content) {
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
				'table'    { app.mode = .table }
				'csv'      { app.mode = .csv }
				'line'     { app.mode = .line }
				'box'      { app.mode = .box }
				'markdown' { app.mode = .markdown }
				'json'     { app.mode = .json }
				'html'     { app.mode = .html }
				'insert'   {
					app.mode = .insert
					if parts.len > 2 {
						app.insert_table = parts[2]
					}
				}
				'quote'    { app.mode = .quote }
				else {
					eprintln('Unknown mode: ${parts[1]}. Use: table, csv, line, box, markdown, json, html, insert [tbl], quote')
					return
				}
			}
			println('Mode set to: ${app.mode}')
		}
		'.headers' {
			if parts.len < 2 {
				println('Headers: ${if app.headers { "on" } else { "off" }}')
				return
			}
			match parts[1] {
				'on'  { app.headers = true }
				'off' { app.headers = false }
				else  { eprintln('Use: .headers on|off') }
			}
		}
		'.nullvalue' {
			if parts.len < 2 {
				println('NULL display: "${app.nullvalue}"')
				return
			}
			app.nullvalue = parts[1]
			println('NULL value set to "${app.nullvalue}"')
		}
		'.separator' {
			if parts.len < 2 {
				println('Separator: "${app.separator}"')
				return
			}
			mut sep := parts[1]
			sep = sep.replace('\\t', '\t').replace('\\n', '\n')
			app.separator = sep
			println('Separator set to "${app.separator}"')
		}
		'.width' {
			if parts.len < 2 {
				if app.col_widths.len == 0 {
					println('Column widths: auto')
				} else {
					mut pairs := []string{}
					for k, v in app.col_widths {
						pairs << 'col${k}=${v}'
					}
					println('Column widths: ${pairs.join(", ")}')
				}
				return
			}
			// Single '0' resets all widths to auto
			if parts.len == 2 && parts[1] == '0' {
				app.col_widths = map[int]int{}
				println('Column widths reset to auto')
				return
			}
			app.col_widths = map[int]int{}
			for i, part in parts[1..] {
				w := part.int()
				if w > 0 {
					app.col_widths[i] = w
				}
			}
			println('Column widths set')
		}
		'.output' {
			if parts.len < 2 || parts[1] in ['stdout', '-'] {
				app.output_path = ''
				app.output_once = false
				println('Output reset to stdout')
			} else {
				// Truncate/create the file fresh
				os.write_file(parts[1], '') or {
					eprintln('Error: cannot open "${parts[1]}": ${err}')
					return
				}
				app.output_path = parts[1]
				app.output_once = false
				println('Output redirected to ${parts[1]}')
			}
		}
		'.once' {
			if parts.len < 2 {
				eprintln('Usage: .once <file>')
				return
			}
			os.write_file(parts[1], '') or {
				eprintln('Error: cannot open "${parts[1]}": ${err}')
				return
			}
			app.output_path = parts[1]
			app.output_once = true
		}
		'.timer' {
			if parts.len < 2 {
				println('Timer: ${if app.timer { "on" } else { "off" }}')
				return
			}
			match parts[1] {
				'on' {
					app.timer = true
					println('Timer: on')
				}
				'off' {
					app.timer = false
					println('Timer: off')
				}
				else {
					eprintln('Use: .timer on|off')
				}
			}
		}
		'.explain' {
			if parts.len < 2 {
				eprintln('Usage: .explain <sql statement>')
				return
			}
			stmt := parts[1..].join(' ')
			app.run_explain(stmt)
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
		'.dump' {
			text := app.db.dump()
			if parts.len > 1 {
				os.write_file(parts[1], text) or {
					eprintln('Error: cannot write "${parts[1]}": ${err}')
					return
				}
				println('Dumped to ${parts[1]}')
			} else {
				println(text)
			}
		}
		'.load' {
			if parts.len < 2 {
				eprintln('Usage: .load <file> [entry-point]')
				return
			}
			entry := if parts.len > 2 { parts[2] } else { '' }
			app.db.load_extension(parts[1], entry) or {
				eprintln('Error: ${err}')
				return
			}
			println('Extension loaded: ${parts[1]}')
		}
		'.bail' {
			if parts.len < 2 {
				println('Bail: ${if app.bail { "on" } else { "off" }}')
				return
			}
			match parts[1] {
				'on'  { app.bail = true;  println('Bail: on') }
				'off' { app.bail = false; println('Bail: off') }
				else  { eprintln('Use: .bail on|off') }
			}
		}
		'.echo' {
			if parts.len < 2 {
				println('Echo: ${if app.echo { "on" } else { "off" }}')
				return
			}
			match parts[1] {
				'on'  { app.echo = true;  println('Echo: on') }
				'off' { app.echo = false; println('Echo: off') }
				else  { eprintln('Use: .echo on|off') }
			}
		}
		'.log' {
			if parts.len < 2 {
				if app.log_path == '' {
					println('Log: off')
				} else {
					println('Log: ${app.log_path}')
				}
				return
			}
			if parts[1] == 'off' {
				app.log_path = ''
				println('Logging off')
			} else {
				app.log_path = parts[1]
				println('Logging to ${app.log_path}')
			}
		}
		'.changes' {
			if parts.len < 2 {
				println('Changes: ${if app.changes { "on" } else { "off" }}')
				return
			}
			match parts[1] {
				'on'  { app.changes = true;  println('Changes: on') }
				'off' { app.changes = false; println('Changes: off') }
				else  { eprintln('Use: .changes on|off') }
			}
		}
		'.open' {
			if parts.len < 2 {
				eprintln('Usage: .open <database-file>')
				return
			}
			new_db := vsqlite.connect(parts[1]) or {
				eprintln('Error: cannot open "${parts[1]}": ${err}')
				return
			}
			app.db = new_db
			app.refresh_completions()
			println('Opened ${parts[1]}')
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
	// Auto-detect separator: .tsv and .tab files use tab; everything else uses comma
	sep := if file.ends_with('.tsv') || file.ends_with('.tab') { u8(`\t`) } else { u8(`,`) }
	headers, rows := vsqlite.read_csv_sep(file, sep) or {
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

// refresh_completions rebuilds the readline completion callback from the
// current schema.  Call once at startup and again after any DDL statement.
fn (mut app App) refresh_completions() {
	dot_cmds := ['.tables', '.schema', '.mode', '.headers', '.nullvalue', '.separator',
		'.width', '.output', '.once', '.timer', '.explain', '.import', '.export',
		'.dump', '.load', '.bail', '.echo', '.log', '.changes', '.open',
		'.databases', '.indexes', '.size', '.help', '.quit', '.exit']
	kws := ['SELECT', 'FROM', 'WHERE', 'INSERT', 'INTO', 'UPDATE', 'SET', 'DELETE',
		'CREATE', 'TABLE', 'DROP', 'ALTER', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER',
		'ON', 'ORDER', 'BY', 'GROUP', 'HAVING', 'LIMIT', 'OFFSET', 'AND', 'OR', 'NOT',
		'NULL', 'VALUES', 'PRIMARY', 'KEY', 'INTEGER', 'TEXT', 'REAL', 'BLOB', 'UNIQUE',
		'DEFAULT', 'AUTOINCREMENT', 'PRAGMA', 'INDEX', 'DISTINCT', 'COUNT', 'SUM', 'MIN',
		'MAX', 'AVG', 'AS', 'LIKE', 'IN', 'IS', 'BETWEEN', 'CASE', 'WHEN', 'THEN',
		'ELSE', 'END', 'BEGIN', 'TRANSACTION', 'COMMIT', 'ROLLBACK']
	mut words := []string{}
	words << dot_cmds
	words << kws
	tables := app.db.tables()
	words << tables
	for t in tables {
		words << app.db.columns(t)
	}
	app.rl.completion_callback = make_completer(words)
}

// make_completer returns a readline completion_callback that completes the
// last SQL token on the current line against words.
// Because readline replaces r.current with the returned string, each result
// is the full line with the matched word substituted for the last token.
fn make_completer(words []string) fn (string) []string {
	return fn [words](line string) []string {
		if line.len == 0 {
			return []string{}
		}
		// Dot command (no space yet): complete the whole command name.
		if line.starts_with('.') && !line.contains(' ') {
			return words.filter(it.starts_with(line))
		}
		// Split off the last token so we can replace it with completions.
		tok_start := last_token_start(line)
		pre := line[..tok_start]
		tok := line[tok_start..]
		if tok.len == 0 {
			return []string{}
		}
		tok_upper := tok.to_upper()
		mut results := []string{}
		for w in words {
			if w.to_upper().starts_with(tok_upper) {
				results << pre + w
			}
		}
		return results
	}
}

// last_token_start returns the byte offset in line where the last SQL token
// begins.  Tokens are delimited by spaces, tabs, '(' and ','.
fn last_token_start(line string) int {
	for i := line.len - 1; i >= 0; i-- {
		b := line[i]
		if b == 32 || b == 9 || b == 40 || b == 44 { // ' '  '\t'  '('  ','
			return i + 1
		}
	}
	return 0
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

// format_duration renders a time.Duration as a human-readable string.
fn format_duration(d time.Duration) string {
	us := d.microseconds()
	if us < 1000 {
		return '${us} µs'
	}
	ms := us / 1000
	frac := us % 1000
	frac_str := if frac < 10 {
		'00${frac}'
	} else if frac < 100 {
		'0${frac}'
	} else {
		'${frac}'
	}
	return '${ms}.${frac_str} ms'
}

// split_statements splits a SQL string on semicolons while respecting single-
// and double-quoted strings.  Each returned statement has its trailing
// semicolon removed and is not empty.
fn split_statements(src string) []string {
	mut stmts := []string{}
	mut start := 0
	mut in_single := false
	mut in_double := false
	for i := 0; i < src.len; i++ {
		c := src[i]
		if c == `'` && !in_double {
			in_single = !in_single
		} else if c == `"` && !in_single {
			in_double = !in_double
		} else if c == `;` && !in_single && !in_double {
			s := src[start..i].trim_space()
			if s != '' {
				stmts << s
			}
			start = i + 1
		}
	}
	// Any trailing text after the last semicolon (or the whole input if no `;`).
	s := src[start..].trim_space()
	if s != '' {
		stmts << s
	}
	return stmts
}

// run_explain runs EXPLAIN QUERY PLAN on stmt and renders the result as a tree.
fn (mut app App) run_explain(stmt string) {
	rows := app.db.exec('EXPLAIN QUERY PLAN ${stmt}') or {
		eprintln('Error: ${err}')
		return
	}
	if rows.len == 0 {
		println('(no query plan)')
		return
	}
	println('QUERY PLAN')
	app.print_eqp_tree(rows, 0, 0)
}

// print_eqp_tree recursively prints EXPLAIN QUERY PLAN rows as an indented tree.
// EXPLAIN QUERY PLAN columns (by index): 0=id, 1=parent, 2=notused, 3=detail
fn (mut app App) print_eqp_tree(rows []vsqlite.Row, parent_id int, depth int) {
	indent := '  '.repeat(depth)
	for row in rows {
		if row.vals.len < 4 {
			continue
		}
		if row.vals[1].int() == parent_id {
			println('${indent}|--${row.vals[3]}')
			app.print_eqp_tree(rows, row.vals[0].int(), depth + 1)
		}
	}
}
