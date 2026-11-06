class_name CaveData
extends RefCounted
## One generated cave: which cells are rock, where the scout starts, where the
## gems and the exit are. Made by CaveGenerator from a seed; the same seed and
## generator version always give the same cave.
##
## Cells are CELL_SIZE pixels square; x grows right, y grows down. A
## "standing cell" is the cell the scout's feet are in (see Reachability).

const CELL_SIZE := 8

var seed: int = 0
## CaveGenerator.VERSION that made this cave (stored with leaderboard scores).
var gen: int = 0
## How many tries the generator needed (attempt 0 is the first).
var attempt: int = 0
var width: int = 0
var height: int = 0
## 1 = rock, 0 = air; index = y * width + x.
var solid: PackedByteArray = PackedByteArray()
## Standing cells.
var start: Vector2i = Vector2i.ZERO
var exit: Vector2i = Vector2i.ZERO
var gems: Array[Vector2i] = []


func setup(w: int, h: int) -> void:
	width = w
	height = h
	solid = PackedByteArray()
	solid.resize(w * h)
	solid.fill(1)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## Outside the cave counts as rock.
func is_solid(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	return solid[y * width + x] == 1


func set_solid(x: int, y: int, value: bool) -> void:
	# The outer ring always stays rock so nobody can leave the cave.
	if x <= 0 or y <= 0 or x >= width - 1 or y >= height - 1:
		return
	solid[y * width + x] = 1 if value else 0


## The middle of a cell's bottom edge, in pixels (where feet stand).
static func feet_position(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 1) * CELL_SIZE, (cell.y + 1) * CELL_SIZE)


func pixel_size() -> Vector2:
	return Vector2(width * CELL_SIZE, height * CELL_SIZE)
