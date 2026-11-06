class_name ResultsScreen
extends RefCounted
## "Cave cleared!": the score broken down, the cave's seed and map, and
## sending the score to the leaderboard under your username.

var root: Control
var _column: VBoxContainer
var _name: LineEdit
var _send: Button
var _status: Label
var _result: Dictionary


func _init(result: Dictionary, on_new_cave: Callable, on_replay: Callable, on_menu: Callable) -> void:
	_result = result
	var parts: Array = UiKit.screen("Cave cleared!", 460)
	root = parts[0]
	_column = parts[1]
	_column.add_child(UiKit.label(Difficulty.label(result["difficulty"]), 16, UiKit.MUTED))
	var gems: int = result["gems"]
	var time_ms: int = result["time_ms"]
	var lines: Array = [
		["%d gems × %d" % [gems, Scoring.GEM_POINTS], gems * Scoring.GEM_POINTS],
		["No damage bonus", Scoring.NO_DAMAGE_BONUS if result["no_damage"] else 0],
		["Speed bonus (%s)" % Scoring.format_time(time_ms), Scoring.speed_bonus(gems, time_ms)],
	]
	for l: Array in lines:
		var row := HBoxContainer.new()
		var a := UiKit.label(l[0], 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		row.add_child(UiKit.label(str(l[1]), 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		_column.add_child(row)
	_column.add_child(UiKit.label("Score: %d" % result["score"], 26, UiKit.GOLD))
	var map := TextureRect.new()
	map.texture = CaveThumbnail.texture_from_base64(result["map"])
	map.custom_minimum_size = Vector2(288, 144)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_column.add_child(map)
	_column.add_child(UiKit.label("Cave seed %d" % result["seed"], 13, UiKit.MUTED))

	var row2 := HBoxContainer.new()
	_name = LineEdit.new()
	_name.max_length = Save.MAX_USERNAME
	_name.placeholder_text = "Your name"
	_name.text = Save.leaderboard_name()
	# Signed in with a username: that's the name (it hides the Google name).
	_name.editable = Save.username() == ""
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.custom_minimum_size = Vector2(0, 38)
	row2.add_child(_name)
	_send = UiKit.button("Send score", _on_send, 130)
	row2.add_child(_send)
	_column.add_child(row2)
	_status = UiKit.label("Send your score to the %s leaderboard?" % Difficulty.label(result["difficulty"]), 14, UiKit.MUTED)
	_column.add_child(_status)
	_column.add_child(UiKit.button("Play a new cave", func() -> void: on_new_cave.call()))
	_column.add_child(UiKit.button("Play this cave again", func() -> void: on_replay.call()))
	_column.add_child(UiKit.button("Main menu", func() -> void: on_menu.call()))
	UiKit.focus_first(_column)


func _on_send() -> void:
	var name: String = Save.clean_username(_name.text)
	if name == "":
		_say("Type a name first (letters and numbers).", UiKit.BAD)
		return
	Save.remember_name(name)
	_send.disabled = true
	_say("Sending…", UiKit.MUTED)
	var entry := {
		"name": name,
		"difficulty": _result["difficulty"],
		"seed": str(_result["seed"]),
		"gen": _result["gen"],
		"gems": _result["gems"],
		"time_ms": _result["time_ms"],
		"no_damage": _result["no_damage"],
		"map": _result["map"],
		"version": OnlineConfig.game_version(),
	}
	WebRequest.send(root, OnlineConfig.leaderboard_url(), func(status: int, reply: Variant) -> void:
		if status == 200 and reply is Dictionary:
			if bool(reply.get("accepted", false)):
				_say("On the leaderboard at #%d!" % int(reply.get("rank", 0)), UiKit.GOOD)
			else:
				_say("Sent, but not in the top scores this time.", UiKit.MUTED)
		elif status == 429:
			_say("Too many scores at once; try again in a minute.", UiKit.BAD)
			_send.disabled = false
		else:
			_say("Couldn't reach the leaderboard. Try again later.", UiKit.BAD)
			_send.disabled = false, HTTPClient.METHOD_POST, entry)


func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
