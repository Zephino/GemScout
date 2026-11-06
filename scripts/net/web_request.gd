class_name WebRequest
extends Node
## One JSON request to the Worker, with a callback. Used by the leaderboard,
## results and suggestion screens. callback(status: int, reply: Variant);
## status 0 means no connection.

## JSON from a reply body, or null (quietly: an error page isn't JSON).
static func parse(raw: PackedByteArray) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(raw.get_string_from_utf8()) == OK else null


static func send(parent: Node, url: String, callback: Callable, method: int = HTTPClient.METHOD_GET, body: Variant = null) -> void:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	parent.add_child(http)
	http.request_completed.connect(func(result: int, status: int, _h: PackedStringArray, raw: PackedByteArray) -> void:
		var reply: Variant = null
		if result == HTTPRequest.RESULT_SUCCESS:
			reply = parse(raw)
		http.queue_free()
		callback.call(status if result == HTTPRequest.RESULT_SUCCESS else 0, reply))
	var headers := PackedStringArray(["Accept: application/json"])
	var text: String = ""
	if body != null:
		headers.append("Content-Type: application/json")
		text = JSON.stringify(body)
	if url == "" or http.request(url, headers, method, text) != OK:
		http.queue_free()
		callback.call(0, null)
