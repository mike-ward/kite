import arrays
import log
import time
import gui

fn create_system_font_theme() gui.Theme {
	return gui.theme_maker(gui.ThemeCfg{
		...gui.theme_dark_bordered_cfg
		text_style: gui.TextStyle{
			...gui.theme_dark_bordered_cfg.text_style
			family: '' // blank means use system font family
		}
	})
}

fn truncate_long_fields(s string) string {
	return arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return match true {
			elem.len > 35 { elem[..20] + '...' }
			else { elem }
		}
	})
}

fn remove_non_ascii(s string) string {
	s1 := arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return elem
			.replace('“', '"')
			.replace('”', '"')
			.replace('’', "'")
			.replace('‘', "'")
			.replace('–', '-')
			.replace('…', '...')
			.replace('&mdash;', '—')
			.replace('\xc2\xa0', ' ') // &nbsp;
	})
	printable := s1.runes().map(if it < ` ` || it > rune(0x04FF) { ` ` } else { it })
	return printable.string()
}

fn sanitize_text(s string) string {
	t := truncate_long_fields(s)
	return remove_non_ascii(t)
}

fn indexes_in_string(s string, start int, end int) bool {
	return end > 0 && end <= s.len && start >= 0 && start < end
}

fn log_error(msg string, file_line string) {
	log.error('${time.now().hhmmss()} > ${file_line} > ${msg}')
}

fn change_font_size(delta int, min_size int, max_size int, mut window gui.Window) {
	size := gui.theme().n3.size + delta
	if size >= min_size && size <= max_size {
		new_theme := gui.theme_change_font_size(size) or { return }
		window.set_theme(new_theme)
	}
}
