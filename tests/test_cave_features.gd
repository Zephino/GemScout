extends TestCase
## Dangers and puzzles never make a cave unbeatable. A little solver plays
## each cave: it starts with every door and beam closed, opens one only once
## its lever or switch can be reached, shoots a Bouldermaw only once it can
## get next to it, and never stands on spikes. Every gem, pickup and the
## exit must be reached that way, with no spot to get stuck in on the way.

const SEEDS := 40


func _solve(cave: CaveData) -> Dictionary:
	var reach := Reachability.new(cave)
	var spikes: PackedByteArray = reach.nodes_inside(cave.spikes)
	var closed: Array[Dictionary] = []
	for d in cave.doors:
		closed.append({"rect": d["rect"], "item": d["lever"]})
	for b in cave.beams:
		closed.append({"rect": b["rect"], "item": b["switch"]})
	for b in cave.boulders:
		closed.append({"rect": b["rect"]})
	var traps: int = 0
	var result: Reachability.Result
	while true:
		var rects: Array[Rect2i] = []
		for c in closed:
			rects.append(c["rect"])
		result = reach.analyse(cave.start, spikes, rects)
		traps += result.traps.size()
		var safe := {}
		for c in result.safe:
			safe[c] = true
		var opened: bool = false
		for i in range(closed.size() - 1, -1, -1):
			var c: Dictionary = closed[i]
			var can: bool = false
			if c.has("item"):
				can = safe.has(c["item"])
			else:
				for s in result.safe:
					if c["rect"].grow(4).has_point(s):
						can = true
						break
			if can:
				closed.remove_at(i)
				opened = true
		if not opened:
			break
	var reached := {}
	for c in result.safe:
		reached[c] = true
	return {"closed_left": closed.size(), "traps": traps, "reached": reached}


func test_every_cave_is_still_beatable() -> void:
	var totals := {"doors": 0, "beams": 0, "boulders": 0, "spikes": 0, "enemies": 0, "pickups": 0}
	for i in SEEDS:
		var seed: int = (i * 2246822519 + 7) % 4294967296
		var cave: CaveData = CaveGenerator.generate(seed)
		totals["doors"] += cave.doors.size()
		totals["beams"] += cave.beams.size()
		totals["boulders"] += cave.boulders.size()
		totals["spikes"] += cave.spikes.size()
		totals["enemies"] += cave.enemies.size()
		totals["pickups"] += cave.pickups.size()
		var r: Dictionary = _solve(cave)
		check_eq(r["closed_left"], 0, "seed %d: every door, beam and Bouldermaw can be opened in turn" % seed)
		check_eq(r["traps"], 0, "seed %d: never a spot to get stuck in" % seed)
		var reached: Dictionary = r["reached"]
		check(reached.has(cave.exit), "seed %d: exit reached without touching spikes" % seed)
		for g in cave.gems:
			check(reached.has(g), "seed %d: gem %s reached without touching spikes" % [seed, g])
		for p: Dictionary in cave.pickups:
			check(reached.has(p["cell"]), "seed %d: %s pickup reached" % [seed, p["type"]])
		check(cave.boulders.size() <= CaveFeatures.MAX_BOULDERS, "seed %d: at most 2 Bouldermaws (Hard has 10 shots)" % seed)
		for e: Dictionary in cave.enemies:
			var at: Vector2 = e["center"] / CaveData.CELL_SIZE if e.has("center") else Vector2(e["cell"])
			check(at.distance_to(Vector2(cave.start)) >= 10.0, "seed %d: %s not next to the start" % [seed, e["type"]])
		var hearts: int = 0
		for p: Dictionary in cave.pickups:
			if p["type"] == "heart":
				hearts += 1
		check_eq(hearts, 1, "seed %d: one heart pickup" % seed)
	print("    over %d caves: %s" % [SEEDS, totals])
	check(totals["doors"] >= SEEDS, "caves have doors")
	check(totals["beams"] >= SEEDS / 2, "caves have beams")
	check(totals["spikes"] >= SEEDS * 2, "caves have spikes")
	check(totals["enemies"] >= SEEDS * 4, "caves have enemies")
