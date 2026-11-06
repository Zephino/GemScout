class_name CrystalBeam
extends Node2D
## A beam of light between two crystals, across a tunnel. While it's on,
## touching it costs a heart; its switch turns it off (and on again).

var rect := Rect2()
var on: bool = true
var _time: float = 0.0


func setup(cells: Rect2i) -> void:
	rect = Rect2(Vector2(cells.position) * CaveData.CELL_SIZE, Vector2(cells.size) * CaveData.CELL_SIZE)


## The part that hurts: a thin band down the middle.
func hurts(body: Rect2) -> bool:
	if not on:
		return false
	var core := Rect2(rect.get_center().x - 3.0, rect.position.y, 6.0, rect.size.y)
	return core.intersects(body)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var x: float = rect.get_center().x
	var top := Vector2(x, rect.position.y + 3.0)
	var bottom := Vector2(x, rect.end.y - 3.0)
	# The two crystals.
	for p: Vector2 in [top, bottom]:
		var s: float = -1.0 if p == top else 1.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -3 * s), p + Vector2(4, -3 * s), p + Vector2(0, 4 * s)]), Color8(120, 230, 255) if on else Color8(70, 90, 110))
	if on:
		var w: float = 2.5 + sin(_time * 18.0) * 0.8
		draw_line(top, bottom, Color(0.5, 0.95, 1.0, 0.35), w * 3.0)
		draw_line(top, bottom, Color(0.9, 1.0, 1.0, 0.95), w)
