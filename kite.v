// Kite is desktop Bluesky client built with V-lang featuring
// a clean GUI interface for browsing your timeline.
import gui

pub const app_default_width = 300
pub const app_default_height = 900

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
	mut window := gui.window(
		state:   &KiteApp{}
		title:   'Kite'
		width:   app_default_width
		height:  app_default_height
		on_init: fn (mut w gui.Window) {
			mut app := kite_app(w)
			app.session = load_session() or {
				app.error_msg = err.msg()
				BSkySession{}
			}
			if is_valid_session(app.session) {
				app.start_timeline_loop(mut w)
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
