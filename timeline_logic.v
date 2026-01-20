// timeline_logic.v implements the core timeline functionality for the Kite Bluesky client
// Key features:
// - Timeline data structures (Timeline and Post)
// - Timeline refresh and update loop
// - Post data conversion from Bluesky API format
// - Image downloading and caching
// - Link and quote post handling
// - Session management and error handling
import gui
import math
import net.http
import os
import stbi
import time

// Directory constants for storing temporary images and cache
const kite_dir = 'kite'
const image_tmp_dir = os.join_path(os.temp_dir(), kite_dir)
const thin_space = '\xE2\x80\x89'

// Timeline represents a collection of posts to be displayed in the UI
@[heap]
struct Timeline {
pub:
	posts []Post
}

// Post represents a single post in the timeline with all associated metadata
@[heap]
struct Post {
pub:
	id                        string
	author                    string
	verified                  bool
	created_at                time.Time
	text                      string
	link_uri                  string
	link_title                string
	image_path                string
	image_alt                 string
	repost_by                 string
	replies                   int
	reposts                   int
	likes                     int
	bsky_link_uri             string
	quote_post_author         string
	quote_post_created_at     time.Time
	quote_post_text           string
	quote_post_link_title     string
	quote_post_link_uri       string
	formatted_text            string
	formatted_repost_by       string
	formatted_time_author     string
	formatted_quote_text      string
	formatted_quote_time_auth string
}

fn (mut app KiteApp) start_timeline_loop(mut w gui.Window) {
	spawn app.timeline_loop(mut w)
}

// timeline_loop manages the main timeline update cycle:
// - Fetches new timeline data from Bluesky API periodically
// - Downloads and caches post images
// - Updates the UI with new timeline content
// - Handles session refresh and error fallback
// - Runs continuously until error occurs
// - Uses exponential backoff for retries
fn (mut app KiteApp) timeline_loop(mut w gui.Window) {
	mut fallback_counter := 0
	w.update_view(timeline_view)

	for {
		bluesky_timeline := get_timeline(app.session) or {
			if fallback_counter < 10 {
				fallback_counter++
				refresh_session(mut app) or { log_error(err.msg(), @FILE_LINE) }
				time.sleep(time.second * fallback_counter * fallback_counter)
				continue
			}
			w.@lock()
			app.timeline = Timeline{}
			app.error_msg = err.msg()
			w.unlock()

			w.update_view(login_view)
			w.update_window()
			break
		}

		prune_disk_image_cache(mut w)

		// 1. Render text immediately (images might be missing)
		timeline := from_bluesky_timeline(bluesky_timeline, max_timeline_posts)
		w.@lock()
		app.timeline = timeline
		w.unlock()
		w.update_window()

		// 2. Download images in background
		if app.show_images {
			get_timeline_images(bluesky_timeline)

			// 3. Re-render with images (now downloaded)
			// We need to re-run from_bluesky_timeline so post_image() finds the files
			timeline_with_images := from_bluesky_timeline(bluesky_timeline, max_timeline_posts)
			w.@lock()
			app.timeline = timeline_with_images
			w.unlock()
			w.update_window()
		}
		fallback_counter = 0
		time.sleep(time.minute)
	}
}

fn from_bluesky_timeline(timeline BSkyTimeline, max_posts int) Timeline {
	mut posts := []Post{cap: max_posts}
	mut post_count := 0

	for post in timeline.posts {
		if post.post.record.reply.parent.cid.len > 0 || post.post.record.reply.root.cid.len > 0 {
			// don't display stand alone replies, no context'
			continue
		}
		posts << from_bluesky_post(post)
		post_count += 1
		if post_count > max_posts {
			break
		}
	}
	return Timeline{
		posts: posts
	}
}

