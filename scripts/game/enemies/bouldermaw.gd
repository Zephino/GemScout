class_name Bouldermaw
extends Node2D
## A slow rock creature wedged across a tunnel. It's solid (it blocks the
## way but doesn't bite) and takes 3 shots, or 1 with Power shot. There are
## never more than 2 in a cave, and an empty blaster recharges, so the way
## through can always be opened.

var level: CaveLevel
var rect := Rect2()
var hp: int = 3
var alive: bool = true
var _body: StaticBody2D
var _flash: float = 0.0
var _time: float = 0.0


func setup(cells: Rect2i) -> void:
	rect = Rect2(Vector2(cells.position) * CaveData.CELL_SIZE, Vector2(cells.size) * CaveData.CELL_SIZE)


func _ready() -> void:
	_body = StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.get_center()
	_body.add_child(collider)
	add_child(_body)


func blocks(point: Vector2) -> bool:
	return alive and rect.grow(2).has_point(point)


func hit(power: bool) -> void:
	if not alive:
		return
	hp -= 3 if power else 1
	_flash = 0.15
	queue_redraw()
	if hp <= 0:
		alive = false
		_body.queue_free()
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _draw() -> void:
	var base := Color8(110, 96, 82) if _flash <= 0.0 else Color8(240, 230, 220)
	var r: Rect2 = rect.grow(1)
	# A lumpy rock body filling the tunnel.
	draw_rect(r, base)
	for i in int(r.size.y / 6.0):
		var y: float = r.position.y + 3.0 + i * 6.0
		draw_circle(Vector2(r.position.x + 2.0 + fmod(i * 3.7, 4.0), y), 3.0, base.darkened(0.2))
	draw_rect(r, Color8(26, 20, 32), false, 1.5)
	# Eyes and a grinding maw, looking at the scout.
	var look: float = 1.0
	if level != null and level.hero != null:
		look = 1.0 if level.hero.position.x > rect.get_center().x else -1.0
	var c: Vector2 = rect.get_center() + Vector2(look * 2.0, -6.0)
	draw_circle(c + Vector2(-3, 0), 2.0, Color8(255, 210, 80))
	draw_circle(c + Vector2(3, 0), 2.0, Color8(255, 210, 80))
	var jaw: float = 2.0 + 1.5 * sin(_time * 3.0)
	draw_rect(Rect2(c + Vector2(-5, 6), Vector2(10, jaw + 2)), Color8(40, 20, 24))
	for k in 3:
		draw_rect(Rect2(c + Vector2(-4 + k * 3, 6), Vector2(2, 2)), Color8(240, 240, 230))
	# Cracks show the damage.
	for k in 3 - hp:
		var x: float = r.position.x + 4.0 + k * 4.0
		draw_line(Vector2(x, r.position.y + 2), Vector2(x + 3, r.end.y - 2), Color8(40, 30, 30), 1.0)
