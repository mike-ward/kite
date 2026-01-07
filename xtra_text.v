import arrays
import log
import time
import gui

fn truncate_long_fields(s string) string {
	return arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return match true {
			elem.len > 35 { elem[..20] + '...' }
			else { elem }
		}
	})
}

fn sanitize_text(s string) string {
	return truncate_long_fields(s)
}

fn indexes_in_string(s string, start int, end int) bool {
	return end > 0 && end <= s.len && start >= 0 && start < end
}

fn log_error(msg string, file_line string) {
	log.error('${time.now().hhmmss()} > ${file_line} > ${msg}')
}

fn change_font_size(delta int, min_size int, max_size int, mut window gui.Window) {
	new_theme := gui.theme().adjust_font_size(delta, min_size, max_size) or {
		eprintln(err.msg())
		return
	}
	window.set_theme(new_theme)
}
