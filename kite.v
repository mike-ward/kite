import gui

pub const app_min_width = 300
pub const app_height = 900
pub const image_width = 250
pub const max_image_height = 250
pub const max_timeline_posts = 25

@[heap]
struct KiteApp {
mut:
	user_name string
	password  string
	error_msg string
	session   BSkySession
	timeline  Timeline
}

fn main() {
	mut app := &KiteApp{}
	app.session = load_session() or {
		app.error_msg = err.msg()
		BSkySession{}
	}
	if is_valid_session(app.session) {
		refresh_session(mut app) or {
			print_error(err.msg(), @FILE_LINE)
			exit(1)
		}
	}
	mut window := gui.window(
		state:   app
		title:   'Kite'
		width:   app_min_width
		height:  app_height
		on_init: fn (mut w gui.Window) {
			mut app := kite_app(w)
			if is_valid_session(app.session) {
				spawn app.timeline_loop(mut w)
			} else {
				w.update_view(login_view)
			}
		}
	)
	window.set_theme(create_system_font_theme())
	window.run()
}

fn kite_app(w &gui.Window) &KiteApp {
	return w.state[KiteApp]()
}

fn create_system_font_theme() gui.Theme {
	return gui.theme_maker(gui.ThemeCfg{
		...gui.theme_dark_bordered_cfg
		text_style: gui.TextStyle{
			...gui.theme_dark_bordered_cfg.text_style
			family: '' // blank means use system font family
		}
	})
}
