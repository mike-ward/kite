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

const space = 0x20
const line_feed = 0x0A
const max_codepoint = 0x4FF

fn substitute_and_collapse_white_space(s string) string {
	sa := s.split_any(' \t') // keep line feeds
	ss := arrays.join_to_string[string](sa, ' ', fn (elem string) string {
		return elem
			.replace_each(['“', '"', '”', '"', '’', "'", '‘', "'", '–', '-', '…', '...',
				'&mdash;', '—', '\xc2\xa0', ' '])
			.runes().map(match true {
			it == line_feed { it }
			it < space { space }
			it > max_codepoint { space }
			else { it }
		}).string()
	})
	return ss
}

fn sanitize_text(s string) string {
	t := truncate_long_fields(s)
	return substitute_and_collapse_white_space(t)
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
