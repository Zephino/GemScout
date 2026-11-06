class_name AccountSignIn
extends Node
## Sign in with Google (as in Mythriven; leaderboard-api/src/accounts.js).
## The same on the web, PC and phones: the game asks the Worker for a sign-in
## page, opens it in the browser, and asks every few seconds until the player
## has signed in there. The Worker then hands over the account's private
## cloud-save code; this device links to it and its progress is merged with
## the account's (best records win). Google's email is kept only on this
## device, to show who is signed in; the real name is never asked for
## (players choose a username instead).

signal changed

const POLL_S := 2.0
const TIMEOUT_S := 600.0

## "idle", "starting", "waiting" (the browser page is open), or "done".
var state: String = "idle"
## Something for the player to read when it went wrong ("" otherwise).
var error: String = ""

var _http: HTTPRequest
var _login: String = ""
var _poll_in: float = -1.0
var _left_s: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_reply)
	add_child(_http)


static func available() -> bool:
	return OnlineConfig.auth_url("start") != ""


func busy() -> bool:
	return state == "starting" or state == "waiting"


func start() -> void:
	if not available() or busy():
		return
	error = ""
	_http.cancel_request()
	state = "starting"
	changed.emit()
	var body: String = JSON.stringify({"code": CloudSync.code()})
	if _http.request(OnlineConfig.auth_url("start"), ["Content-Type: application/json"], HTTPClient.METHOD_POST, body) != OK:
		_stop("Couldn't reach the sign-in service. Check your connection.")


func cancel() -> void:
	_stop("")


func _process(delta: float) -> void:
	if state != "waiting":
		return
	_left_s -= delta
	if _left_s <= 0.0:
		_stop("Sign-in took too long. Try again.")
		return
	if _poll_in < 0.0:
		return
	_poll_in -= delta
	if _poll_in <= 0.0:
		_poll_in = -1.0
		if _http.request(OnlineConfig.auth_url("poll") + "?login=" + _login.uri_encode()) != OK:
			_poll_in = POLL_S


func _on_reply(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var reply: Variant = WebRequest.parse(body) if result == HTTPRequest.RESULT_SUCCESS else null
	if state == "starting":
		if status == 503:
			_stop("Google sign-in isn't set up on the server yet.")
		elif status != 200 or not reply is Dictionary or str(reply.get("login", "")) == "":
			_stop("Couldn't reach the sign-in service. Check your connection.")
		else:
			_login = str(reply["login"])
			state = "waiting"
			_left_s = TIMEOUT_S
			_poll_in = POLL_S
			changed.emit()
			_open(str(reply.get("url", "")))
		return
	if state != "waiting":
		return
	_poll_in = POLL_S
	if status != 200 or not reply is Dictionary:
		return
	match str(reply.get("state", "")):
		"done":
			_finish(str(reply.get("code", "")), str(reply.get("email", "")))
		"cancelled":
			_stop("Sign-in was cancelled.")
		"expired":
			_stop("Sign-in took too long. Try again.")


func _finish(account_code: String, email: String) -> void:
	var cloud: CloudSync = get_parent() as CloudSync
	if CloudSync.normalize(account_code) == "" or cloud == null:
		_stop("Something went wrong signing in. Try again.")
		return
	cloud.link(account_code, email)
	_login = ""
	state = "done"
	error = ""
	changed.emit()


func _stop(reason: String) -> void:
	_http.cancel_request()
	state = "idle"
	error = reason
	_login = ""
	_poll_in = -1.0
	changed.emit()


## Opens the sign-in page in the browser (a new tab on the web).
func _open(url: String) -> void:
	if not url.begins_with("https://") and not url.begins_with("http://127.0.0.1"):
		return
	if OS.has_feature("web"):
		var opened: Variant = JavaScriptBridge.eval("!!window.open(%s, '_blank')" % JSON.stringify(url), true)
		if not bool(opened):
			error = "Your browser blocked the sign-in window. Allow pop-ups for this site and try again."
			changed.emit()
		return
	OS.shell_open(url)
