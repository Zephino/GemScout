class_name UiKit
extends RefCounted
## GemScout's look for menus: big readable text, chunky buttons that are easy
## to tap on a phone, and helpers to build screens in a few lines.

const TEXT := Color8(242, 234, 216)
const MUTED := Color8(170, 160, 186)
const GOLD := Color8(240, 200, 90)
const GOOD := Color8(110, 220, 140)
const BAD := Color8(255, 120, 120)
const PANEL := Color8(30, 24, 42, 240)
const BUTTON := Color8(64, 52, 90)
const BUTTON_HOVER := Color8(88, 72, 122)
const BUTTON_PRESSED := Color8(124, 100, 168)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	for kind: String in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", kind, _box(BUTTON, 2, Color8(110, 94, 140)))
		t.set_stylebox("hover", kind, _box(BUTTON_HOVER, 2, Color8(150, 130, 190)))
		t.set_stylebox("pressed", kind, _box(BUTTON_PRESSED, 2, GOLD))
		t.set_stylebox("disabled", kind, _box(Color8(44, 38, 56), 2, Color8(70, 62, 84)))
		t.set_stylebox("focus", kind, _outline(GOLD))
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_focus_color", kind, Color.WHITE)
		t.set_color("font_disabled_color", kind, Color8(120, 112, 134))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 2, Color8(90, 76, 118), 14))
	for kind: String in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", kind, _box(Color8(18, 14, 26), 2, Color8(90, 76, 118)))
		t.set_stylebox("focus", kind, _outline(GOLD))
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_placeholder_color", kind, Color8(120, 112, 134))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	_theme = t
	return t


static func _box(color: Color, border: int, border_color: Color, padding: int = 10) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_border_width_all(border)
	b.border_color = border_color
	b.set_corner_radius_all(8)
	b.content_margin_left = padding + 4
	b.content_margin_right = padding + 4
	b.content_margin_top = padding - 2
	b.content_margin_bottom = padding - 2
	return b


static func _outline(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.draw_center = false
	b.set_border_width_all(3)
	b.border_color = color
	b.set_corner_radius_all(8)
	b.expand_margin_left = 2
	b.expand_margin_right = 2
	b.expand_margin_top = 2
	b.expand_margin_bottom = 2
	return b


## A label. Long text wraps to the width it's given; pass wrap = false for
## titles and short lines so they never break mid-word.
static func label(text: String, size: int = 16, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable, min_width: float = 220.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 38)
	b.pressed.connect(on_press)
	return b


## A full-screen screen: dark backdrop, a centred panel with a scrolling
## column. Returns [root, column].
static func screen(title: String, max_width: float = 460.0) -> Array:
	var root := Control.new()
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color8(12, 9, 18, 235)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	root.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(max_width, 600), 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(minf(max_width, 600) - 28, 0)
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	if title != "":
		column.add_child(label(title, 28, GOLD, HORIZONTAL_ALIGNMENT_CENTER, false))
	# Keep the panel inside the screen: the scroll area takes what's left.
	root.resized.connect(func() -> void:
		var h: float = root.size.y - 48
		scroll.custom_minimum_size.y = minf(h, column.get_combined_minimum_size().y)
		panel.custom_minimum_size.x = minf(max_width, root.size.x - 24)
		scroll.custom_minimum_size.x = panel.custom_minimum_size.x - 28)
	column.resized.connect(func() -> void:
		scroll.custom_minimum_size.y = minf(root.size.y - 48, column.get_combined_minimum_size().y))
	return [root, column]


## Screens are built by small helper objects (ResultsScreen, SettingsScreen…)
## and only their `root` is put on screen. The helper must live as long as
## the screen, or its buttons silently stop working (Godot drops the
## connections of a freed object; this was the "Send score does nothing"
## bug). Keeping it on the root ties their lives together.
static func keep_alive(root: Control, helper: RefCounted) -> void:
	root.set_meta("screen_helper", helper)


## Focus the first button so keyboards and controllers can use the menu.
static func focus_first(node: Node) -> void:
	for child in node.find_children("*", "Button", true, false):
		var b: Button = child
		if b.visible and not b.disabled:
			b.call_deferred("grab_focus")
			return
