module vsqlite

import term

pub enum OutputMode {
	table
	csv
	line
}

// format renders rows in the given output mode.
// Set headers to include column name headers in the output.
pub fn format(rows []Row, mode OutputMode, headers bool) string {
	return match mode {
		.table { format_table(rows, headers) }
		.csv { format_csv(rows, headers) }
		.line { format_line(rows) }
	}
}

// format_table renders rows as an ASCII table with optional bold headers.
pub fn format_table(rows []Row, headers bool) string {
	if rows.len == 0 {
		return ''
	}
	ncols := rows[0].vals.len
	cols := resolve_cols(rows[0].cols, ncols)

	mut widths := []int{len: ncols, init: cols[index].len}
	for row in rows {
		for i, val in row.vals {
			if i < ncols {
				v := null_str(val)
				if v.len > widths[i] {
					widths[i] = v.len
				}
			}
		}
	}

	mut sep := '+'
	for w in widths {
		sep += '-'.repeat(w + 2) + '+'
	}

	mut out := ''

	if headers {
		out += sep + '\n'
		mut header := '|'
		for i, col in cols {
			header += ' ' + term.bold(str_pad(col.limit(widths[i]), widths[i])) + ' |'
		}
		out += header + '\n'
	}
	out += sep + '\n'

	for row in rows {
		mut line := '|'
		for i, val in row.vals {
			if i >= ncols {
				break
			}
			line += ' ' + str_pad(null_str(val).limit(widths[i]), widths[i]) + ' |'
		}
		out += line + '\n'
	}
	out += sep
	return out
}

// format_csv renders rows as RFC 4180 CSV.
pub fn format_csv(rows []Row, headers bool) string {
	if rows.len == 0 {
		return ''
	}
	ncols := rows[0].vals.len
	cols := resolve_cols(rows[0].cols, ncols)

	mut lines := []string{}
	if headers {
		lines << cols.map(csv_escape(it)).join(',')
	}
	for row in rows {
		lines << row.vals.map(csv_escape(it)).join(',')
	}
	return lines.join('\n')
}

// format_line renders each column on its own line, aligned by column name width.
pub fn format_line(rows []Row) string {
	if rows.len == 0 {
		return ''
	}
	ncols := rows[0].vals.len
	cols := resolve_cols(rows[0].cols, ncols)

	mut max_len := 0
	for col in cols {
		if col.len > max_len {
			max_len = col.len
		}
	}

	mut blocks := []string{}
	for row in rows {
		mut lines := []string{}
		for j, val in row.vals {
			if j >= ncols {
				break
			}
			lines << '${str_pad_left(cols[j], max_len)}: ${null_str(val)}'
		}
		blocks << lines.join('\n')
	}
	return blocks.join('\n\n')
}

fn null_str(s string) string {
	return if s == '' { 'NULL' } else { s }
}

fn resolve_cols(cols []string, ncols int) []string {
	if cols.len == ncols {
		return cols
	}
	mut generated := []string{cap: ncols}
	for i in 0 .. ncols {
		generated << 'col${i}'
	}
	return generated
}

fn str_pad(s string, w int) string {
	if s.len >= w {
		return s
	}
	return s + ' '.repeat(w - s.len)
}

fn str_pad_left(s string, w int) string {
	if s.len >= w {
		return s
	}
	return ' '.repeat(w - s.len) + s
}
