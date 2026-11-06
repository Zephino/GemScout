class_name Bullet
extends Node2D
## A blaster shot. Flies straight; stops at rock, closed doors and
## Bouldermaws; hits the first enemy it touches (Power shot goes through
## enemies and breaks a Bouldermaw at once).

const SPEED := 360.0
const LIFE_S := 0.9

var level: CaveLevel
var dir: float = 1.0
var power: bool = false
var _life: float = LIFE_S
var _hit: Array[Node] = []


func _physics_process(delta: float) -> void:
	_life -= delta
	var steps: int = 3
	for i in steps:
		position.x += dir * SPEED * delta / steps
		if _check():
			queue_free()
			return
	if _life <= 0.0:
		queue_free()


## True when the shot stops here.
func _check() -> bool:
	for b in level.boulders:
		if is_instance_valid(b) and b.blocks(position):
			b.hit(power)
			return true
	if level.is_blocked(position):
		return true
	for e in level.enemies_alive():
		if _hit.has(e):
			continue
		if e.body_center().distance_to(position) <= e.radius + 3.0:
			e.hit(power)
			_hit.append(e)
			if not power:
				return true
	return false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c: Color = Color8(255, 160, 60) if power else Color8(120, 230, 255)
	draw_line(Vector2(-dir * 6.0, 0), Vector2.ZERO, Color(c, 0.4), 4.0)
	draw_circle(Vector2.ZERO, 2.5, c)
	draw_circle(Vector2.ZERO, 1.2, Color.WHITE)
