class_name Dripjaw
extends Enemy
## Looks like a stalactite. When the scout walks underneath it drops, waits
## on the floor a moment, then climbs back up. One shot, or dodge it.

const DROP_TRIGGER_X := 14.0
const FALL_ACCEL := 900.0
const CLIMB_SPEED := 40.0

var top_y: float = 0.0
var floor_y: float = 0.0
var state: String = "hang"
var _speed: float = 0.0
var _wait: float = 0.0


func setup(data: Dictionary) -> void:
	var c: Vector2i = data["cell"]
	top_y = (c.y + 1) * CaveData.CELL_SIZE + 6.0
	floor_y = float(data["floor_y"]) - 7.0
	position = Vector2((c.x + 1) * CaveData.CELL_SIZE, top_y)
	radius = 6.0


func _ready() -> void:
	_make_sprite(4)


func tick(delta: float) -> void:
	match state:
		"hang":
			sprite.frame = 4
			var hero: Hero = level.hero
			if hero != null and absf(hero.position.x - position.x) < DROP_TRIGGER_X and hero.position.y > position.y:
				state = "drop"
				_speed = 0.0
		"drop":
			sprite.frame = 5
			_speed += FALL_ACCEL * delta
			position.y = minf(position.y + _speed * delta, floor_y)
			if position.y >= floor_y:
				state = "wait"
				_wait = 1.2
		"wait":
			_wait -= delta
			if _wait <= 0.0:
				state = "climb"
		"climb":
			sprite.frame = 4
			position.y = maxf(top_y, position.y - CLIMB_SPEED * delta)
			if position.y <= top_y:
				state = "hang"
