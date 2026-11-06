class_name CaveShape
extends RefCounted
## Turns a cave's rock cells into smooth, natural-looking rock (no square
## tiles): the cells are blurred into a "rockiness" field, a little noise
## makes the edges wobble, and marching squares traces where the field
## crosses 0.5. The result is triangles to draw and edge segments to
## collide with, so what you see is what you stand on.
##
## Straight walls stay where the cells say (the blur crosses 0.5 on the
## cell edge); corners get rounded, and the noise moves edges by well under
## half a cell, which Reachability's cautious body box allows for.

## Sub-steps per cell (4 px with 8 px cells): smaller = smoother, slower.
const SUB := 2
## How far the noise can push the field (0.5 is the edge).
const WOBBLE := 0.12

var cave: CaveData
## Triangles of rock, in pixels (every three points are one triangle).
var triangles := PackedVector2Array()
## Colour for each triangle point.
var colors := PackedColorArray()
## Rock edges, in pixels (every two points are one segment).
var segments := PackedVector2Array()

var _blur := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _shade := FastNoiseLite.new()
var _gw: int = 0
var _gh: int = 0
var _field := PackedFloat32Array()


func _init(c: CaveData) -> void:
	cave = c
	_noise.seed = c.seed % 1000003
	_noise.frequency = 0.25
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_shade.seed = c.seed % 1000033 + 7
	_shade.frequency = 0.04
	_blur_cells()
	_sample_field()
	_march()


func _cell(x: int, y: int) -> float:
	return 1.0 if cave.is_solid(x, y) else 0.0


## Each cell's value: itself counted 4 times plus its 4 side neighbours,
## over 8. A one-cell-thick ledge stays solid (0.75); a wall's edge stays on
## the cell edge.
func _blur_cells() -> void:
	_blur.resize(cave.width * cave.height)
	for y in cave.height:
		for x in cave.width:
			var sum: float = 4.0 * _cell(x, y)
			sum += _cell(x - 1, y) + _cell(x + 1, y) + _cell(x, y - 1) + _cell(x, y + 1)
			_blur[y * cave.width + x] = sum / 8.0


func _blur_at(x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= cave.width or y >= cave.height:
		return 1.0
	return _blur[y * cave.width + x]


## The field at a point given in cells (bilinear between cell centres, plus wobble).
func value_at(px: float, py: float) -> float:
	var u: float = px - 0.5
	var v: float = py - 0.5
	var ix: int = floori(u)
	var iy: int = floori(v)
	var fx: float = u - ix
	var fy: float = v - iy
	var top: float = lerpf(_blur_at(ix, iy), _blur_at(ix + 1, iy), fx)
	var bottom: float = lerpf(_blur_at(ix, iy + 1), _blur_at(ix + 1, iy + 1), fx)
	var value: float = lerpf(top, bottom, fy)
	# Wobble only near edges, never across a whole cell.
	if value > 0.2 and value < 0.8:
		value += _noise.get_noise_2d(px, py) * WOBBLE
	# The outer ring is always rock.
	if px <= 1.0 or py <= 1.0 or px >= cave.width - 1 or py >= cave.height - 1:
		value = maxf(value, 0.75)
	return value


func _sample_field() -> void:
	_gw = cave.width * SUB + 1
	_gh = cave.height * SUB + 1
	_field.resize(_gw * _gh)
	for j in _gh:
		for i in _gw:
			_field[j * _gw + i] = value_at(float(i) / SUB, float(j) / SUB)


func _point(i: int, j: int) -> Vector2:
	var step: float = float(CaveData.CELL_SIZE) / SUB
	return Vector2(i * step, j * step)


func _rock_color(p: Vector2, value: float) -> Color:
	var depth: float = clampf((value - 0.5) * 2.2, 0.0, 1.0)
	var light := Color8(118, 100, 140)
	var deep := Color8(46, 38, 60)
	var c: Color = light.lerp(deep, depth)
	var s: float = _shade.get_noise_2d(p.x, p.y) * 0.12
	return Color(c.r + s, c.g + s * 0.8, c.b + s * 1.1, 1.0)


## Marching squares over the sub-grid: each square's rock part becomes a
## small polygon (fanned into triangles); edges between two crossing points
## become collision segments.
func _march() -> void:
	for j in _gh - 1:
		for i in _gw - 1:
			var idx: Array[Vector2i] = [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var vals: Array[float] = []
			var inside: int = 0
			for k in 4:
				var val: float = _field[idx[k].y * _gw + idx[k].x]
				vals.append(val)
				if val >= 0.5:
					inside += 1
			if inside == 0:
				continue
			var poly: Array[Vector2] = []
			var crossing: Array[bool] = []
			var depth: Array[float] = []
			for k in 4:
				var a: Vector2 = _point(idx[k].x, idx[k].y)
				var va: float = vals[k]
				var n: int = (k + 1) % 4
				var vb: float = vals[n]
				if va >= 0.5:
					poly.append(a)
					crossing.append(false)
					depth.append(va)
				if (va >= 0.5) != (vb >= 0.5):
					var t: float = (0.5 - va) / (vb - va)
					poly.append(a.lerp(_point(idx[n].x, idx[n].y), t))
					crossing.append(true)
					depth.append(0.5)
			for k in range(1, poly.size() - 1):
				for m: int in [0, k, k + 1]:
					triangles.append(poly[m])
					colors.append(_rock_color(poly[m], depth[m]))
			if inside < 4:
				for k in poly.size():
					var n: int = (k + 1) % poly.size()
					if crossing[k] and crossing[n]:
						segments.append(poly[k])
						segments.append(poly[n])


## True when a point (pixels) is inside rock, by the drawn shape.
func is_rock_at(p: Vector2) -> bool:
	return value_at(p.x / CaveData.CELL_SIZE, p.y / CaveData.CELL_SIZE) >= 0.5
