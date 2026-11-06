class_name CaveFeatures
extends RefCounted
## Puts the dangers, puzzles and pickups into a generated cave, fairly.
##
## Barriers go across tunnels: coloured doors (opened by a lever of the same
## colour), crystal beams (turned off by a switch; they hurt while on) and
## Bouldermaws (solid until shot). Rules, all checked with Reachability:
##   - Barriers are sorted by how far along the cave they are. For each one,
##     everything is checked with it and every later barrier still closed:
##     its lever or switch must be reachable then (so you always find the
##     lever before you need it), and there must be no spot you could get
##     stuck in.
##   - Spikes are only kept if every gem, the exit, every lever, switch and
##     pickup can still be reached (and left) without standing on spikes, at
##     every stage. So spikes never block the only way through.
##   - Enemies can always be shot or jumped past and never start near you.
##     Bouldermaws need 3 shots; there are never more than 2, and the
##     blaster slowly recharges when empty, so ammo can't run out for good.
##   - Pickups (one heart, three ammo crates for Medium, two or three
##     power-ups) are only on reachable spots, spread out.

const COLORS := 3
const MAX_BOULDERS := 2
const BARRIER_SPACING := 12
const ENEMY_START_GAP := 14.0

var _cave: CaveData
var _rng: RandomNumberGenerator
var _reach: Reachability
## Cells that already have something (gems, levers, pickups...).
var _used: Array[Vector2i] = []
## Barriers in cave order: {kind: "door"/"beam"/"boulder", rect, color?, item?}.
var _barriers: Array[Dictionary] = []
var _spike_excluded := PackedByteArray()


func _init(cave: CaveData, rng: RandomNumberGenerator) -> void:
	_cave = cave
	_rng = rng


## Places everything. Returns false if the cave turned out unfair (the
## generator then tries again), which should be rare.
func place() -> bool:
	_reach = Reachability.new(_cave)
	var base := _reach.analyse(_cave.start)
	if not base.traps.is_empty():
		return false
	_cave.safe.clear()
	for c in base.safe:
		_cave.safe[c] = true
	_used.assign(_cave.gems)
	_used.append(_cave.start)
	_used.append(_cave.exit)
	_place_barriers(base.safe.size())
	_place_pickups()
	if not _valid(PackedByteArray()):
		return false
	_place_spikes()
	_place_enemies()
	_write_barriers()
	return true


# --- Barriers -----------------------------------------------------------------

## Tunnel spots where a 2-wide barrier would fill the whole tunnel height.
func _candidates() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for x in range(CaveGenerator.SHAFT_W + 10, _cave.width - CaveGenerator.SHAFT_W - 12):
		var y: int = 1
		while y < _cave.height - 1:
			if _cave.is_solid(x, y):
				y += 1
				continue
			var top: int = y
			while y < _cave.height - 1 and not _cave.is_solid(x, y):
				y += 1
			var bottom: int = y - 1
			var h: int = bottom - top + 1
			if h < 5 or h > 12:
				continue
			# The next column must be a tunnel at about the same place too.
			if _cave.is_solid(x + 1, bottom) or not _cave.is_solid(x + 1, bottom + 1) and not _cave.is_solid(x, bottom + 1):
				continue
			var top2: int = bottom
			while top2 > 1 and not _cave.is_solid(x + 1, top2 - 1):
				top2 -= 1
			if absi(top2 - top) > 3:
				continue
			out.append(Rect2i(x, mini(top, top2), 2, bottom - mini(top, top2) + 1))
	return out


func _touches_used(rect: Rect2i) -> bool:
	var grown := rect.grow(2)
	for c in _used:
		if grown.intersects(Rect2i(c.x, c.y - 2, 2, 3)):
			return true
	return false


