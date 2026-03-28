module main

import os
import readline

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
