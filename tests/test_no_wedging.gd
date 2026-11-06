extends TestCase
## The scout never gets wedged next to a ledge (owner report: stuck between
## a shaft's ledge and the wall, unable to jump or walk out). With real
## physics, the scout is dropped beside the end of every ledge in a few
## caves and must land on its feet (on a floor it can jump from), not hang
## jammed in rock.

const SEEDS: Array[int] = [7, 794710975, 2024]


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func test_scout_never_wedges_beside_a_ledge() -> void:
	var drops: int = 0
	for seed in SEEDS:
		var level := CaveLevel.new()
		tree.root.add_child(level)
		level.build(seed, "easy")
		# Let every door and Bouldermaw finish setting up before opening them.
		await _frames(2)
		level.freeze_left = 1e9
		level.hero.invulnerable_left = 1e9
		for g in level.gates:
			g.open()
		for b in level.beams:
			b.on = false
		for b in level.boulders:
			b.hit(true)
		await _frames(2)
		var cave := level.cave
		# Ledge ends: rock with air above, and air on one side.
		var spots: Array[Vector2] = []
		for y in range(3, cave.height - 2):
			for x in range(2, cave.width - 2):
				if not cave.is_solid(x, y) or cave.is_solid(x, y - 1):
					continue
				for side: int in [-1, 1]:
					if not cave.is_solid(x + side, y) and not cave.is_solid(x + side, y + 1):
						spots.append(Vector2((x + side + 0.5) * 8.0, (y - 2) * 8.0))
		for p in spots:
			drops += 1
			level.hero.position = p
			level.hero.velocity = Vector2.ZERO
			await _frames(40)
			var before: Vector2 = level.hero.position
			await _frames(10)
			# Wedged = not standing, yet not moving either (it keeps its full
			# falling speed but stays put, jammed in rock).
			var wedged: bool = not level.hero.is_on_floor() and level.hero.position.distance_to(before) < 1.0
			check(not wedged, "seed %d: dropped beside a ledge end at %s, the scout isn't jammed (now %s)" % [seed, p, level.hero.position])
		level.queue_free()
		await _frames(2)
	print("    %d drops beside ledge ends" % drops)
	check(drops > 50, "there were ledge ends to test")


func test_im_stuck_returns_to_safe_ground() -> void:
	var level := CaveLevel.new()
	tree.root.add_child(level)
	level.build(7, "medium")
	await _frames(20)
	var safe_spot: Vector2 = level.hero.position
	level.hero.position = Vector2(-500, -500)
	level.collected = 3
	level.unstick()
	await _frames(5)
	check(level.hero.position.distance_to(safe_spot) < 12.0, "the scout is back on the last safe spot")
	check_eq(level.collected, 3, "and keeps the gems")
	level.queue_free()
	await _frames(2)
