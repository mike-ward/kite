import gui
import os
import time

const timeline_scroll_id = 1
const line_thickness = 0.5
const image_width = 270
const max_image_height = 250
const max_timeline_posts = 25
const thin_space = '\xE2\x80\x89'
const link_color = gui.cornflower_blue
const post_text_color = gui.rgb(0xA0, 0xA0, 0xA0)
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
			size:  base_text_style.size
		}
		post_repost_style := gui.TextStyle{
			...base_text_style
			color: post_text_color
			size:  base_text_style.size - 1
		}

		for post in app.timeline.posts {
			post_text := sanitize_text(post.text)
			quote_text := sanitize_text(post.quote_post_text)
			if post_text.is_blank() && quote_text.is_blank() {
				continue
			}

			mut post_content := []gui.View{cap: 10}

			if !post.repost_by.is_blank() {
				reposted_by := truncate_long_fields('•${thin_space}reposted by ${post.repost_by}')
				post_content << gui.text(
					text:       reposted_by
					mode:       .wrap
					text_style: post_repost_style
				)
			}

			author_timestamp := author_timestamp_text(post.author, post.created_at)
			post_content << text_link(author_timestamp, post.bsky_link_uri, base_text_style)
			post_content << gui.rectangle(height: gui.pad_x_small - 1) // spacer

			post_content << gui.text(
				text:       post_text
				mode:       .wrap
				text_style: post_text_style
			)

			if !quote_text.is_blank() {
				quote_author_timestamp := author_timestamp_text(post.quote_post_author,
					post.quote_post_created_at)
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
								text_link(quote_author_timestamp, post.quote_post_link_uri,
									base_text_style),
								gui.rectangle(height: gui.pad_x_small - 1),
								gui.text(
									text:       quote_text
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
				post_content << text_link(sanitize_text(post.link_title), post.link_uri,
					post_link_style)
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
						gui.image(
							file_name:  post.image_path
							max_height: max_image_height
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

fn author_timestamp_text(author string, created_at time.Time) string {
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	timestamp := if time_short == '0m' { 'now' } else { time_short }
	return truncate_long_fields('${sanitize_text(author)} • ${timestamp}')
}
