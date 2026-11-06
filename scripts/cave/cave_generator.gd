class_name CaveGenerator
extends RefCounted
## Makes a cave from a seed. The same seed and VERSION always make the same
## cave, so a seed is enough to replay one (the leaderboard keeps it).
##
## Layout: three winding tunnels stacked on top of each other ("tiers"),
## joined by shafts at alternate ends, so the cave snakes from the top-left
## to the bottom. Tunnels have uneven floors (slopes and steps of up to two
## cells), bumpy ceilings, rocks and stalactites, and taller chambers with
## floating ledges. Shafts have ledges exactly 5 rows apart to climb back up.
##
## Steps: plan every floor (random walk, flat chambers, flat shaft bottoms),
## limit steps to 2 cells, carve, add ledges and decorations, then check the
## result with Reachability, then add doors, beams, spikes, enemies and
## pickups (CaveFeatures, which checks they're fair). If any spot the scout can reach can't get back
## to the start, or there aren't enough spots for gems, the next try (same
## seed, attempt + 1) is used. Gems and the exit are only put on spots the
## scout can reach and come back from.
##
## Change VERSION whenever a change here would draw a different cave for the
## same seed (old leaderboard seeds then show "made with an older version").

const VERSION := 2
const WIDTH := 144
const HEIGHT := 72
const TIERS := 3
const MAX_ATTEMPTS := 30
const MIN_GEMS := 10
const MAX_GEMS := 16
const SHAFT_W := 9
## Rows between shaft ledges (and chamber ledges): one full jump.
const LEDGE_GAP := 5
const MAX_STEP := 2
const TUNNEL_MIN_H := 7
const TUNNEL_MAX_H := 11
const CHAMBER_H := 17

var _rng := RandomNumberGenerator.new()
var _cave: CaveData
## Per tier: floor row for each column (feet stand on floor - 1).
var _floors: Array[PackedInt32Array] = []
## Per tier: tunnel height for each column.
var _rooms: Array[PackedInt32Array] = []
## Per tier: 1 where the floor is pinned (chambers, shaft bottoms).
var _pinned: Array[PackedByteArray] = []
## Per tier: chambers as [x0, x1].
var _chambers: Array = []


## A random seed for a new game (0 to 4294967295).
static func random_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi()


static func generate(seed: int) -> CaveData:
	var g := CaveGenerator.new()
	for attempt in MAX_ATTEMPTS:
		var cave: CaveData = g._try(seed, attempt)
		if cave != null:
			return cave
	# Every try failed (never seen in tests): the plainest layout always works.
	return g._try(seed, MAX_ATTEMPTS, true)


func _try(seed: int, attempt: int, plain: bool = false) -> CaveData:
	_rng.seed = hash([seed, attempt, VERSION])
	_cave = CaveData.new()
	_cave.seed = seed
	_cave.gen = VERSION
	_cave.attempt = attempt
	_cave.setup(WIDTH, HEIGHT)
	_floors.clear()
	_rooms.clear()
	_pinned.clear()
	_chambers.clear()
	for tier in TIERS:
		_plan_tier(tier, plain)
	var shafts: Array = []
	for tier in TIERS - 1:
		shafts.append(_plan_shaft(tier))
	for tier in TIERS:
		_limit_steps(tier)
		_carve_tier(tier)
	for tier in TIERS - 1:
		_carve_shaft(tier, shafts[tier])
	for tier in TIERS:
		_add_chamber_ledges(tier)
	if not plain:
		_decorate()
	_cave.start = _stand_near(4, 0)
	if _cave.start.x < 0:
		return null
	var result := Reachability.new(_cave).analyse(_cave.start)
	if not result.traps.is_empty() and not plain:
		return null
	_cave.exit = _pick_exit(result.safe)
	if _cave.exit.x < 0:
		return null
	_cave.gems = _pick_gems(result.safe)
	if _cave.gems.size() < MIN_GEMS and not plain:
		return null
	if plain:
		for c in result.safe:
			_cave.safe[c] = true
		return _cave
	# Dangers, puzzles and pickups (CaveFeatures checks they're fair).
	if not CaveFeatures.new(_cave, _rng).place():
		return null
	return _cave


func _tier_base(tier: int) -> int:
	# Floor rows near 24, 46, 68 for a 72-cell-high cave.
	return 2 + (tier + 1) * (HEIGHT - 6) / TIERS


## The highest a ceiling may go in this tier (keeps rock between tiers).
func _tier_top(tier: int) -> int:
	return _tier_base(tier) - (HEIGHT - 6) / TIERS + 3