func _place_barriers(full_size: int) -> void:
	var kinds: Array[String] = []
	for i in _rng.randi_range(1, COLORS):
		kinds.append("door")
	for i in _rng.randi_range(1, 2):
		kinds.append("beam")
	for i in _rng.randi_range(0, MAX_BOULDERS):
		kinds.append("boulder")
	for i in range(kinds.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var t: String = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = t
	var candidates: Array[Rect2i] = _candidates()
	# Shuffle (with the cave's own random numbers, so the seed decides).
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var t: Rect2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = t
	var chosen: Array[Dictionary] = []
	for rect in candidates:
		if chosen.size() >= kinds.size():
			break
		if _touches_used(rect):
			continue
		var near: bool = false
		for b: Dictionary in chosen:
			if absi(b["rect"].position.x - rect.position.x) < BARRIER_SPACING and absi(b["rect"].position.y - rect.position.y) < 14:
				near = true
		if near:
			continue
		# It must really cut the cave: closing it alone hides a good part.
		var closed := _reach.analyse(_cave.start, PackedByteArray(), [rect] as Array[Rect2i])
		if closed.safe.size() > full_size - 25 or not closed.traps.is_empty():
			continue
		chosen.append({"rect": rect, "reach": closed.safe.size()})
	# In cave order: the barrier that hides the most comes first.
	chosen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["reach"] < b["reach"])
	var color: int = 0
	var k: int = 0
	for b: Dictionary in chosen:
		var kind: String = kinds[k]
		k += 1
		if kind == "door":
			b["color"] = color % COLORS
			color += 1
		b["kind"] = kind
		_barriers.append(b)
	# Levers and switches, stage by stage.
	var i: int = 0
	while i < _barriers.size():
		var b: Dictionary = _barriers[i]
		var stage := _stage(i, PackedByteArray())
		if not stage.traps.is_empty() or _reach.node_at(_cave.start) < 0:
			_barriers.remove_at(i)
			continue
		if b["kind"] != "boulder":
			var item: Vector2i = _pick_spot(stage.safe, b["rect"], 8.0)
			if item.x < 0:
				_barriers.remove_at(i)
				continue
			b["item"] = item
			_used.append(item)
		i += 1


## Reachability with barrier `index` and every later one closed.
func _stage(index: int, excluded: PackedByteArray) -> Reachability.Result:
	var closed: Array[Rect2i] = []
	for j in range(index, _barriers.size()):
		closed.append(_barriers[j]["rect"])
	return _reach.analyse(_cave.start, excluded, closed)


