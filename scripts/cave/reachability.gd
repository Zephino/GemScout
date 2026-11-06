class_name Reachability
extends RefCounted
## Works out where the scout can get to in a cave, on the cell grid, with
## deliberately cautious rules (the real hero jumps about 11 cells high and
## is smaller than the box used here), so anything this says is reachable
## really is.
##
## A standing cell (x, y) is where the feet are: the body box (BODY_W x
## BODY_H cells: x..x+1, y-2..y) is air and there is rock under at least one
## of its two columns. Moves between standing cells:
##   walk  one column sideways, up or down at most one cell (a slope)
##   fall  step off an edge and drop straight down
##   jump  up to JUMP_UP cells higher (or JUMP_DOWN lower), JUMP_DX columns
##         across, with room to rise above the higher of the two spots
##
## The generator keeps only caves where every spot the scout can reach can
## also get back to the start, and places gems and the exit only on spots
## that can be reached from the start (so no gem is ever out of reach and the
## scout can't get stuck).

const BODY_W := 2
const BODY_H := 3
const JUMP_UP := 5
const JUMP_DOWN := 6
const JUMP_DX := 4
## Air needed above the higher spot for a jump (rows above the body): none
## for a short hop (up to 2 columns across), one row for a longer one.
const HEADROOM_SHORT := 0
const HEADROOM_LONG := 1

var cave: CaveData
## Standing cell index (y * width + x) -> node number, or -1.
var _node_of: PackedInt32Array
## 1 where a cell is a standing cell (fast lookups while building).
var _stand: PackedByteArray
## Node number -> cell.
var cells: Array[Vector2i] = []
## Node number -> nodes it can move to.
var _edges: Array[PackedInt32Array] = []
## Node number -> nodes that can move to it.
var _back: Array[PackedInt32Array] = []
## For each edge in _edges / _back: the cells it sweeps through, as
## x0, y0, x1, y1 (inclusive), so a closed door or a living Bouldermaw can
## block it without rebuilding everything.
var _edge_rects: Array[PackedInt32Array] = []
var _back_rects: Array[PackedInt32Array] = []


func _init(c: CaveData) -> void:
	cave = c
	_build()


func _air(x: int, y: int) -> bool:
	return not cave.is_solid(x, y)


## The body box with its feet in (x, y) is all air.
func body_fits(x: int, y: int) -> bool:
	for dy in BODY_H:
		for dx in BODY_W:
			if cave.is_solid(x + dx, y - dy):
				return false
	return true


func is_standing(x: int, y: int) -> bool:
	if not body_fits(x, y):
		return false
	return cave.is_solid(x, y + 1) or cave.is_solid(x + 1, y + 1)


## Every cell in the rectangle (inclusive) is air.
func _rect_air(x0: int, y0: int, x1: int, y1: int) -> bool:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if cave.is_solid(x, y):
				return false
	return true


func node_at(cell: Vector2i) -> int:
	if not cave.in_bounds(cell.x, cell.y):
		return -1
	return _node_of[cell.y * cave.width + cell.x]


func _build() -> void:
	_node_of = PackedInt32Array()
	_node_of.resize(cave.width * cave.height)
	_node_of.fill(-1)
	_stand = PackedByteArray()
	_stand.resize(cave.width * cave.height)
	for y in cave.height:
		for x in cave.width:
			if is_standing(x, y):
				_stand[y * cave.width + x] = 1
				_node_of[y * cave.width + x] = cells.size()
				cells.append(Vector2i(x, y))
	_edges.resize(cells.size())
	_back.resize(cells.size())
	_edge_rects.resize(cells.size())
	_back_rects.resize(cells.size())
	for i in cells.size():
		_back[i] = PackedInt32Array()
		_back_rects[i] = PackedInt32Array()
	for i in cells.size():
		var out := PackedInt32Array()
		var rects := PackedInt32Array()
		var s: Vector2i = cells[i]
		for target in _moves_from(s):
			var j: int = node_at(target)
			if j >= 0 and j != i and not out.has(j):
				out.append(j)
				# Everything the move might pass through (a little more than needed).
				var r := PackedInt32Array([mini(s.x, target.x), mini(s.y, target.y) - BODY_H - HEADROOM_LONG, maxi(s.x, target.x) + BODY_W - 1, maxi(s.y, target.y)])
				rects.append_array(r)
				_back[j].append(i)
				_back_rects[j].append_array(r)
		_edges[i] = out
		_edge_rects[i] = rects


func _is_stand(x: int, y: int) -> bool:
	return cave.in_bounds(x, y) and _stand[y * cave.width + x] == 1


