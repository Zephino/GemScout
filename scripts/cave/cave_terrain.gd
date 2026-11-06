class_name CaveTerrain
extends Node2D
## Draws a cave's smooth rock (CaveShape) and makes it solid: one mesh for
## the rock, a lighter rim along every edge, a few glinting minerals, and a
## StaticBody2D whose collision is exactly the drawn edges.

const BACK_WALL := Color8(28, 22, 38)
const RIM := Color8(176, 156, 206)
const MINERALS: Array[Color] = [Color8(230, 60, 90), Color8(60, 210, 120), Color8(70, 140, 250), Color8(250, 200, 50)]

var cave: CaveData
var shape: CaveShape
var _mesh: ArrayMesh
var _specks: Array = []


func setup(c: CaveData, s: CaveShape = null) -> void:
	cave = c
	shape = s if s != null else CaveShape.new(c)
	_build_mesh()
	_build_collision()
	_place_specks()
	queue_redraw()


func _build_mesh() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = shape.triangles
	arrays[Mesh.ARRAY_COLOR] = shape.colors
	_mesh = ArrayMesh.new()
	if shape.triangles.size() >= 3:
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Rock"
	var collider := CollisionShape2D.new()
	var concave := ConcavePolygonShape2D.new()
	concave.segments = shape.segments
	collider.shape = concave
	body.add_child(collider)
	add_child(body)


## Tiny coloured glints inside the rock, near its surface.
func _place_specks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cave.seed, "specks"])
	var size: Vector2 = cave.pixel_size()
	var tries: int = 0
	while _specks.size() < 220 and tries < 6000:
		tries += 1
		var p := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		var v: float = shape.value_at(p.x / CaveData.CELL_SIZE, p.y / CaveData.CELL_SIZE)
		if v > 0.62 and v < 0.95:
			_specks.append([p.floor(), MINERALS[rng.randi_range(0, MINERALS.size() - 1)].darkened(rng.randf_range(0.2, 0.55))])


func _draw() -> void:
	if cave == null:
		return
	draw_rect(Rect2(Vector2.ZERO, cave.pixel_size()), BACK_WALL)
	if _mesh != null:
		draw_mesh(_mesh, null)
	draw_multiline(shape.segments, RIM, 1.5)
	for s: Array in _specks:
		draw_rect(Rect2(s[0], Vector2(2, 2)), s[1])
