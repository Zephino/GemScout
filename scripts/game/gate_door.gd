class_name GateDoor
extends Node2D
## A coloured door across a tunnel (red, blue or yellow). Solid until its
## lever of the same colour is pulled; then it slides up into the rock.

const COLORS: Array[Color] = [Color8(230, 60, 70), Color8(70, 130, 245), Color8(245, 200, 50)]
const NAMES: Array[String] = ["red", "blue", "yellow"]

var color: int = 0
var rect := Rect2()
var is_open: bool = false
var _body: StaticBody2D
var _slide: float = 0.0


func setup(color_index: int, cells: Rect2i) -> void:
	color = color_index
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
	return not is_open and rect.has_point(point)


func open() -> void:
	if is_open:
		return
	is_open = true
	_body.queue_free()
	var tween := create_tween()
	tween.tween_property(self, "_slide", 1.0, 0.6).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, 0.6)


func _draw() -> void:
	var c: Color = COLORS[color]
	var h: float = rect.size.y * (1.0 - _slide)
	if h <= 0.5:
		return
	var r := Rect2(rect.position, Vector2(rect.size.x, h))
	draw_rect(r, c.darkened(0.45))
	for i in 3:
		var x: float = r.position.x + 2.0 + i * (r.size.x - 4.0) / 2.0
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), c, 2.0)
	draw_rect(r, Color8(26, 20, 32), false, 1.0)
	# A small lock in the door's colour.
	var lock := Vector2(rect.get_center().x, r.end.y - 10.0)
	if h > 14.0:
		draw_circle(lock, 3.5, c.lightened(0.3))
		draw_circle(lock, 1.2, Color8(26, 20, 32))