## A free spot among `spots`, away from used things and from `avoid`.
func _pick_spot(spots: Array[Vector2i], avoid: Rect2i, min_gap: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score: float = -1.0
	for n in 30:
		if spots.is_empty():
			break
		var c: Vector2i = spots[_rng.randi_range(0, spots.size() - 1)]
		if avoid.size.x > 0 and avoid.grow(3).has_point(c):
			continue
		var d: float = INF
		for u in _used:
			d = minf(d, c.distance_to(u))
		if d < min_gap * 0.5:
			continue
		var gap: float = c.distance_to(Vector2(avoid.get_center())) if avoid.size.x > 0 else 0.0
		var score: float = minf(d, 20.0) + minf(gap, 30.0) * 0.5 + _rng.randf() * 4.0
		if score > best_score:
			best_score = score
			best = c
	return best


# --- Pickups ------------------------------------------------------------------

func _place_pickups() -> void:
	var spots: Array[Vector2i] = []
	spots.assign(_cave.safe.keys())
	var types: Array[String] = ["heart", "ammo", "ammo", "ammo"]
	var powers: Array[String] = ["power_shot", "gravity", "freeze", "shield"]
	for i in range(powers.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var t: String = powers[i]
		powers[i] = powers[j]
		powers[j] = t
	for i in _rng.randi_range(2, 3):
		types.append(powers[i])
	for type in types:
		var c: Vector2i = _pick_spot(spots, Rect2i(), 6.0)
		if c.x < 0:
			continue
		# Every pickup must be reachable at its own stage: before any barrier
		# it's behind is opened, the levers before it are enough.
		_cave.pickups.append({"type": type, "cell": c})
		_used.append(c)


# --- Fairness check -----------------------------------------------------------

## Every required spot reachable (and left again) at every stage, with
## `excluded` nodes (spikes) avoided.
func _valid(excluded: PackedByteArray) -> bool:
	var everything := _reach.analyse(_cave.start, excluded)
	if not everything.traps.is_empty():
		return false
	var safe := {}
	for c in everything.safe:
		safe[c] = true
	var required: Array[Vector2i] = []
	required.assign(_cave.gems)
	required.append(_cave.exit)
	for p: Dictionary in _cave.pickups:
		required.append(p["cell"])
	for b: Dictionary in _barriers:
		if b.has("item"):
			required.append(b["item"])
	for c in required:
		if not safe.has(c):
			return false
	for i in _barriers.size():
		var stage := _stage(i, excluded)
		if not stage.traps.is_empty():
			return false
		if _barriers[i].has("item") and not stage.safe.has(_barriers[i]["item"]):
			return false
	return true


# --- Spikes -------------------------------------------------------------------

func _place_spikes() -> void:
	var want: int = _rng.randi_range(4, 7)
	var spots: Array = _cave.safe.keys()
	var tries: int = 0
	while _cave.spikes.size() < want and tries < 40:
		tries += 1
		var c: Vector2i = spots[_rng.randi_range(0, spots.size() - 1)]
		if c.distance_to(_cave.start) < 10.0:
			continue
		var length: int = _rng.randi_range(2, 4)
		var rect := Rect2i(c.x, c.y, length, 1)
		var ok: bool = true
		for x in range(rect.position.x, rect.end.x):
			# Flat rock floor under every spike, air above.
			if not _cave.is_solid(x, c.y + 1) or _cave.is_solid(x, c.y) or _cave.is_solid(x, c.y - 1):
				ok = false
		for u in _used:
			if rect.grow(2).has_point(u):
				ok = false
		for s in _cave.spikes:
			if rect.grow(3).intersects(s):
				ok = false
		for b: Dictionary in _barriers:
			if rect.grow(3).intersects(b["rect"]):
				ok = false
		if not ok:
			continue
		var excluded: PackedByteArray = Reachability.merge_excluded(_spike_excluded, _reach.nodes_inside([rect] as Array[Rect2i]))
		if _valid(excluded):
			_cave.spikes.append(rect)
			_spike_excluded = excluded


# --- Enemies ------------------------------------------------------------------

func _free_spots() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in _cave.safe.keys():
		var n: int = _reach.node_at(c)
		if not _spike_excluded.is_empty() and _spike_excluded[n] == 1:
			continue
		if c.distance_to(_cave.start) < ENEMY_START_GAP:
			continue
		var clear: bool = true
		for b: Dictionary in _barriers:
			if b["rect"].grow(3).has_point(c):
				clear = false
		if clear:
			out.append(c)
	return out


func _place_enemies() -> void:
	var spots: Array[Vector2i] = _free_spots()
	if spots.is_empty():
		return
	var plan: Array[String] = []
	for i in _rng.randi_range(2, 3):
		plan.append("shellback")
	for i in _rng.randi_range(1, 2):
		plan.append("glowmoth")
	for i in 2:
		plan.append("dripjaw")
	for i in _rng.randi_range(1, 2):
		plan.append("spitter")
	var taken: Array[Vector2i] = []
	for type in plan:
		for attempt in 40:
			var c: Vector2i = spots[_rng.randi_range(0, spots.size() - 1)]
			var crowded: bool = false
			for t in taken:
				if c.distance_to(t) < 10.0:
					crowded = true
			if crowded:
				continue
			var e: Dictionary = _make_enemy(type, c)
			if not e.is_empty():
				_cave.enemies.append(e)
				taken.append(c)
				break


func _make_enemy(type: String, c: Vector2i) -> Dictionary:
	match type:
		"shellback":
			# Patrols the flat-ish floor it stands on (at least 6 cells of it).
			var from_x: int = c.x
			var to_x: int = c.x
			while from_x > c.x - 10 and _walkable(from_x - 1, c.y):
				from_x -= 1
			while to_x < c.x + 10 and _walkable(to_x + 1, c.y):
				to_x += 1
			if to_x - from_x < 6:
				return {}
			return {"type": type, "cell": c, "from_x": from_x, "to_x": to_x}
		"glowmoth":
			# Open air around a spot above the floor.
			var center := Vector2i(c.x + 1, c.y - 5)
			for dy in range(-3, 4):
				for dx in range(-4, 5):
					if _cave.is_solid(center.x + dx, center.y + dy):
						return {}
			return {"type": type, "center": Vector2((center.x + 0.5) * CaveData.CELL_SIZE, (center.y + 0.5) * CaveData.CELL_SIZE)}
		"dripjaw":
			# Hangs from a ceiling 5 to 10 cells above the floor.
			var y: int = c.y - 3
			while y > c.y - 11 and not _cave.is_solid(c.x, y) and not _cave.is_solid(c.x + 1, y):
				y -= 1
			if not (_cave.is_solid(c.x, y) and _cave.is_solid(c.x + 1, y)) or c.y - y < 5:
				return {}
			return {"type": type, "cell": Vector2i(c.x, y), "floor_y": float((c.y + 1) * CaveData.CELL_SIZE)}
		"spitter":
			# On a wall at head height, facing open air.
			for dir: int in [1, -1]:
				var wall_x: int = c.x - 1 if dir == 1 else c.x + 2
				if not _cave.is_solid(wall_x, c.y - 1):
					continue
				var open: bool = true
				for k in range(0, 8):
					if _cave.is_solid(c.x + (k if dir == 1 else 1 - k), c.y - 1):
						open = false
				if open:
					return {"type": type, "cell": Vector2i(wall_x, c.y - 1), "dir": dir}
			return {}
	return {}


func _walkable(x: int, y: int) -> bool:
	return _cave.safe.has(Vector2i(x, y)) or _cave.safe.has(Vector2i(x, y - 1)) or _cave.safe.has(Vector2i(x, y + 1))


func _write_barriers() -> void:
	for b: Dictionary in _barriers:
		match b["kind"]:
			"door":
				_cave.doors.append({"color": b["color"], "rect": b["rect"], "lever": b["item"]})
			"beam":
				_cave.beams.append({"rect": b["rect"], "switch": b["item"]})
			"boulder":
				_cave.boulders.append({"rect": b["rect"]})
