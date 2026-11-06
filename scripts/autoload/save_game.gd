extends Node
## This device's saved progress (user://save.json), available everywhere as
## `Save`. Also what cloud sync uploads and merges.
##
## Saved: the username, settings, and records (best score, fastest clear,
## caves cleared, gems collected). The Google sign-in itself (private cloud
## code and email) is kept apart, in user://account.cfg, never inside the save.

signal changed

const PATH := "user://save.json"
const SAVE_VERSION := 1
const MAX_USERNAME := 12

var data: Dictionary = {}


func _ready() -> void:
	data = _blank()
	load_from_disk()


static func _blank() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"username": "",
		"username_updated": 0,
		"settings": {"touch": "auto"},
		"settings_updated": 0,
		"records": {"best_score": 0, "best_time_ms": 0, "caves_cleared": 0, "gems_collected": 0},
	}


func load_from_disk() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var text: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		data = sanitize(parsed)


func save_to_disk() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
	changed.emit()


## Only known fields with sensible values, from any (possibly old or edited) save.
static func sanitize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = _blank()
	out["username"] = clean_username(str(raw.get("username", "")))
	out["username_updated"] = int(raw.get("username_updated", 0))
	var settings: Variant = raw.get("settings", {})
	if settings is Dictionary and str(settings.get("touch", "auto")) in ["auto", "on", "off"]:
		out["settings"]["touch"] = str(settings.get("touch", "auto"))
	out["settings_updated"] = int(raw.get("settings_updated", 0))
	var records: Variant = raw.get("records", {})
	if records is Dictionary:
		for key: String in out["records"]:
			out["records"][key] = maxi(0, int(records.get(key, 0)))
	return out


## Letters, numbers, space, _ and - only; at most 12 (the leaderboard's rule).
static func clean_username(raw: String) -> String:
	var cleaned: String = ""
	for ch in raw:
		var code: int = ch.unicode_at(0)
		var ok: bool = (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or ch == " " or ch == "_" or ch == "-"
		if ok:
			cleaned += ch
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	return cleaned.strip_edges().left(MAX_USERNAME).strip_edges()


## Two saves made one: the best records win; the most recently changed
## username and settings win.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var x: Dictionary = sanitize(a)
	var y: Dictionary = sanitize(b)
	var out: Dictionary = _blank()
	var newer_name: Dictionary = x if x["username_updated"] >= y["username_updated"] else y
	out["username"] = newer_name["username"]
	out["username_updated"] = newer_name["username_updated"]
	var newer_settings: Dictionary = x if x["settings_updated"] >= y["settings_updated"] else y
	out["settings"] = newer_settings["settings"].duplicate()
	out["settings_updated"] = newer_settings["settings_updated"]
	for key: String in ["best_score", "caves_cleared", "gems_collected"]:
		out["records"][key] = maxi(x["records"][key], y["records"][key])
	var tx: int = x["records"]["best_time_ms"]
	var ty: int = y["records"]["best_time_ms"]
	out["records"]["best_time_ms"] = mini(tx, ty) if tx > 0 and ty > 0 else maxi(tx, ty)
	return out


func username() -> String:
	return str(data.get("username", ""))


func set_username(name: String) -> void:
	data["username"] = clean_username(name)
	data["username_updated"] = int(Time.get_unix_time_from_system())
	save_to_disk()


func setting(key: String) -> String:
	return str(data["settings"].get(key, ""))


func set_setting(key: String, value: String) -> void:
	data["settings"][key] = value
	data["settings_updated"] = int(Time.get_unix_time_from_system())
	save_to_disk()


func records() -> Dictionary:
	return data["records"]


## After a cleared cave.
func record_clear(result: Dictionary) -> void:
	var r: Dictionary = data["records"]
	r["caves_cleared"] += 1
	r["gems_collected"] += int(result["gems"])
	r["best_score"] = maxi(r["best_score"], int(result["score"]))
	var t: int = int(result["time_ms"])
	r["best_time_ms"] = t if r["best_time_ms"] == 0 else mini(r["best_time_ms"], t)
	save_to_disk()
