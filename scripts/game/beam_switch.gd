class_name BeamSwitch
extends Node2D
## Turns its crystal beam off and on (interact).

const ITEMS := preload("res://assets/sprites/items.png")

var beam: CrystalBeam
var near: bool = false
var _sprite: Sprite2D
var _time: float = 0.0


func setup(cell: Vector2i, for_beam: CrystalBeam) -> void:
	position = CaveData.feet_position(cell)
	beam = for_beam


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = ITEMS
	_sprite.hframes = 12
	_sprite.frame = 10
	_sprite.position = Vector2(0, -12)
	add_child(_sprite)


func toggle() -> void:
	beam.on = not beam.on
	_sprite.frame = 10 if beam.on else 11


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if near:
		InteractHint.draw_on(self, Vector2(0, -24), _time)
