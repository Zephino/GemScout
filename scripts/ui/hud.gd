class_name Hud
extends CanvasLayer
## What's shown while playing: gems found, hearts, the blaster's ammo,
## active power-ups, the time, a pause button (handy on phones), and short
## messages ("The exit is open!").

signal pause_pressed

var _gems: Label
var _time: Label
var _toast: Label
var _toast_left: float = 0.0
var _level: CaveLevel
var _hearts: HBoxContainer
var _ammo: Label
var _powers: Label
var _recharge: ProgressBar


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
	# The blue gem, so it can't be mistaken for the hearts next to it.
	atlas.region = Rect2(24, 0, 12, 12)
	gem_icon.texture = atlas
	gem_icon.custom_minimum_size = Vector2(24, 24)
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.add_child(gem_icon)
	_gems = _outlined("0 / 0", 20)
	bar.add_child(_gems)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 2)
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_hearts)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(10, 0)
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap2)
	bar.add_child(_item_icon(3))
	var ammo_box := VBoxContainer.new()
	ammo_box.add_theme_constant_override("separation", 0)
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo = _outlined("6", 20)
	ammo_box.add_child(_ammo)
	_recharge = ProgressBar.new()
	_recharge.show_percentage = false
	_recharge.custom_minimum_size = Vector2(28, 4)
	_recharge.max_value = 1.0
	_recharge.visible = false
	_recharge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_box.add_child(_recharge)
	bar.add_child(ammo_box)

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

	_powers = _outlined("", 15)
	_powers.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_powers.offset_top = 36
	_powers.offset_bottom = 56
	_powers.offset_left = 12
	_powers.add_theme_color_override("font_color", Color8(180, 230, 255))
	root.add_child(_powers)

	_toast = _outlined("", 18)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 52
	_toast.offset_bottom = 84
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", UiKit.GOLD)
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func _item_icon(frame: int) -> TextureRect:
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/items.png")
	atlas.region = Rect2(frame * 12, 0, 12, 12)
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(22, 22)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _show_hearts(current: int, most: int) -> void:
	for c in _hearts.get_children():
		c.queue_free()
	for i in most:
		_hearts.add_child(_item_icon(0 if i < current else 1))


func _show_ammo(ammo: int) -> void:
	_ammo.text = "free" if ammo < 0 else str(ammo)
	_ammo.add_theme_color_override("font_color", UiKit.BAD if ammo == 0 else UiKit.TEXT)


func _show_powers() -> void:
	var parts: Array[String] = []
	if _level.power_shot_left > 0.0:
		parts.append("Power shot %ds" % ceili(_level.power_shot_left))
	if _level.gravity_left > 0.0:
		parts.append("Reverse gravity %ds" % ceili(_level.gravity_left))
	if _level.freeze_left > 0.0:
		parts.append("Freeze %ds" % ceili(_level.freeze_left))
	if _level.hero != null and _level.hero.shielded:
		parts.append("Shield")
	_powers.text = "   ".join(parts)


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
	level.hearts_changed.connect(_show_hearts)
	level.ammo_changed.connect(_show_ammo)
	level.powers_changed.connect(_show_powers)
	_gems.text = "%d / %d" % [level.collected, level.total]
	_show_hearts(level.hearts, level.max_hearts)
	_show_ammo(level.ammo)
	_show_powers()


func show_message(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = 3.0


func _process(delta: float) -> void:
	if _level != null:
		_time.text = Scoring.format_time(_level.time_ms)
		var p: float = _level.recharge_progress()
		_recharge.visible = _level.ammo == 0
		_recharge.value = p
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left, 0.0, 1.0)
