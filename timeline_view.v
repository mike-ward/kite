import gui
import os

const thin_space = '\xE2\x80\x89'
const link_color = gui.cornflower_blue
const post_text_color = gui.rgb(160, 160, 160)
const post_text_style = gui.TextStyle{
	...gui.theme().text_style
	color: post_text_color
}
const post_link_style = gui.TextStyle{
	...gui.theme().text_style
	color: link_color
}
const post_repost_style = gui.TextStyle{
	...gui.theme().text_style
	color: post_text_color
	size:  gui.theme().size_text_small
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
			time_short := post.created_at
				.utc_to_local()
				.relative_short()
				.fields()[0]
			timestamp := if time_short == '0m' { 'now' } else { time_short }
			author_timestamp := truncate_long_fields('${post_author} • ${timestamp}')
			mut post_content := []gui.View{cap: 6}

			if !post.repost_by.is_blank() {
				post_content << gui.text(
					text:       truncate_long_fields('•${thin_space}reposted by ${remove_non_ascii(post.repost_by)}')
					text_style: post_repost_style
				)
			}
			post_content << gui.text(text: author_timestamp)
			post_content << gui.text(
				text:       post_text
				mode:       .wrap
				text_style: post_text_style
			)
			if !post.link_uri.is_blank() {
				post_content << gui.column(
					padding:  gui.Padding{
						top: gui.pad_small
					}
					sizing:   gui.fill_fit
					on_click: fn [post] (_ voidptr, mut e gui.Event, mut _ gui.Window) {
						e.is_handled = true
						os.open_uri(post.link_uri) or { print_error(err.msg(), @FILE_LINE) }
					}
					on_hover: fn (mut _ gui.Layout, mut e gui.Event, mut w gui.Window) {
						w.set_mouse_cursor_pointing_hand()
						e.is_handled = true
					}
					content:  [
						gui.text(
							text:       sanitize_text(post.link_title)
							mode:       .wrap
							text_style: post_link_style
						),
					]
				)
			}
			if !post.image_path.is_blank() {
				post_content << gui.column(
					h_align: .center
					sizing:  gui.fill_fit
					content: [
						gui.image(
							file_name:  post.image_path
							width:      image_width
							max_height: max_image_height
							on_click:   fn [post] (_ &gui.ImageCfg, mut e gui.Event, mut _ gui.Window) {
								e.is_handled = true
								os.open_uri(post.bsky_link_uri) or {
									print_error(err.msg(), @FILE_LINE)
								}
							}
						),
					]
				)
			}
			post_content << gui.rectangle(height: gui.pad_small) // spacer
			post_content << gui.rectangle(
				height: 0.4
				width:  w - gui.pad_large - gui.pad_medium
				sizing: gui.fixed_fixed
				color:  post_text_color
			)
			content << gui.column(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 1
				content: post_content
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
