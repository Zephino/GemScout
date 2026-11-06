class_name TitleScreen
extends Control
## The main screen: Play, Leaderboard, Settings, Suggest a feature, Quit, and
## a badge showing whether you're signed in to Google (tap it for Settings).

signal play
signal open_leaderboard
signal open_settings
signal open_suggest

var _badge: Button
var _quit_note: Label


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color8(16, 12, 24)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var gems := HBoxContainer.new()
	gems.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 5:
		var icon := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/sprites/gems.png")
		atlas.region = Rect2(i * 12, 0, 12, 12)
		icon.texture = atlas
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gems.add_child(icon)
	col.add_child(gems)
	col.custom_minimum_size = Vector2(300, 0)
	var title := UiKit.label("GEMSCOUT", 44, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, false)
	title.add_theme_color_override("font_outline_color", Color8(80, 40, 10))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	col.add_child(UiKit.label("Find every gem. Find the way out.", 15, UiKit.MUTED))
	var r: Dictionary = Save.records()
	if r["caves_cleared"] > 0:
		col.add_child(UiKit.label("Best score %d  ·  Caves cleared %d" % [r["best_score"], r["caves_cleared"]], 14, UiKit.MUTED))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	col.add_child(gap)
	for entry: Array in [["Play", play], ["Leaderboard", open_leaderboard], ["Settings", open_settings], ["Suggest a feature", open_suggest]]:
		var sig: Signal = entry[1]
		col.add_child(UiKit.button(entry[0], func() -> void: sig.emit(), 240))
	col.add_child(UiKit.button("Quit", _on_quit, 240))
	_quit_note = UiKit.label("", 14, UiKit.MUTED)
	col.add_child(_quit_note)

	# Signed-in badge, top right.
	_badge = UiKit.button("", func() -> void: open_settings.emit(), 0)
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_right = -8
	_badge.offset_top = 8
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge.focus_mode = Control.FOCUS_NONE
	add_child(_badge)
	var version := UiKit.label("v" + OnlineConfig.game_version(), 13, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, false)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 10
	version.offset_top = -26
	add_child(version)
	# Godot's MIT license asks for its notice in shipped games (CREDITS.md).
	var godot := UiKit.label("Made with Godot Engine. (c) Godot Engine contributors, MIT license.", 11, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
	godot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	godot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	godot.offset_right = -10
	godot.offset_top = -24
	add_child(godot)

	Cloud.status_changed.connect(_refresh_badge)
	Save.changed.connect(_refresh_badge)
	_refresh_badge()
	UiKit.focus_first(col)


func _refresh_badge() -> void:
	if CloudSync.signed_in():
		var name: String = Save.username()
		_badge.text = "Signed in: " + (name if name != "" else "signed in")
		_badge.add_theme_color_override("font_color", UiKit.GOOD)
	else:
		_badge.text = "Not signed in"
		_badge.add_theme_color_override("font_color", UiKit.MUTED)


func _on_quit() -> void:
	if not AppActions.quit(get_tree()):
		_quit_note.text = "You can close this tab now."
