extends TestCase
## The cave generator: same seed → same cave; every cave can be finished.

const SEEDS := 120


func test_same_seed_same_cave() -> void:
	var a: CaveData = CaveGenerator.generate(12345)
	var b: CaveData = CaveGenerator.generate(12345)
	check(a.solid == b.solid, "rock layout matches")
	check_eq(a.gems, b.gems, "gems match")
	check_eq(a.exit, b.exit, "exit matches")
	var c: CaveData = CaveGenerator.generate(54321)
	check(a.solid != c.solid, "a different seed makes a different cave")


func test_every_cave_can_be_finished() -> void:
	var attempts: Array[int] = []
	var slowest: int = 0
	for i in SEEDS:
		var seed: int = (i * 2654435761) % 4294967296
		var started: int = Time.get_ticks_msec()
		var cave: CaveData = CaveGenerator.generate(seed)
		slowest = maxi(slowest, Time.get_ticks_msec() - started)
		attempts.append(cave.attempt)
		var reach := Reachability.new(cave)
		var result := reach.analyse(cave.start)
		check(result.traps.is_empty(), "seed %d: no spot the scout could get stuck in (%d found)" % [seed, result.traps.size()])
		check(cave.gems.size() >= CaveGenerator.MIN_GEMS, "seed %d: enough gems (%d)" % [seed, cave.gems.size()])
		check(result.safe.has(cave.exit), "seed %d: exit reachable and the way back works" % seed)
		for g in cave.gems:
			check(result.safe.has(g), "seed %d: gem at %s reachable" % [seed, g])
		check(not cave.gems.has(cave.start), "seed %d: no gem on the start" % seed)
		check(cave.attempt < CaveGenerator.MAX_ATTEMPTS, "seed %d: a real layout, not the fallback" % seed)
	attempts.sort()
	print("    attempts needed: median %d, worst %d; slowest cave %d ms" % [attempts[attempts.size() / 2], attempts[-1], slowest])


func test_fallback_layout_works() -> void:
	var g := CaveGenerator.new()
	var cave: CaveData = g._try(7, CaveGenerator.MAX_ATTEMPTS, true)
	check(cave != null, "the plain layout is always made")
	if cave == null:
		return
	var result := Reachability.new(cave).analyse(cave.start)
	check(result.safe.has(cave.exit), "its exit is reachable")
	check(not cave.gems.is_empty(), "it has gems")
