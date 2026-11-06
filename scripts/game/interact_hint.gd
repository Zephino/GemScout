class_name InteractHint
extends RefCounted
## The little bobbing arrow shown over a lever or switch you can use.


static func draw_on(node: CanvasItem, at: Vector2, time: float) -> void:
	var p: Vector2 = at + Vector2(0, sin(time * 5.0) * 2.0)
	node.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -4), p + Vector2(4, -4), p + Vector2(0, 1)]), Color8(255, 230, 120))
	node.draw_polyline(PackedVector2Array([p + Vector2(-4, -4), p + Vector2(4, -4), p + Vector2(0, 1), p + Vector2(-4, -4)]), Color8(26, 20, 32), 1.0)
