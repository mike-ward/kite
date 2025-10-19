import gui

pub const app_min_width = 300
pub const app_height = 900
pub const image_width = 280
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
	mut window := gui.window(
		state:   app
		title:   'Kite'
		width:   app_min_width
		height:  app_height
		on_init: fn (mut w gui.Window) {
			mut app := kite_app(w)
			valid := is_valid_session(app.session)
			view := if valid { timeline_view } else { login_view }
			if valid {
				app.timeline_loop()
			}
			w.update_view(view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn kite_app(w &gui.Window) &KiteApp {
	return w.state[KiteApp]()
}