fn from_bluesky_post(post BSkyPost) Post {
	handle := post.post.author.handle
	d_name := post.post.author.display_name
	name := if d_name.len > 0 { d_name } else { handle }
	path, alt := post_image(post)
	bsky_link_uri := bluesky_post_link(post)
	repost_by_name := repost_by(post)

	// links are displayed below post text.
	// If link appears in text, remove it from text.
	mut text := post.post.record.text
	mut uri, mut title := external_link(post)
	inline_uri, byte_start, byte_end := inline_link(post)
	if indexes_in_string(text, byte_start, byte_end) {
		uri = inline_uri
		title = sanitize_text(text[byte_start..byte_end])
		text = text[0..byte_start] + text[byte_end..]
	}

	// quoted links are displayed below quoted text.
	// If link appears in quoted text, remove it from quoted text.
	mut q_text := get_quote_post_text(post)
	q_uri, _, q_byte_start, q_byte_end := get_quote_post_link(post)
	if indexes_in_string(q_text, q_byte_start, q_byte_end) {
		uri = q_uri
		// q_title = q_text[q_byte_start..q_byte_end] // Unused
		q_text = q_text[0..q_byte_start] + q_text[q_byte_end..]
	}

	created_at := time.parse_iso8601(post.post.record.created_at) or { time.utc() }

	return Post{
		id:                        post.post.uri
		author:                    name
		verified:                  bluesky_post_verified(post)
		created_at:                created_at
		text:                      text
		link_uri:                  uri
		link_title:                title
		image_path:                path
		image_alt:                 alt
		repost_by:                 repost_by_name
		replies:                   post.post.replies
		reposts:                   post.post.reposts + post.post.quotes
		likes:                     post.post.likes
		bsky_link_uri:             bsky_link_uri
		quote_post_author:         get_quote_post_author(post)
		quote_post_created_at:     get_quote_post_created_at(post)
		quote_post_text:           q_text
		quote_post_link_uri:       q_uri
		formatted_text:            sanitize_text(text)
		formatted_repost_by:       if repost_by_name.len > 0 {
			truncate_long_fields('•${thin_space}reposted by ${repost_by_name}')
		} else {
			''
		}
		formatted_time_author:     author_timestamp_text(name, created_at)
		formatted_quote_text:      sanitize_text(q_text)
		formatted_quote_time_auth: author_timestamp_text(get_quote_post_author(post),
			get_quote_post_created_at(post))
	}
}

fn author_timestamp_text(author string, created_at time.Time) string {
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	timestamp := if time_short == '0m' { 'now' } else { time_short }
	return truncate_long_fields('${sanitize_text(author)} • ${timestamp}')
}

fn bluesky_post_verified(post BSkyPost) bool {
	return post.post.author.verification.verified_status == 'valid'
}

fn bluesky_post_link(post BSkyPost) string {
	id := post.post.uri.all_after_last('.post/')
	handle := post.post.author.handle
	return 'https://bsky.app/profile/${handle}/post/${id}'
}

fn repost_by(post BSkyPost) string {
	return match post.reason.type.contains('Repost') {
		true {
			match post.reason.by.display_name.len > 0 {
				true { post.reason.by.display_name }
				else { post.reason.by.handle }
			}
		}
		else {
			''
		}
	}
}

fn external_link(post BSkyPost) (string, string) {
	external := post.post.record.embed.external
	if external.uri.len > 0 {
		title := if external.title.len > 0 { external.title } else { external.uri }
		return external.uri, sanitize_text(title)
	}
	return '', ''
}

// post_image downloads the first image blob associated with the post
// and returns the file path where the image is stored and the alt text
// for that image.
fn post_image(post BSkyPost) (string, string) {
	sources := extract_image_sources(post)
	for source in sources {
		tmp_file := image_tmp_file_path(source.cid)
		if os.exists(tmp_file) {
			return tmp_file, source.alt
		}
	}
	return '', ''
}

// get_timeline_images retrieves images from bluesky.
// Instead of direct links, an identifier (cid) is specified.
// The api also requires the authors identifier (did)
fn get_timeline_images(timeline BSkyTimeline) {
	os.mkdir_all(image_tmp_dir) or { log_error(err.msg(), @FILE_LINE) }

	mut threads := []thread{}
	for post in timeline.posts {
		threads << spawn download_post_images(post)
	}
	threads.wait()
}

fn download_post_images(post BSkyPost) {
	image_sources := extract_image_sources(post)
	for source in image_sources {
		image_tmp_file := image_tmp_file_path(source.cid)
		if !os.exists(image_tmp_file) {
			if source.url.len > 0 {
				// Download from URL (thumbnail)
				response := http.get(source.url) or {
					log_error(err.msg(), @FILE_LINE)
					continue
				}
				if response.status() != .ok {
					continue
				}
				save_image(image_tmp_file, response.body) or {
					log_error(err.msg(), @FILE_LINE)
					continue
				}
			} else {
				// Download blob
				blob := get_blob(source.author_did, source.cid) or {
					log_error(err.msg(), @FILE_LINE)
					continue
				}
				save_image(image_tmp_file, blob) or {
					log_error(err.msg(), @FILE_LINE)
					continue
				}
			}
		}
	}
}

