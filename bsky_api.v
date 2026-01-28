// bsky_api.v implements Bluesky (AT Protocol) API client functionality.
// Provides session management, timeline retrieval, and media blob fetching.
// Main components: BSkySession, BSkyTimeline, and associated data structures.
import json
import net.http
import os

// =================== Session ===================

const pds_host = 'https://bsky.social/xrpc'
const session_file = '.kite.toml'
const api_timeline_limit = 50

struct BSkySession {
pub:
	handle          string
	email           string
	email_confirmed bool   @[json: 'emailConfirmed']
	access_jwt      string @[json: 'accessJwt']
	refresh_jwt     string @[json: 'refreshJwt']
}

struct BSkyCreateSessionRequest {
	identifier string
	password   string
}

fn create_session(identifier string, password string) !BSkySession {
	request := BSkyCreateSessionRequest{
		identifier: identifier
		password:   password
	}
	data := json.encode(request)
	response := http.post_json('${pds_host}/com.atproto.server.createSession', data)!

	return match response.status() {
		.ok { json.decode(BSkySession, response.body) }
		else { error(response.status_msg) }
	}
}

struct RefreshSession {
pub:
	access_jwt  string @[json: 'accessJwt']
	refresh_jwt string @[json: 'refreshJwt']
	active      bool
}

fn refresh_bsky_session(session BSkySession) !RefreshSession {
	response := http.fetch(
		method: .post
		url:    '${pds_host}/com.atproto.server.refreshSession'
		header: http.new_header(
			key:   .authorization
			value: 'Bearer ${session.refresh_jwt}'
		)
	) or { return error('failed to create header') }

	return match response.status() {
		.ok { json.decode(RefreshSession, response.body)! }
		else { error(response.status_msg) }
	}
}

// =================== Timeline ===================

struct BSkyTimeline {
pub:
	posts []BSkyPost @[json: 'feed']
}

struct BSkyPost {
pub:
	post   struct {
	pub:
		uri     string
		author  Author
		record  struct {
		pub:
			type       string @[json: '\$type'] // app.bsky.feed.post
			text       string
			created_at string @[json: 'createdAt']
			embed      EmbedMedia
			reply      Reply
			facets     []Facet
		}
		embed   struct {
		pub:
			type      string @[json: '\$type']
			cid       string
			thumbnail string
			record    struct {
			pub:
				type   string @[json: '\$type']
				author Author
				value  Value
			}
		}
		replies int @[json: 'replyCount']
		likes   int @[json: 'likeCount']
		reposts int @[json: 'repostCount']
		quotes  int @[json: 'quoteCount']
	}
	reason struct {
	pub:
		type string @[json: '\$type']
		by   Author
	}
}

pub struct Author {
pub:
	did          string
	handle       string
	display_name string @[json: 'displayName']
	verification struct {
		verified_status string @[json: 'verifiedStatus']
	}
}

pub struct EmbedMedia {
pub:
	type     string @[json: '\$type'] // app.bsky.embed.images
	images   []ImageLink
	media    Media
	external ExternalLink
}

pub struct ImageLink {
pub:
	alt   string
	image struct {
	pub:
		type string @[json: '\$type'] // blob
		ref  struct {
		pub:
			link string @[json: '\$link']
		}
	}
}

pub struct Media {
pub:
	type   string @[json: '\$type'] // app.bsky.embed.images
	images []ImageLink
}

pub struct ExternalLink {
pub:
	title string
	uri   string
}

pub struct Value {
pub:
	type       string @[json: '\$type']
	created_at string @[json: 'createdAt']
	text       string
	embed      EmbedMedia
	facets     []Facet
}

pub struct Facet {
pub:
	features []struct {
	pub:
		type string @[json: '\$type'] // app.bsky.richtext.facet#link
		uri  string
	}
	index    struct {
	pub:
		byte_start int @[json: 'byteStart']
		byte_end   int @[json: 'byteEnd']
	}
}

pub struct Reply {
pub:
	parent struct {
	pub:
		cid string
	}
	root   struct {
	pub:
		cid string
	}
}

fn get_timeline(session BSkySession) !BSkyTimeline {
	response := http.fetch(
		method: .get
		url:    '${pds_host}/app.bsky.feed.getTimeline?limit=${api_timeline_limit}'
		header: http.new_header(
			key:   .authorization
			value: 'Bearer ${session.access_jwt}'
		)
	)!

	$if bsky ? {
		os.write_file('response_body.json', response.body) or {}
	}

	return match response.status() {
		.ok { json.decode(BSkyTimeline, response.body) }
		else { error(response.status_msg) }
	}
}

fn url_encode(s string) string {
	mut result := []u8{cap: s.len * 3}
	for c in s {
		if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`)
			|| c == `-` || c == `_` || c == `.` || c == `~` {
			result << c
		} else {
			result << `%`
			result << '0123456789ABCDEF'[c >> 4]
			result << '0123456789ABCDEF'[c & 0x0F]
		}
	}
	return result.bytestr()
}

fn get_blob(did string, cid string) !string {
	encoded_did := url_encode(did)
	encoded_cid := url_encode(cid)
	response := http.get('${pds_host}/com.atproto.sync.getBlob?did=${encoded_did}&cid=${encoded_cid}')!
	return match response.status() {
		.ok { response.body }
		else { error(response.status_msg) }
	}
}
