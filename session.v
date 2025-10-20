import os
import toml
import gui

fn load_session() !BSkySession {
	path := get_session_path()
	if os.exists(path) {
		contents := os.read_file(path)!
		return toml.decode[BSkySession](contents)!
	}
	return error('"${path}" does not exist')
}

fn save_session(session BSkySession) ! {
	contents := toml.encode(session)
	path := get_session_path()
	os.write_file(path, contents)!
}

fn get_session_path() string {
	home_dir := os.home_dir()
	path := os.join_path_single(home_dir, session_file)
	return path
}

fn is_valid_session(session BSkySession) bool {
	return session.handle.len > 0 && session.email.len > 0 && session.access_jwt.len > 0
		&& session.refresh_jwt.len > 0
}

fn refresh_session(mut app KiteApp) ! {
	refresh := refresh_bsky_session(app.session)!
	session := BSkySession{
		...app.session
		access_jwt:  refresh.access_jwt
		refresh_jwt: refresh.refresh_jwt
	}
	save_session(session)!
}

fn login(mut app KiteApp, mut w gui.Window) {
	if session := create_session(app.user_name, app.password) {
		save_session(session) or {
			app.error_msg = err.msg()
			return
		}
		app.session = load_session() or {
			app.error_msg = err.msg()
			return
		}
		app.error_msg = ''
		spawn app.timeline_loop(mut w)
	} else {
		app.error_msg = err.msg()
	}
}
