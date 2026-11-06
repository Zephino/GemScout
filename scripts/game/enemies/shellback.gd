class_name Shellback
extends Enemy
## An armoured cave beetle that patrols a stretch of floor, turning at the
## ends. One shot; jump over it or shoot it.

const SPEED := 30.0

var from_x: float = 0.0
var to_x: float = 0.0
var dir: float = 1.0


func setup(data: Dictionary) -> void:
	from_x = (data["from_x"] + 1) * CaveData.CELL_SIZE
	to_x = (data["to_x"] + 1) * CaveData.CELL_SIZE
	var c: Vector2i = data["cell"]
	position = CaveData.feet_position(c)
	radius = 7.0


func _ready() -> void:
	_make_sprite(0)
	sprite.position = Vector2(0, -8)


func body_center() -> Vector2:
	return position + Vector2(0, -6)


func tick(delta: float) -> void:
	position.x += dir * SPEED * delta
	if position.x >= to_x:
		position.x = to_x
		dir = -1.0
	elif position.x <= from_x:
		position.x = from_x
		dir = 1.0
	position.y = level.floor_y_at(position.x, position.y)
	sprite.flip_h = dir < 0.0
	sprite.frame = int(time * 6.0) % 2
