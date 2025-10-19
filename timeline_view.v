import gui

const post_body_color = gui.rgb(160, 160, 160)

fn timeline_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := kite_app(window)

	mut content := []gui.View{cap: max_timeline_posts}

	for post in app.timeline.posts {
		author_text := sanitize_text(post.author)
		body_text := sanitize_text(post.text)
		if author_text.is_blank() || body_text.is_blank() {
			continue
		}
		vp := gui.column(
			padding: gui.padding_none
			sizing:  gui.fill_fit
			spacing: 0
			content: [
				gui.text(
					text: author_text
				),
				gui.text(
					text:       body_text
					mode:       .wrap
					text_style: gui.TextStyle{
						...gui.theme().text_style
						color: post_body_color
					}
				),
			]
		)
		content << vp
	}

	return gui.column(
		id_scroll: 1
		width:     w
		height:    h
		sizing:    gui.fixed_fixed
		h_align:   .center
		v_align:   .middle
		content:   content
	)
}
