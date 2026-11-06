class_name Hud
extends CanvasLayer
## What's shown while playing: gems found, the time, a pause button (handy
## on phones), and short messages ("The exit is open!").

signal pause_pressed

var _gems: Label
var _time: Label
var _toast: Label
var _toast_left: float = 0.0
var _level: CaveLevel


func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.theme = UiKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 6
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	var gem_icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/gems.png")
	atlas.region = Rect2(0, 0, 12, 12)
	gem_icon.texture = atlas
	gem_icon.custom_minimum_size = Vector2(24, 24)
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.add_child(gem_icon)
	_gems = _outlined("0 / 0", 20)
	bar.add_child(_gems)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	_time = _outlined("0:00.0", 20)
	bar.add_child(_time)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(12, 0)
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer2)
	var pause := UiKit.button("II", func() -> void: pause_pressed.emit(), 44)
	pause.focus_mode = Control.FOCUS_NONE
	pause.tooltip_text = "Pause (Esc)"
	bar.add_child(pause)

	_toast = _outlined("", 18)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 52
	_toast.offset_bottom = 84
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", UiKit.GOLD)
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func _outlined(text: String, size: int) -> Label:
	var l := UiKit.label(text, size, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_outline_color", Color8(10, 8, 14))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func watch(level: CaveLevel) -> void:
	_level = level
	level.gems_changed.connect(func(c: int, t: int) -> void: _gems.text = "%d / %d" % [c, t])
	level.message.connect(show_message)
	_gems.text = "%d / %d" % [level.collected, level.total]


func show_message(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = 3.0


func _process(delta: float) -> void:
	if _level != null:
		_time.text = Scoring.format_time(_level.time_ms)
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left, 0.0, 1.0)
