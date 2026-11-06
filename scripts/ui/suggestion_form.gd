class_name SuggestionForm
extends RefCounted
## Suggest a feature: a short form that becomes a GitHub issue through the
## Worker (no account or email needed). Device details are broad categories
## only, shown before sending.

const CATEGORIES := [["Gameplay", "gameplay"], ["Caves", "caves"], ["Enemies", "enemies"], ["Power-ups", "powerups"], ["Controls", "controls"], ["Menus & screens", "ui"], ["Other", "other"]]

var root: Control
var _column: VBoxContainer
var _category: OptionButton
var _title: LineEdit
var _body: TextEdit
var _status: Label
var _send: Button
var _on_close: Callable


func _init(on_close: Callable) -> void:
	_on_close = on_close
	var parts: Array = UiKit.screen("Suggest a feature", 480)
	root = parts[0]
	_column = parts[1]
	_column.add_child(UiKit.label("Ideas and problems go straight to the developer. Please don't include personal information.", 14, UiKit.MUTED))
	_category = OptionButton.new()
	for c: Array in CATEGORIES:
		_category.add_item(c[0])
	_category.custom_minimum_size = Vector2(0, 38)
	_column.add_child(_category)
	_title = LineEdit.new()
	_title.placeholder_text = "Short title (5–100 characters)"
	_title.max_length = 100
	_title.custom_minimum_size = Vector2(0, 38)
	_column.add_child(_title)
	_body = TextEdit.new()
	_body.placeholder_text = "Describe your idea (at least 20 characters)"
	_body.custom_minimum_size = Vector2(0, 110)
	_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_column.add_child(_body)
	var info: Dictionary = AppActions.client_info()
	_column.add_child(UiKit.label("Sent with: version %s, %s, %s, %s, %s" % [info["game_version"], info["runtime"], info["device_type"], info["platform"], info["browser"]], 12, UiKit.MUTED))
	_status = UiKit.label("", 14, UiKit.MUTED)
	_column.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_send = UiKit.button("Send", _on_send, 140)
	row.add_child(_send)
	row.add_child(UiKit.button("Close", func() -> void: _on_close.call(), 140))
	_column.add_child(row)
	UiKit.focus_first(_column)


func _on_send() -> void:
	var title: String = _title.text.strip_edges()
	var body: String = _body.text.strip_edges()
	if title.length() < 5:
		_say("The title needs at least 5 characters.", UiKit.BAD)
		return
	if body.length() < 20 or body.length() > 2000:
		_say("The description needs 20 to 2000 characters.", UiKit.BAD)
		return
	_send.disabled = true
	_say("Sending…", UiKit.MUTED)
	var payload := {
		"category": CATEGORIES[_category.selected][1],
		"title": title,
		"description": body,
		"website": "",
		"client": AppActions.client_info(),
	}
	WebRequest.send(root, OnlineConfig.suggestion_url(), func(status: int, reply: Variant) -> void:
		if status == 201:
			_say("Thank you! Your suggestion was sent.", UiKit.GOOD)
			_title.text = ""
			_body.text = ""
		else:
			var why: String = str(reply.get("error", "")) if reply is Dictionary else ""
			_say("Couldn't send it" + (": " + why if why != "" else ". Check your connection and try again."), UiKit.BAD)
			_send.disabled = false, HTTPClient.METHOD_POST, payload)


func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
