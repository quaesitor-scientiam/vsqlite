module vsqlite

import os

// read_csv reads a CSV file and returns rows as string arrays.
// The first row is treated as headers.
pub fn read_csv(path string) !([]string, [][]string) {
	content := os.read_file(path)!
	lines := content.split_into_lines()
	if lines.len == 0 {
		return error('CSV file is empty')
	}
	headers := parse_csv_line(lines[0])
	mut rows := [][]string{}
	for line in lines[1..] {
		trimmed := line.trim_space()
		if trimmed == '' {
			continue
		}
		rows << parse_csv_line(trimmed)
	}
	return headers, rows
}

// write_csv writes rows to a CSV file.
pub fn write_csv(path string, rows []Row, headers bool) ! {
	mut lines := []string{}
	if headers && rows.len > 0 {
		lines << rows[0].cols.map(csv_escape(it)).join(',')
	}
	for row in rows {
		lines << row.vals.map(csv_escape(it)).join(',')
	}
	os.write_file(path, lines.join('\n') + '\n')!
}

// csv_escape quotes a field for RFC 4180 CSV (comma separator).
pub fn csv_escape(s string) string {
	return csv_escape_sep(s, ',')
}

// csv_escape_sep quotes a field if it contains the separator, a double-quote, or a newline.
fn csv_escape_sep(s string, sep string) string {
	if s.contains(sep) || s.contains('"') || s.contains('\n') {
		return '"' + s.replace('"', '""') + '"'
	}
	return s
}

pub fn parse_csv_line(line string) []string {
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
