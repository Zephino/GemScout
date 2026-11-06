class_name Pickup
extends Node2D
## Something to pick up: a heart, an ammo crate, or a power-up orb.

const ITEMS := preload("res://assets/sprites/items.png")
const FRAMES := {"heart": 0, "ammo": 2, "power_shot": 4, "gravity": 5, "freeze": 6, "shield": 7}
const NAMES := {"heart": "Heart", "ammo": "Ammo", "power_shot": "Power shot", "gravity": "Reverse gravity", "freeze": "Freeze", "shield": "Shield"}

var type: String = ""
var _sprite: Sprite2D
var _time: float = 0.0


func setup(kind: String, cell: Vector2i) -> void:
	type = kind
	position = CaveData.feet_position(cell) - Vector2(0, 10)
	_time = position.x


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = ITEMS
	_sprite.hframes = 12
	_sprite.frame = FRAMES[type]
	add_child(_sprite)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = sin(_time * 2.5) * 1.5
	queue_redraw()


func _draw() -> void:
	if type != "ammo":
		draw_circle(Vector2(0, _sprite.position.y), 10.0, Color(1, 1, 1, 0.08 + 0.05 * sin(_time * 4.0)))


func take() -> void:
	set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
