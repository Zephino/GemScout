class_name TouchControls
extends CanvasLayer
## On-screen buttons for phones and tablets. They press the same actions as
## the keyboard and controller (GameInput), and support several fingers at
## once (run and jump together); sliding a finger between left and right
## switches direction.
##
## Two layouts, picked automatically when the phone is turned:
##   landscape  see-through buttons over the game: move bottom-left, jump
##              bottom-right; the camera keeps the scout above them
##   portrait   the game on top and a solid control panel below it, so
##              the buttons never cover the cave
## Shown on touch screens only (Settings → Touch controls: Auto / On / Off).

signal layout_changed

const ALPHA := 0.38
const PANEL_SHARE := 0.30

var portrait: bool = false
var shown: bool = false
## Buttons: {action, center (Vector2), radius, icon}.
var buttons: Array = []
## Touch index → action held by that finger.
var _held: Dictionary = {}
var _panel_h: float = 0.0
var _pad: Control


func _ready() -> void:
	layer = 5
	_pad = Control.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	get_viewport().size_changed.connect(_layout)
	_layout()


## True when the buttons should show (setting, or a touch screen on Auto).
static func wanted(mode: String) -> bool:
	if mode == "on":
		return true
	if mode == "off":
		return false
	return DisplayServer.is_touchscreen_available()


func set_shown(value: bool) -> void:
	shown = value
	_pad.visible = value
	if not value:
		release_all()
	_layout()


## Height of the solid panel at the bottom (portrait only), in screen pixels.
func panel_height() -> float:
	return _panel_h if shown and portrait else 0.0


## How far up the camera should move the scout, in screen pixels.
func view_shift() -> float:
	if not shown:
		return 0.0
	if portrait:
		return _panel_h / 2.0
	return buttons[0]["radius"] * 0.7 if not buttons.is_empty() else 0.0


func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	portrait = vp.y > vp.x * 1.05
	buttons.clear()
	if portrait:
		_panel_h = vp.y * PANEL_SHARE
		var r: float = minf(_panel_h * 0.26, vp.x * 0.11)
		var cy: float = vp.y - _panel_h / 2.0
		buttons.append({"action": "move_left", "center": Vector2(vp.x * 0.16, cy), "radius": r, "icon": "left"})
		buttons.append({"action": "move_right", "center": Vector2(vp.x * 0.16 + r * 2.5, cy), "radius": r, "icon": "right"})
		buttons.append({"action": "jump", "center": Vector2(vp.x * 0.80, cy), "radius": r * 1.15, "icon": "up"})
	else:
		_panel_h = 0.0
		var r: float = clampf(vp.y * 0.11, 30.0, 52.0)
		var m: float = r * 0.45
		var cy: float = vp.y - m - r
		buttons.append({"action": "move_left", "center": Vector2(m + r, cy), "radius": r, "icon": "left"})
		buttons.append({"action": "move_right", "center": Vector2(m + r * 3.3, cy), "radius": r, "icon": "right"})
		buttons.append({"action": "jump", "center": Vector2(vp.x - m - r * 1.1, cy), "radius": r * 1.1, "icon": "up"})
	_pad.queue_redraw()
	layout_changed.emit()


func _button_at(pos: Vector2) -> String:
	for b: Dictionary in buttons:
		# A generous hit area: fingers are bigger than the drawing.
		if pos.distance_to(b["center"]) <= b["radius"] * 1.35:
			return b["action"]
	return ""


func _input(event: InputEvent) -> void:
	if not shown:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			var action: String = _button_at(touch.position)
			if action != "":
				_hold(touch.index, action)
				get_viewport().set_input_as_handled()
			elif portrait and touch.position.y > get_viewport().get_visible_rect().size.y - _panel_h:
				get_viewport().set_input_as_handled()
		else:
			if _held.has(touch.index):
				_release(touch.index)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if not _held.has(drag.index):
			return
		var action: String = _button_at(drag.position)
		# Slide between left and right; jump stays held until the finger lifts.
		if action != "" and action != _held[drag.index] and _held[drag.index] != "jump":
			_release(drag.index)
			_hold(drag.index, action)
		get_viewport().set_input_as_handled()


func _hold(index: int, action: String) -> void:
	_held[index] = action
	Input.action_press(action)
	_pad.queue_redraw()


func _release(index: int) -> void:
	var action: String = _held[index]
	_held.erase(index)
	if not _held.values().has(action):
		Input.action_release(action)
	_pad.queue_redraw()


func release_all() -> void:
	for index: int in _held.keys():
		_release(index)


func _draw_pad() -> void:
	if not shown:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if portrait:
		_pad.draw_rect(Rect2(0, vp.y - _panel_h, vp.x, _panel_h), Color8(20, 16, 28))
		_pad.draw_line(Vector2(0, vp.y - _panel_h), Vector2(vp.x, vp.y - _panel_h), Color8(90, 76, 118), 2.0)
	var held: Array = _held.values()
	for b: Dictionary in buttons:
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var on: bool = held.has(b["action"])
		var alpha: float = 1.0 if portrait else ALPHA
		_pad.draw_circle(c, r, Color(0.35, 0.28, 0.5, alpha * (0.95 if on else 0.6)))
		_pad.draw_arc(c, r, 0, TAU, 40, Color(0.95, 0.9, 0.85, alpha * 0.9), 2.5)
		var s: float = r * 0.45
		var pts: PackedVector2Array
		match b["icon"]:
			"left":
				pts = PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s * 0.6, -s), c + Vector2(s * 0.6, s)])
			"right":
				pts = PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.6, -s), c + Vector2(-s * 0.6, s)])
			_:
				pts = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.6), c + Vector2(-s, s * 0.6)])
		_pad.draw_colored_polygon(pts, Color(1, 0.97, 0.9, minf(1.0, alpha + 0.35)))
