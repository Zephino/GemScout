class_name LeaderboardScreen
extends RefCounted
## The shared leaderboard: best cleared caves, each with its seed and a
## little map of the cave. "Play" replays that exact cave (same seed).

var root: Control
var _column: VBoxContainer
var _list: VBoxContainer
var _status: Label
var _on_close: Callable
var _on_play: Callable


func _init(on_close: Callable, on_play: Callable) -> void:
	_on_close = on_close
	_on_play = on_play
	var parts: Array = UiKit.screen("Leaderboard", 600)
	root = parts[0]
	_column = parts[1]
	_status = UiKit.label("Loading…", 15, UiKit.MUTED)
	_column.add_child(_status)
	_list = VBoxContainer.new()
	_column.add_child(_list)
	_column.add_child(UiKit.button("Back", func() -> void: _on_close.call()))
	UiKit.focus_first(_column)
	root.ready.connect(_load)


func _load() -> void:
	WebRequest.send(root, OnlineConfig.leaderboard_url(), func(status: int, reply: Variant) -> void:
		if status == 200 and reply is Dictionary:
			_show(reply.get("entries", []))
		else:
			# The Worker isn't reachable: try the copy on GitHub's data branch.
			WebRequest.send(root, OnlineConfig.LEADERBOARD_READ_URL, func(s2: int, r2: Variant) -> void:
				if s2 == 200 and r2 is Dictionary:
					_show(r2.get("entries", []))
				else:
					_status.text = "The leaderboard can't be reached right now."))


func _show(entries: Variant) -> void:
	if not entries is Array or entries.is_empty():
		_status.text = "No scores yet. Clear a cave to be the first!"
		return
	_status.text = "Top %d cleared caves" % entries.size()
	var rank: int = 0
	for e: Variant in entries:
		if not e is Dictionary:
			continue
		rank += 1
		_list.add_child(_row(rank, e))


func _row(rank: int, e: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var place := UiKit.label("#%d" % rank, 18, UiKit.GOLD if rank <= 3 else UiKit.TEXT)
	place.custom_minimum_size = Vector2(44, 0)
	place.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(place)
	var map := TextureRect.new()
	map.texture = CaveThumbnail.texture_from_base64(str(e.get("map", "")))
	map.custom_minimum_size = Vector2(108, 54)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(map)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	# Names are cleaned by the Worker; shown as plain text.
	info.add_child(UiKit.label("%s  —  %d pts" % [str(e.get("name", "?")), int(e.get("score", 0))], 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var details: String = "%s · %d gems%s · seed %s" % [Scoring.format_time(int(e.get("time_ms", 0))), int(e.get("gems", 0)), " · no damage" if bool(e.get("no_damage", false)) else "", str(e.get("seed", ""))]
	info.add_child(UiKit.label(details, 13, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(info)
	var seed_text: String = str(e.get("seed", ""))
	var same_gen: bool = int(e.get("gen", 0)) == CaveGenerator.VERSION
	var play := UiKit.button("Play", func() -> void: _on_play.call(int(seed_text)), 70)
	play.disabled = not same_gen or not seed_text.is_valid_int()
	if not same_gen:
		play.tooltip_text = "Made with an older version of the cave generator."
	row.add_child(play)
	return panel