func _plan_tier(tier: int, plain: bool) -> void:
	var base: int = _tier_base(tier)
	var floors := PackedInt32Array()
	var rooms := PackedInt32Array()
	var pinned := PackedByteArray()
	floors.resize(WIDTH)
	rooms.resize(WIDTH)
	pinned.resize(WIDTH)
	floors.fill(base)
	rooms.fill(9)
	var f: int = base
	var h: int = 9
	var x: int = 2
	while x < WIDTH - 2:
		var run: int = _rng.randi_range(3, 7)
		if not plain:
			var step: int = [-2, -1, -1, 0, 0, 0, 1, 1, 2][_rng.randi_range(0, 8)]
			f = clampi(f + step, base - 4, base + 1)
			h = clampi(h + _rng.randi_range(-2, 2), TUNNEL_MIN_H, TUNNEL_MAX_H)
		for i in run:
			if x >= WIDTH - 2:
				break
			floors[x] = f
			rooms[x] = h + (_rng.randi_range(0, 1) if not plain else 0)
			x += 1
	var chambers: Array = []
	if not plain:
		var count: int = _rng.randi_range(1, 2)
		var slot_w: int = (WIDTH - 2 * (SHAFT_W + 8)) / count
		for c in count:
			var w: int = _rng.randi_range(14, 20)
			var x0: int = SHAFT_W + 8 + c * slot_w + _rng.randi_range(0, maxi(0, slot_w - w))
			chambers.append([x0, x0 + w - 1])
			var fl: int = floors[x0]
			for cx in range(x0, x0 + w):
				floors[cx] = fl
				rooms[cx] = CHAMBER_H
				pinned[cx] = 1
	_floors.append(floors)
	_rooms.append(rooms)
	_pinned.append(pinned)
	_chambers.append(chambers)


## Picks where the shaft from `tier` down to the next goes and its bottom
## row, so its ledges come out exactly LEDGE_GAP rows apart; pins that floor.
func _plan_shaft(tier: int) -> Dictionary:
	var at_right: bool = tier % 2 == 0
	var x0: int = WIDTH - 3 - SHAFT_W if at_right else 3
	var edge_x: int = x0 - 1 if at_right else x0 + SHAFT_W
	var up_floor: int = _floors[tier][edge_x]
	# The upper floor right next to the shaft is pinned, so the top ledge fits it.
	for x in range(edge_x - 2, edge_x + 3):
		if x > 1 and x < WIDTH - 2 and (x < x0 or x >= x0 + SHAFT_W):
			_floors[tier][x] = up_floor
			_pinned[tier][x] = 1
	var first: int = up_floor + 3
	var lower: PackedInt32Array = _floors[tier + 1]
	var want: int = lower[x0 + SHAFT_W / 2]
	var base: int = _tier_base(tier + 1)
	# Bottom row: ledges at first, first+5, ...; the last ledge 4–5 rows above it.
	var best: int = want
	var best_cost: int = 999
	for low in range(base - 4, base + 2):
		var gap: int = (low - first) % LEDGE_GAP
		var ok: bool = (low - first) >= 4 and (gap == 4 or gap == 0)
		if ok and absi(low - want) < best_cost:
			best_cost = absi(low - want)
			best = low
	for x in range(x0 - 2, x0 + SHAFT_W + 2):
		if x > 1 and x < WIDTH - 2:
			lower[x] = best
			_pinned[tier + 1][x] = 1
	return {"x0": x0, "at_right": at_right, "up_floor": up_floor, "low_floor": best}


## No step between neighbouring columns more than MAX_STEP cells: unpinned
## columns move towards their pinned or already-fixed neighbours.
func _limit_steps(tier: int) -> void:
	var f: PackedInt32Array = _floors[tier]
	var pinned: PackedByteArray = _pinned[tier]
	for pass_i in 12:
		var changed: bool = false
		for x in range(3, WIDTH - 2):
			for pair: Array in [[x - 1, x], [x, x - 1]]:
				var a: int = pair[0]
				var b: int = pair[1]
				if pinned[b] == 1:
					continue
				if f[b] - f[a] > MAX_STEP:
					f[b] = f[a] + MAX_STEP
					changed = true
				elif f[a] - f[b] > MAX_STEP:
					f[b] = f[a] - MAX_STEP
					changed = true
		if not changed:
			break


func _carve_tier(tier: int) -> void:
	var top: int = _tier_top(tier)
	for x in range(2, WIDTH - 2):
		var fl: int = _floors[tier][x]
		var ceiling: int = maxi(top, fl - _rooms[tier][x])
		for y in range(ceiling, fl):
			_cave.set_solid(x, y, false)


func _ledge(x0: int, row: int, w: int) -> void:
	for x in range(x0, x0 + w):
		_cave.set_solid(x, row, true)


