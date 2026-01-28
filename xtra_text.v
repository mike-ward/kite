import arrays
import log
import time
import gui

const max_field_len = 35
const truncate_at = 20

fn truncate_long_fields(s string) string {
	return arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return match true {
			elem.len > max_field_len { elem[..truncate_at] + '...' }
			else { elem }
		}
	})
}

fn remove_control_chars(s string) string {
	mut result := []u8{cap: s.len}
	for c in s {
		// Keep printable ASCII, tab, newline, and all UTF-8 (>= 0x80)
		if c >= 0x20 || c == `\t` || c == `\n` || c >= 0x80 {
			result << c
		}
	}
	return result.bytestr()
}

fn sanitize_text(s string) string {
	return truncate_long_fields(remove_control_chars(s))
}

fn is_utf8_boundary(s string, idx int) bool {
	if idx <= 0 || idx >= s.len {
		return true
	}
	b := s[idx]
	// UTF-8 continuation bytes start with 10xxxxxx (0x80-0xBF)
	return b < 0x80 || b >= 0xC0
}

fn indexes_in_string(s string, start int, end int) bool {
	return end > 0 && end <= s.len && start >= 0 && start < end && is_utf8_boundary(s, start)
		&& is_utf8_boundary(s, end)
}

fn log_error(msg string, file_line string) {
	log.error('${time.now().hhmmss()} > ${file_line} > ${msg}')
}

fn change_font_size(delta f32, min_size int, max_size int, mut window gui.Window) {
	new_theme := gui.theme().adjust_font_size(delta, min_size, max_size) or {
		eprintln(err.msg())
		return
	}
	window.set_theme(new_theme)
}
