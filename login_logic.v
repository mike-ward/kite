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

fn save_session(session BSkySession, mut w gui.Window) {
	contents := toml.encode(session)
	path := get_session_path()
	os.write_file(path, contents) or {
		w.dialog(
			align_buttons: .end
			dialog_type:   .message
			title:         'Title Displays Here'
			body:          err.msg()
		)
	}
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
