class_name Glowmoth
extends Enemy
## A pale moth that drifts in a slow figure-eight through open air,
## glowing softly. One shot.

var center := Vector2.ZERO


func setup(data: Dictionary) -> void:
	center = data["center"]
	position = center
	radius = 6.0


func _ready() -> void:
	_make_sprite(2)
	time = center.x * 0.01


func tick(_delta: float) -> void:
	position = center + Vector2(sin(time * 0.8) * 26.0, sin(time * 1.6) * 12.0)
	sprite.frame = 2 + int(time * 8.0) % 2
	queue_redraw()


func _draw() -> void:
	if alive:
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.95, 0.6, 0.12 + 0.05 * sin(time * 5.0)))