func _carve_shaft(tier: int, s: Dictionary) -> void:
	var x0: int = s["x0"]
	var up_floor: int = s["up_floor"]
	var low_floor: int = s["low_floor"]
	for x in range(x0, x0 + SHAFT_W):
		for y in range(up_floor - TUNNEL_MIN_H, low_floor):
			_cave.set_solid(x, y, false)
	# Ledges, alternating sides, LEDGE_GAP rows apart from just under the upper
	# floor down; the top one is on the side next to the upper tunnel.
	var near_left: bool = s["at_right"]
	var row: int = up_floor + 3
	var k: int = 0
	while low_floor - row >= 4:
		var left: bool = near_left if k % 2 == 0 else not near_left
		_ledge(x0 if left else x0 + SHAFT_W - 4, row, 4)
		row += LEDGE_GAP
		k += 1


## Two floating ledges per chamber: one LEDGE_GAP above the floor, one twice that.
func _add_chamber_ledges(tier: int) -> void:
	for ch: Array in _chambers[tier]:
		var fl: int = _floors[tier][ch[0]]
		var w1: int = _rng.randi_range(4, 6)
		var lx: int = ch[0] + _rng.randi_range(2, 5)
		_ledge(lx, fl - LEDGE_GAP, w1)
		var w2: int = _rng.randi_range(4, 6)
		var hx: int = lx + w1 + _rng.randi_range(1, 3)
		if hx + w2 < ch[1] - 1:
			_ledge(hx, fl - 2 * LEDGE_GAP, w2)


## Rocks on floors and stalactites in tall places: only where they leave room.
func _decorate() -> void:
	for tier in TIERS:
		var floors: PackedInt32Array = _floors[tier]
		for i in _rng.randi_range(3, 6):
			var x: int = _rng.randi_range(SHAFT_W + 6, WIDTH - SHAFT_W - 8)
			var w: int = _rng.randi_range(2, 3)
			var fl: int = floors[x]
			var ok: bool = true
			for dx in range(-1, w + 1):
				if floors[x + dx] != fl or _cave.is_solid(x + dx, fl - 8) or _pinned[tier][x + dx] == 1:
					ok = false
			if ok:
				for dx in w:
					_cave.set_solid(x + dx, fl - 1, true)
		for i in _rng.randi_range(3, 6):
			var x: int = _rng.randi_range(4, WIDTH - 5)
			var fl: int = floors[x]
			var y: int = fl - 1
			while y > 1 and not _cave.is_solid(x, y):
				y -= 1
			if fl - 1 - y >= 10 and _pinned[tier][x] == 0:
				for dy in range(1, _rng.randi_range(1, 2) + 1):
					_cave.set_solid(x, y + dy, true)


## The first standing cell from column `x` rightwards in the given tier.
func _stand_near(x: int, tier: int) -> Vector2i:
	var floors: PackedInt32Array = _floors[tier]
	for cx in range(x, WIDTH - 4):
		var y: int = floors[cx] - 1
		var clear: bool = true
		for dy in 3:
			if _cave.is_solid(cx, y - dy) or _cave.is_solid(cx + 1, y - dy):
				clear = false
		if clear and (_cave.is_solid(cx, y + 1) or _cave.is_solid(cx + 1, y + 1)):
			return Vector2i(cx, y)
	return Vector2i(-1, -1)


## The safe spot furthest along the cave: the bottom tier's far end.
func _pick_exit(safe: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score: float = -INF
	var last_tier_right: bool = (TIERS - 1) % 2 == 0
	var bottom_base: int = _tier_base(TIERS - 1)
	for c in safe:
		if c.y < bottom_base - 8:
			continue
		var score: float = c.x if last_tier_right else -c.x
		if score > best_score:
			best_score = score
			best = c
	return best


## Spread the gems out over safe spots, away from the start and the exit.
func _pick_gems(safe: Array[Vector2i]) -> Array[Vector2i]:
	var want: int = _rng.randi_range(MIN_GEMS, MAX_GEMS)
	var candidates: Array[Vector2i] = []
	for c in safe:
		if c.distance_to(_cave.start) >= 8 and c.distance_to(_cave.exit) >= 4:
			candidates.append(c)
	var picked: Array[Vector2i] = []
	if candidates.is_empty():
		return picked
	picked.append(candidates[_rng.randi_range(0, candidates.size() - 1)])
	while picked.size() < want:
		var best := Vector2i(-1, -1)
		var best_d: float = -1.0
		for i in 24:
			var c: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
			var d: float = INF
			for p in picked:
				d = minf(d, c.distance_to(p))
			if d > best_d:
				best_d = d
				best = c
		if best_d < 5.0:
			break
		picked.append(best)
	return picked
