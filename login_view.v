import gui

const field_width = 250

fn login_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := kite_app(window)

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		spacing: gui.spacing_large
		content: [
			gui.text(text: 'Login', text_style: gui.theme().b1),
			gui.input(
				text:            app.user_name
				placeholder:     'User Name'
				id_focus:        1
				sizing:          gui.fixed_fit
				width:           field_width
				on_text_changed: fn (_ &gui.Shape, s string, mut w gui.Window) {
					mut app := kite_app(w)
					app.user_name = s
				}
			),
			gui.input(
				is_password:     true
				text:            app.password
				placeholder:     'Password'
				id_focus:        2
				sizing:          gui.fixed_fit
				width:           field_width
				on_text_changed: fn (_ &gui.Shape, s string, mut w gui.Window) {
					mut app := kite_app(w)
					app.password = s
				}
			),
			gui.button(
				disabled: app.user_name.is_blank() || app.password.is_blank()
				id_focus: 3
				content:  [gui.text(text: 'Submit')]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := kite_app(w)
					login(mut app, mut w)
				}
			),
			gui.text(
				text:       app.error_msg
				text_style: gui.theme().b3
				mode:       .wrap
			),
		]
	)
}
