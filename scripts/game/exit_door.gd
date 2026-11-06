class_name ExitDoor
extends Area2D
## The way out. Sealed until every gem is collected; then it opens and the
## scout can walk in to finish the cave.

signal entered
signal bumped_locked

var is_open: bool = false
var _sprite: Sprite2D
var _glow: float = 0.0


func _ready() -> void:
	monitoring = true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 26)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, -13)
	add_child(collider)
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/door.png")
	_sprite.hframes = 2
	_sprite.position = Vector2(0, -16)
	add_child(_sprite)
	z_index = -1
	body_entered.connect(_on_body_entered)


func open() -> void:
	if is_open:
		return
	is_open = true
	_sprite.frame = 1
	var tween := create_tween()
	_sprite.scale = Vector2(1.25, 1.25)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	# Already standing in the doorway? Then that counts.
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _process(delta: float) -> void:
	if is_open:
		_glow += delta
		queue_redraw()


func _draw() -> void:
	if is_open:
		draw_circle(Vector2(0, -14), 20.0, Color(0.3, 1.0, 0.6, 0.12 + 0.06 * sin(_glow * 3.0)))


func _on_body_entered(body: Node) -> void:
	if not body is Hero:
		return
	if is_open:
		entered.emit()
	else:
		bumped_locked.emit()
