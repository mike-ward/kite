// Kite is desktop Bluesky client built with V-lang featuring
// a simple GUI interface for browsing your timeline.
import gui
import os

pub const app_default_width = 300
pub const app_default_height = 900

@[heap]
struct KiteApp {
mut:
	user_name   string
	password    string
	error_msg   string
	session     BSkySession
	timeline    Timeline
	show_images bool = true
}

fn main() {
	mut app := &KiteApp{}
	process_args(mut app)

	mut window := gui.window(
		state:    app
		title:    'Kite'
		width:    app_default_width
		height:   app_default_height
		on_event: app_on_event
		on_init:  fn (mut w gui.Window) {
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
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn process_args(mut app KiteApp) {
	arg := os.args_after('')[1] or { '' }
	app.show_images = arg != '-no-images'
}

fn kite_app(w &gui.Window) &KiteApp {
	return w.state[KiteApp]()
}

fn app_on_event(e &gui.Event, mut w gui.Window) {
	if e.typ == gui.EventType.mouse_scroll && e.modifiers == gui.Modifier.ctrl {
		delta := match true {
			e.scroll_y < 0 { f32(-0.25) }
			e.scroll_y > 0 { f32(0.25) }
			else { return }
		}
		change_font_size(delta, 4, 30, mut w)
	}
}
