import gui

fn timeline_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := kite_app(window)

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.text(
				text:       app.timeline.str()
				mode:       .wrap
				text_style: gui.theme().b1
			),
		]
	)
}
