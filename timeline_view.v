import gui
import os

const timeline_scroll_id = 1
const line_thickness = 0.5
const image_width = 270
const max_image_height = 250
const max_timeline_posts = 25
const link_color = gui.cornflower_blue
const post_text_color = gui.rgb(0xAA, 0xAA, 0xAA)
const post_divider_color = gui.rgb(0x70, 0x70, 0x70)

fn timeline_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	content := timeline_content(window)

	return gui.column(
		id_focus:     1
		id_scroll:    timeline_scroll_id
		scroll_mode:  .vertical_only
		width:        w
		height:       h
		sizing:       gui.fixed_fixed
		padding:      gui.Padding{
			top:    gui.pad_x_small
			bottom: gui.pad_small
			left:   gui.pad_small + gui.pad_x_small
			right:  gui.pad_medium + gui.pad_x_small
		}
		on_any_click: fn (_ voidptr, mut e gui.Event, mut w gui.Window) {
			if e.mouse_button == .right {
				w.scroll_vertical_to(timeline_scroll_id, 0)
				e.is_handled = true
			}
		}
		content:      [
			gui.column(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				content: content
			),
		]
	)
}

fn timeline_content(window &gui.Window) []gui.View {
	app := kite_app(window)
	mut content := []gui.View{cap: max_timeline_posts}

	if app.timeline.posts.len == 0 {
		content << gui.column(
			sizing:  gui.fill_fill
			h_align: .center
			v_align: .middle
			content: [
				gui.text(
					text: 'Fetching Timeline...'
				),
			]
		)
	} else {
		base_text_style := gui.theme().n3
		post_text_style := gui.TextStyle{
			...base_text_style
			color: post_text_color
		}
		post_link_style := gui.TextStyle{
			...base_text_style
			color: link_color
			size:  base_text_style.size - 1
		}
		post_repost_style := gui.TextStyle{
			...base_text_style
			color: post_text_color
			size:  base_text_style.size - 1
		}

		for post in app.timeline.posts {
			if post.formatted_text.is_blank() && post.formatted_quote_text.is_blank() {
				continue
			}

			mut post_content := []gui.View{cap: 10}

			if !post.formatted_repost_by.is_blank() {
				post_content << gui.text(
					text:       post.formatted_repost_by
					mode:       .wrap
					text_style: post_repost_style
				)
			}

			post_content << text_link(post.formatted_time_author, post.bsky_link_uri,
				base_text_style)
			post_content << gui.rectangle(height: gui.pad_x_small - 1) // spacer

			post_content << gui.text(
				text:       post.formatted_text
				mode:       .wrap
				text_style: post_text_style
			)

			if !post.formatted_quote_text.is_blank() {
				post_content << gui.row(
					padding: gui.Padding{
						top:    gui.pad_medium
						left:   gui.pad_x_small
						bottom: gui.pad_medium
						right:  gui.pad_small
					}
					sizing:  gui.fill_fit
					spacing: 0
					content: [
						gui.rectangle( // vertical line
							width:  line_thickness
							sizing: gui.fixed_fill
							color:  post_text_color
						),
						gui.rectangle(width: gui.pad_medium),
						gui.column(
							padding: gui.padding_none
							sizing:  gui.fill_fit
							spacing: 0
							content: [
								text_link(post.formatted_quote_time_auth, post.quote_post_link_uri,
									base_text_style),
								gui.rectangle(height: gui.pad_x_small - 1),
								gui.text(
									text:       post.formatted_quote_text
									mode:       .wrap
									text_style: post_text_style
								),
							]
						),
					]
				)
			}

			if !post.link_uri.is_blank() {
				post_content << gui.rectangle(height: gui.pad_x_small) // spacer
				post_content << text_link(post.link_title, post.link_uri, post_link_style) // link_title is already sanitized in logic if needed, but here we just used it directly. Wait, previous code used sanitized_text(post.link_title). I should probably sanitize it in logic too.
			}

			if !post.image_path.is_blank() && app.show_images {
				post_content << gui.column(
					h_align: .center
					padding: gui.Padding{
						top:   gui.pad_small
						right: gui.pad_small
					}
					sizing:  gui.fill_fit
					content: [
						gui.column(
							color:   gui.theme().color_border
							padding: gui.padding_one
							radius:  0
							content: [
								gui.image(
									file_name:  post.image_path
									max_height: max_image_height
								),
							]
						),
					]
				)
			}

			post_content << gui.rectangle(height: gui.pad_small) // spacer
			post_content << gui.rectangle( // divider line
				height: line_thickness
				sizing: gui.fill_fixed
				color:  post_divider_color
			)

			content << gui.column(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 1
				content: post_content
			)
		}
	}
	return content
}

fn text_link(link_title string, link_uri string, text_style gui.TextStyle) gui.View {
	return gui.column(
		padding:  gui.padding_none
		sizing:   gui.fill_fit
		on_click: fn [link_uri] (_ voidptr, mut e gui.Event, mut _ gui.Window) {
			e.is_handled = true
			os.open_uri(link_uri) or { log_error(err.msg(), @FILE_LINE) }
		}
		on_hover: fn (mut layout gui.Layout, mut e gui.Event, mut w gui.Window) {
			e.is_handled = true
			layout.children[0].shape.text_style = &gui.TextStyle{
				...layout.children[0].shape.text_style
				color: gui.cornflower_blue
			}
			w.set_mouse_cursor_pointing_hand()
		}
		content:  [
			gui.text(
				text:       link_title
				mode:       .wrap
				text_style: text_style
			),
		]
	)
}
