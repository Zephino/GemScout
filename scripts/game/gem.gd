class_name Gem
extends Area2D
## A gem to collect. Bobs gently with a soft glow; when the scout touches it,
## it pops and tells the level.

signal collected(gem: Gem)

const COLOURS: Array[Color] = [Color8(230, 40, 70), Color8(40, 200, 90), Color8(50, 120, 240), Color8(245, 190, 30), Color8(160, 70, 220)]

var kind: int = 0
var _sprite: Sprite2D
var _time: float = 0.0
var _taken: bool = false


func setup(at: Vector2, gem_kind: int) -> void:
	position = at
	kind = gem_kind
	_time = at.x * 0.05


func _ready() -> void:
	monitoring = true
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/gems.png")
	_sprite.hframes = 5
	_sprite.frame = kind
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	_sprite.position.y = sin(_time * 3.0) * 1.5
	queue_redraw()


func _draw() -> void:
	if _taken:
		return
	var glow: Color = COLOURS[kind]
	glow.a = 0.18 + 0.08 * sin(_time * 4.0)
	draw_circle(Vector2(0, _sprite.position.y), 10.0, glow)


func _on_body_entered(body: Node) -> void:
	if _taken or not body is Hero:
		return
	_taken = true
	set_deferred("monitoring", false)
	collected.emit(self)
	queue_redraw()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(2.2, 2.2), 0.25)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
