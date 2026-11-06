class_name Lever
extends Node2D
## Pull it (interact) to open every door of the same colour.

const ITEMS := preload("res://assets/sprites/items.png")

var color: int = 0
var pulled: bool = false
var near: bool = false
var _sprite: Sprite2D
var _time: float = 0.0


func setup(color_index: int, cell: Vector2i) -> void:
	color = color_index
	position = CaveData.feet_position(cell)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = ITEMS
	_sprite.hframes = 12
	_sprite.frame = 8
	_sprite.position = Vector2(0, -6)
	_sprite.modulate = GateDoor.COLORS[color].lightened(0.2)
	add_child(_sprite)


func pull() -> bool:
	if pulled:
		return false
	pulled = true
	_sprite.frame = 9
	return true


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if near and not pulled:
		InteractHint.draw_on(self, Vector2(0, -20), _time)