struct ImageSource {
	cid        string
	url        string
	alt        string
	author_did string
}

fn extract_image_sources(post BSkyPost) []ImageSource {
	mut sources := []ImageSource{}
	if post.post.record.embed.images.len > 0 {
		for image in post.post.record.embed.images {
			if image.image.ref.link.len > 0 {
				sources << ImageSource{
					cid:        image.image.ref.link
					alt:        image.alt
					author_did: post.post.author.did
				}
			}
		}
	} else if post.post.record.embed.media.images.len > 0 {
		for image in post.post.record.embed.media.images {
			if image.image.ref.link.len > 0 {
				sources << ImageSource{
					cid:        image.image.ref.link
					alt:        image.alt
					author_did: post.post.author.did
				}
			}
		}
	} else if post.post.embed.thumbnail.len > 0 {
		sources << ImageSource{
			cid:        post.post.embed.cid
			url:        post.post.embed.thumbnail
			author_did: post.post.author.did
		}
	} else if post.post.embed.record.value.embed.images.len > 0 {
		for image in post.post.embed.record.value.embed.images {
			if image.image.ref.link.len > 0 {
				sources << ImageSource{
					cid:        image.image.ref.link
					alt:        image.alt
					author_did: post.post.embed.record.author.did
				}
			}
		}
	}
	return sources
}

fn save_image(name string, blob string) ! {
	m_img := stbi.load_from_memory(blob.str, blob.len) or { return err }
	ratio := f64(m_img.height) / f64(m_img.width)
	r_img := stbi.resize_uint8(m_img, image_width, int(image_width * ratio)) or { return err }
	height := math.min(max_image_height, r_img.height)

	stbi.stbi_write_jpg(name, r_img.width, height, r_img.nr_channels, r_img.data, 90) or {
		return err
	}
}

fn has_embed_post(post BSkyPost) bool {
	return post.post.embed.record.type.contains('#viewRecord')
		&& post.post.embed.record.value.type.contains('post')
}

fn get_quote_post_author(post BSkyPost) string {
	if has_embed_post(post) {
		handle := post.post.embed.record.author.handle
		name := post.post.embed.record.author.display_name
		return if name.len > 0 { name } else { handle }
	}
	return ''
}

fn get_quote_post_created_at(post BSkyPost) time.Time {
	if has_embed_post(post) {
		return time.parse_iso8601(post.post.embed.record.value.created_at) or { time.Time{} }
	}
	return time.Time{}
}

fn get_quote_post_text(post BSkyPost) string {
	if has_embed_post(post) {
		return post.post.embed.record.value.text
	}
	return ''
}

fn get_quote_post_link(post BSkyPost) (string, string, int, int) {
	embed := post.post.embed.record.value.embed
	facets := post.post.embed.record.value.facets
	if has_embed_post(post) && embed.type.contains('external') {
		title := if embed.external.title.len > 0 { embed.external.title } else { embed.external.uri }
		return embed.external.uri, title, 0, 0
	} else if facets.len > 0 { // usually a link to a video
		for facet in facets {
			for feature in facet.features {
				if feature.uri.len > 0 {
					return feature.uri, feature.uri, facets[0].index.byte_start, facets[0].index.byte_end
				}
			}
		}
	}

	return '', '', 0, 0
}

fn image_tmp_file_path(cid string) string {
	return os.join_path_single(image_tmp_dir, '${cid}.jpg')
}

fn inline_link(post BSkyPost) (string, int, int) {
	for facet in post.post.record.facets {
		for feature in facet.features {
			if feature.type.contains('#link') {
				return feature.uri, facet.index.byte_start, facet.index.byte_end
			}
		}
	}
	return '', 0, 0
}

fn prune_disk_image_cache(mut window gui.Window) {
	entries := os.ls(image_tmp_dir) or { return }
	for entry in entries {
		path := os.join_path_single(image_tmp_dir, entry)
		last := os.file_last_mod_unix(path)
		date := time.unix(last)
		diff := time.utc() - date
		if diff > time.hour {
			window.remove_image_from_cache_by_file_name(path)
			os.rm(path) or {}
		}
	}
}
