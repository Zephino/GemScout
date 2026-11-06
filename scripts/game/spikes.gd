class_name Spikes
extends Node2D
## Every spike strip in the cave: rows of sharp crystals on the floor.
## Touching them costs a heart.

var rects: Array[Rect2] = []


func setup(cells: Array[Rect2i]) -> void:
	for c in cells:
		# The hurting part: the bottom 5 pixels of the cell above the floor.
		var r := Rect2(Vector2(c.position) * CaveData.CELL_SIZE, Vector2(c.size) * CaveData.CELL_SIZE)
		rects.append(Rect2(r.position.x, r.end.y - 5.0, r.size.x, 5.0))
	queue_redraw()


func hurts(body: Rect2) -> bool:
	for r in rects:
		if r.intersects(body):
			return true
	return false


func _draw() -> void:
	for r in rects:
		var n: int = int(r.size.x / 4.0)
		for i in n:
			var x: float = r.position.x + i * 4.0
			var base: float = r.end.y + 1.0
			var tri := PackedVector2Array([Vector2(x, base), Vector2(x + 4.0, base), Vector2(x + 2.0, base - 7.0)])
			draw_colored_polygon(tri, Color8(210, 215, 230))
			draw_line(Vector2(x + 2.0, base - 7.0), Vector2(x + 3.5, base), Color8(120, 120, 150), 1.0)
