class_name Enemy
extends Node2D
## What every enemy shares: hit points, a round body that hurts the scout on
## touch, getting shot, and stopping while Freeze is on. Each kind moves in
## its own script.

const SHEET := preload("res://assets/sprites/enemies.png")

var level: CaveLevel
var hp: int = 1
## Touch radius in pixels, around body_center().
var radius: float = 6.0
var alive: bool = true
var sprite: Sprite2D
var time: float = 0.0
var _flash: float = 0.0


func _make_sprite(frame: int) -> void:
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 9
	sprite.frame = frame
	add_child(sprite)


func frozen() -> bool:
	return level != null and level.freeze_left > 0.0


func body_center() -> Vector2:
	return position


## True when this enemy is touching a point (the scout's middle).
func touches(point: Vector2, extra: float = 7.0) -> bool:
	return alive and not frozen() and body_center().distance_to(point) <= radius + extra


## Shot. `power` is true with Power shot (counts as three hits).
func hit(power: bool) -> void:
	if not alive:
		return
	hp -= 3 if power else 1
	_flash = 0.12
	if hp <= 0:
		die()


func die() -> void:
	alive = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 0.2), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if not alive:
		return
	_flash = maxf(0.0, _flash - delta)
	modulate = Color(3, 3, 3) if _flash > 0.0 else (Color(0.6, 0.85, 1.3) if frozen() else Color.WHITE)
	if frozen():
		return
	time += delta
	tick(delta)


## Each kind's movement (not called while frozen or dead).
func tick(_delta: float) -> void:
	pass
