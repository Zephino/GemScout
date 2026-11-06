class_name OnlineConfig
extends RefCounted
## Where GemScout's online service lives (leaderboard-api/README.md). These
## are public addresses, not secrets.

## Public board (read-only) on the `data` branch, written only by the Worker.
const LEADERBOARD_READ_URL := "https://raw.githubusercontent.com/Zephino/GemScout/data/leaderboard.json"

## The Cloudflare Worker (no path, no trailing slash).
const API_BASE_URL := "https://gemscout.thebotcoder.workers.dev"

## For testing against a Worker on this computer (`npx wrangler dev`):
## start the game with `-- --api=http://127.0.0.1:8787`.
static var base_override: String = ""


static func api_base() -> String:
	if base_override == "":
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--api="):
				base_override = arg.trim_prefix("--api=")
	return (base_override if base_override != "" else API_BASE_URL).strip_edges().trim_suffix("/")


static func url(path: String) -> String:
	var base: String = api_base()
	return "" if base.is_empty() else base + path


static func leaderboard_url() -> String:
	return url("/leaderboard")


static func suggestion_url() -> String:
	return url("/suggestions")


static func cloud_url() -> String:
	return url("/cloud/save")


static func auth_url(step: String) -> String:
	return url("/auth/" + step)


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))