func _moves_from(s: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: int in [-1, 1]:
		# Walk (including gentle slopes).
		for dy: int in [-1, 0, 1]:
			var t := Vector2i(s.x + dir, s.y + dy)
			if _is_stand(t.x, t.y) and _rect_air(mini(s.x, t.x), mini(s.y, t.y) - BODY_H + 1, maxi(s.x, t.x) + BODY_W - 1, maxi(s.y, t.y)):
				out.append(t)
		# Fall: step off an edge and drop.
		var fx: int = s.x + dir
		if body_fits(fx, s.y) and not _is_stand(fx, s.y):
			var y: int = s.y
			while y < cave.height and body_fits(fx, y + 1) and not _is_stand(fx, y):
				y += 1
			if _is_stand(fx, y):
				out.append(Vector2i(fx, y))
	# Jumps.
	for ty in range(s.y - JUMP_UP, s.y + JUMP_DOWN + 1):
		for tx in range(s.x - JUMP_DX, s.x + JUMP_DX + 1):
			if (tx == s.x and ty == s.y) or not _is_stand(tx, ty):
				continue
			if _jump_clear(s, Vector2i(tx, ty)):
				out.append(Vector2i(tx, ty))
	return out


## Room to jump from s to t: straight up from s to just above the higher of
## the two spots (plus headroom), across, and down onto t.
func _jump_clear(s: Vector2i, t: Vector2i) -> bool:
	var apex: int = mini(s.y, t.y) - 1  # feet row at the top of the jump
	var headroom: int = HEADROOM_SHORT if absi(t.x - s.x) <= 2 else HEADROOM_LONG
	var top: int = apex - BODY_H + 1 - headroom
	if not _rect_air(s.x, top, s.x + BODY_W - 1, s.y):
		return false
	if not _rect_air(mini(s.x, t.x), top, maxi(s.x, t.x) + BODY_W - 1, apex):
		return false
	return _rect_air(t.x, top, t.x + BODY_W - 1, t.y)


## Nodes reachable from `from` (forward), or that can reach it (backward).
## `excluded`: nodes that may not be stood on (1 = excluded; spikes, or
## inside a barrier). `barriers`: closed doors etc. (cell rects) no move may
## pass through.
func _search(from: int, backward: bool, excluded: PackedByteArray = PackedByteArray(), barriers: Array[Rect2i] = []) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(cells.size())
	if from < 0 or (not excluded.is_empty() and excluded[from] == 1):
		return seen
	var queue := PackedInt32Array([from])
	seen[from] = 1
	var head: int = 0
	while head < queue.size():
		var n: int = queue[head]
		head += 1
		var list: PackedInt32Array = _back[n] if backward else _edges[n]
		var rects: PackedInt32Array = _back_rects[n] if backward else _edge_rects[n]
		for k in list.size():
			var m: int = list[k]
			if seen[m] == 1 or (not excluded.is_empty() and excluded[m] == 1):
				continue
			if not barriers.is_empty() and _crosses(rects, k, barriers):
				continue
			seen[m] = 1
			queue.append(m)
	return seen


func _crosses(rects: PackedInt32Array, k: int, barriers: Array[Rect2i]) -> bool:
	var x0: int = rects[k * 4]
	var y0: int = rects[k * 4 + 1]
	var x1: int = rects[k * 4 + 2]
	var y1: int = rects[k * 4 + 3]
	for b in barriers:
		if x0 <= b.end.x - 1 and x1 >= b.position.x and y0 <= b.end.y - 1 and y1 >= b.position.y:
			return true
	return false


## 1 for every node whose body would overlap one of `rects` (cells).
func nodes_inside(rects: Array[Rect2i]) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cells.size())
	for i in cells.size():
		var c: Vector2i = cells[i]
		var body := Rect2i(c.x, c.y - BODY_H + 1, BODY_W, BODY_H)
		for r in rects:
			if body.intersects(r):
				out[i] = 1
				break
	return out


## Combines two exclusion lists (either may be empty).
static func merge_excluded(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	var out := a.duplicate()
	for i in out.size():
		out[i] = 1 if a[i] == 1 or b[i] == 1 else 0
	return out


class Result:
	## Spots reachable from the start that can also get back to it.
	var safe: Array[Vector2i] = []
	## Spots reachable from the start that can't get back (the scout would be stuck).
	var traps: Array[Vector2i] = []
	var forward: PackedByteArray
	var backward: PackedByteArray


func analyse(start: Vector2i, excluded: PackedByteArray = PackedByteArray(), barriers: Array[Rect2i] = []) -> Result:
	var r := Result.new()
	var s: int = node_at(start)
	var ex: PackedByteArray = merge_excluded(excluded, nodes_inside(barriers)) if not barriers.is_empty() else excluded
	r.forward = _search(s, false, ex, barriers)
	r.backward = _search(s, true, ex, barriers)
	for i in cells.size():
		if r.forward[i] == 0:
			continue
		if r.backward[i] == 1:
			r.safe.append(cells[i])
		else:
			r.traps.append(cells[i])
	return r


## True when `target` can be reached from `from` and back.
func round_trip(from: Vector2i, target: Vector2i) -> bool:
	var a: int = node_at(from)
	var b: int = node_at(target)
	if a < 0 or b < 0:
		return false
	return _search(a, false)[b] == 1 and _search(b, false)[a] == 1
