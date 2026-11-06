class_name CloudSync
extends Node
## Cloud saves, so progress follows the player between the web, PC and
## phone (available everywhere as `Cloud`). Signing in with Google (child
## AccountSignIn) gives this device the account's private save code; the
## Worker keeps one save per code (leaderboard-api/src/cloud.js).
##
## A sync downloads the cloud copy, merges it with this device's save
## (Save.merge: best records win, the newest username and settings win),
## saves the result here, and uploads it. It runs at launch, after signing in,
## and a few seconds after anything is saved. The game always works offline;
## a failed sync is simply tried again later.

signal status_changed

const ACCOUNT_PATH := "user://account.cfg"
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 12
## Wait this long after a save before syncing (several saves become one upload).
const SOON_S := 3.0
## The Worker accepts one upload per save every 5 s.
const MIN_GAP_S := 6.0

## "off" (not signed in), "syncing", "synced", or "error".
var state: String = "off"
var last_synced_unix: int = 0
var sign_in: AccountSignIn

var _http: HTTPRequest
var _phase: String = ""
var _wait_s: float = -1.0
var _since_upload_s: float = 999.0
var _applying: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.request_completed.connect(_on_reply)
	add_child(_http)
	sign_in = AccountSignIn.new()
	add_child(sign_in)
	state = "synced" if signed_in() else "off"
	var save: Node = get_node_or_null("/root/Save")
	if save != null:
		save.changed.connect(_on_save_changed)
	if signed_in():
		request_sync()


static func _account() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(ACCOUNT_PATH)
	return cfg


## This device's private cloud code ("" when not signed in). Never shown or logged.
static func code() -> String:
	return normalize(str(_account().get_value("account", "code", "")))


static func email() -> String:
	return str(_account().get_value("account", "email", ""))


static func signed_in() -> bool:
	return code() != ""


## The code without dashes or spaces, upper-case; "" if it isn't valid.
static func normalize(raw: String) -> String:
	var c: String = raw.replace("-", "").replace(" ", "").to_upper()
	if c.length() != CODE_LENGTH:
		return ""
	for ch in c:
		if not ALPHABET.contains(ch):
			return ""
	return c


## Called by AccountSignIn when Google sign-in finished.
func link(account_code: String, account_email: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "code", normalize(account_code))
	cfg.set_value("account", "email", account_email.left(120))
	cfg.save(ACCOUNT_PATH)
	state = "syncing"
	status_changed.emit()
	request_sync(true)


func sign_out() -> void:
	_http.cancel_request()
	_phase = ""
	_wait_s = -1.0
	if FileAccess.file_exists(ACCOUNT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ACCOUNT_PATH))
	state = "off"
	status_changed.emit()


## Sync now (or as soon as the last one finishes).
func request_sync(now: bool = false) -> void:
	if not signed_in() or OnlineConfig.cloud_url() == "":
		return
	_wait_s = 0.0 if now else SOON_S


func _on_save_changed() -> void:
	if not _applying and signed_in():
		request_sync()


func _process(delta: float) -> void:
	_since_upload_s += delta
	if _wait_s < 0.0 or _phase != "":
		return
	_wait_s -= delta
	if _wait_s > 0.0:
		return
	_wait_s = -1.0
	_phase = "download"
	state = "syncing"
	status_changed.emit()
	if _http.request(OnlineConfig.cloud_url(), _auth_headers()) != OK:
		_failed()


func _auth_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + code(), "Content-Type: application/json", "Accept: application/json"])


func _on_reply(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var phase: String = _phase
	_phase = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		_failed()
		return
	if phase == "download":
		if status != 200:
			_failed()
			return
		var reply: Variant = WebRequest.parse(body)
		var cloud_save: Variant = reply.get("save") if reply is Dictionary else null
		var save: Node = get_node("/root/Save")
		var merged: Dictionary = save.merge(save.data, cloud_save) if cloud_save is Dictionary else save.data.duplicate(true)
		_applying = true
		save.data = merged
		save.save_to_disk()
		_applying = false
		_upload(merged)
	elif phase == "upload":
		if status == 200:
			state = "synced"
			last_synced_unix = int(Time.get_unix_time_from_system())
			status_changed.emit()
		elif status == 429:
			# Too soon after the last upload: try again shortly.
			_phase = ""
			_wait_s = MIN_GAP_S
		else:
			_failed()


func _upload(save_data: Dictionary) -> void:
	if _since_upload_s < MIN_GAP_S:
		_wait_s = MIN_GAP_S - _since_upload_s
		state = "synced"
		status_changed.emit()
		return
	_since_upload_s = 0.0
	_phase = "upload"
	if _http.request(OnlineConfig.cloud_url(), _auth_headers(), HTTPClient.METHOD_PUT, JSON.stringify(save_data)) != OK:
		_phase = ""
		_failed()


func _failed() -> void:
	state = "error"
	status_changed.emit()
	# Try again in a minute.
	_wait_s = 60.0
