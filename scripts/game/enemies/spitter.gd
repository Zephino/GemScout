class_name Spitter
extends Enemy
## A pod growing on a wall. Every few seconds it opens and spits a slow
## glob across the tunnel. One shot.

const EVERY_S := 2.8
const GLOB_SPEED := 85.0

var dir: int = 1
var _next: float = 1.5


func setup(data: Dictionary) -> void:
	var c: Vector2i = data["cell"]
	dir = data["dir"]
	# Sits against the wall cell, facing into the tunnel.
	position = Vector2((c.x + (1.0 if dir == 1 else 0.0)) * CaveData.CELL_SIZE + dir * 5.0, (c.y + 0.5) * CaveData.CELL_SIZE)
	radius = 6.0


func _ready() -> void:
	_make_sprite(6)
	sprite.flip_h = dir < 0
	_next = 1.0 + fmod(position.x, 1.5)


func tick(delta: float) -> void:
	_next -= delta
	sprite.frame = 7 if _next < 0.35 else 6
	if _next <= 0.0:
		_next = EVERY_S
		var glob := Glob.new()
		glob.level = level
		glob.velocity = Vector2(GLOB_SPEED * dir, 0)
		glob.position = position + Vector2(dir * 8.0, 0)
		level.add_child(glob)
