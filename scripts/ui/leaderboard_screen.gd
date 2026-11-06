class_name LeaderboardScreen
extends RefCounted
## The shared leaderboard: one board per difficulty (tabs), each row with
## the cave's seed and a little map. "Play" replays that exact cave on that
## difficulty.

var root: Control
var _column: VBoxContainer
var _list: VBoxContainer
var _status: Label
var _tabs: Array[Button] = []
var _boards: Dictionary = {}
var _shown: String = "medium"
var _on_close: Callable
var _on_play: Callable


func _init(on_close: Callable, on_play: Callable, start_tab: String = "medium") -> void:
	_on_close = on_close
	_on_play = on_play
	_shown = Difficulty.valid(start_tab)
	var parts: Array = UiKit.screen("Leaderboard", 600)
	root = parts[0]
	_column = parts[1]
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in Difficulty.IDS:
		var b := UiKit.button(Difficulty.label(id), func() -> void: _show_tab(id), 110)
		b.toggle_mode = true
		tabs.add_child(b)
		_tabs.append(b)
	_column.add_child(tabs)
	_status = UiKit.label("Loading…", 15, UiKit.MUTED)
	_column.add_child(_status)
	_list = VBoxContainer.new()
	_column.add_child(_list)
	_column.add_child(UiKit.button("Back", func() -> void: _on_close.call()))
	_mark_tabs()
	UiKit.focus_first(_column)
	root.ready.connect(_load)


func _load() -> void:
	WebRequest.send(root, OnlineConfig.leaderboard_url(), func(status: int, reply: Variant) -> void:
		if status == 200 and reply is Dictionary:
			_got(reply)
		else:
			# The Worker isn't reachable: try the copy on GitHub's data branch.
			WebRequest.send(root, OnlineConfig.LEADERBOARD_READ_URL, func(s2: int, r2: Variant) -> void:
				if s2 == 200 and r2 is Dictionary:
					_got(r2)
				else:
					_status.text = "The leaderboard can't be reached right now."))


func _got(reply: Dictionary) -> void:
	var boards: Variant = reply.get("boards", {})
	_boards = boards if boards is Dictionary else {}
	_show_tab(_shown)


func _mark_tabs() -> void:
	for i in _tabs.size():
		_tabs[i].button_pressed = Difficulty.IDS[i] == _shown


func _show_tab(id: String) -> void:
	_shown = id
	_mark_tabs()
	for c in _list.get_children():
		c.queue_free()
	var entries: Variant = _boards.get(id, [])
	if not entries is Array or entries.is_empty():
		_status.text = "No %s scores yet. Clear a cave to be the first!" % Difficulty.label(id)
		return
	_status.text = "Top %d on %s" % [entries.size(), Difficulty.label(id)]
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
	var place := UiKit.label("#%d" % rank, 18, UiKit.GOLD if rank <= 3 else UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	place.custom_minimum_size = Vector2(44, 0)
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
	var tab: String = _shown
	var play := UiKit.button("Play", func() -> void: _on_play.call(int(seed_text), tab), 70)
	play.disabled = not same_gen or not seed_text.is_valid_int()
	if not same_gen:
		play.tooltip_text = "Made with an older version of the cave generator."
	row.add_child(play)
	return panel
