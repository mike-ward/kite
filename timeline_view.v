import gui

const post_text_color = gui.rgb(160, 160, 160)
const post_text_style = gui.TextStyle{
	...gui.theme().text_style
	color: post_text_color
}

fn timeline_view(window &gui.Window) gui.View {
	app := kite_app(window)
	w, h := window.window_size()
	mut content := []gui.View{cap: max_timeline_posts}

	if app.timeline.posts.len == 0 {
		content << gui.column(
			sizing:  gui.fill_fill
			h_align: .center
			v_align: .middle
			content: [gui.text(text: 'Fetching Timeline...', text_style: gui.theme().b1)]
		)
	} else {
		for post in app.timeline.posts {
			post_author := sanitize_text(post.author)
			post_text := sanitize_text(post.text)
			if post_author.is_blank() || post_text.is_blank() {
				continue
			}
			content << gui.column(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 1
				content: [
					gui.text(
						text: post_author
					),
					gui.text(
						text:       post_text
						mode:       .wrap
						text_style: post_text_style
					),
					// spacer
					gui.rectangle(height: gui.pad_small),
					// horizontal line
					gui.rectangle(
						height: 0.4
						width:  w - gui.pad_large - gui.pad_medium
						sizing: gui.fixed_fixed
						color:  post_text_color
					),
				]
			)
		}
	}
	return gui.column(
		id_scroll: 1
		width:     w
		height:    h
		sizing:    gui.fixed_fixed
		padding:   gui.Padding{
			top:    gui.pad_x_small
			bottom: gui.pad_small
			left:   gui.pad_small + gui.pad_x_small
			right:  gui.pad_medium
		}
		content:   content
	)
}
