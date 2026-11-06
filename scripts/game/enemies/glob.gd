class_name Glob
extends Enemy
## A Spitter's glob: flies straight until it hits rock (or after a while).
## Touching it costs a heart; it can be shot.

var velocity := Vector2.ZERO
var _life: float = 4.0


func _ready() -> void:
	_make_sprite(8)
	radius = 4.0


func tick(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0 or level.is_blocked(position):
		alive = false
		queue_free()


func die() -> void:
	alive = false
	queue_free()
