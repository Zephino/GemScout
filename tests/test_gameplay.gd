extends TestCase
## Plays a real cave with real physics: the scout stands at the start and at
## every gem's spot without falling through, picks the gems up, the exit
## opens only when all are found, and walking in clears the cave.


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func test_cave_can_be_cleared() -> void:
	for seed: int in [11, 2024]:
		var level := CaveLevel.new()
		tree.root.add_child(level)
		level.build(seed)
		var cleared: Array = []
		level.cleared.connect(func(r: Dictionary) -> void: cleared.append(r))
		# This test is about standing on every gem spot, so nothing may knock
		# the scout away (enemies frozen, the scout unhurtable).
		level.freeze_left = 1e9
		level.hero.invulnerable_left = 1e9
		await _frames(30)
		check(level.hero.is_on_floor(), "seed %d: the scout lands at the start" % seed)
		var start_feet: Vector2 = CaveData.feet_position(level.cave.start)
		check(level.hero.position.distance_to(start_feet) < 6.0, "seed %d: and stays there (%s vs %s)" % [seed, level.hero.position, start_feet])

		# The exit is sealed while gems remain.
		level.hero.place(CaveData.feet_position(level.cave.exit))
		await _frames(10)
		check(not level.door.is_open and cleared.is_empty(), "seed %d: exit sealed with gems left" % seed)

		for cell in level.cave.gems:
			level.hero.place(CaveData.feet_position(cell))
			await _frames(12)
			var feet: Vector2 = CaveData.feet_position(cell)
			check(level.hero.is_on_floor(), "seed %d: the scout stands at the gem spot %s" % [seed, cell])
			check(level.hero.position.distance_to(feet) < 10.0, "seed %d: without sliding away from %s (now %s)" % [seed, feet, level.hero.position])
		check_eq(level.collected, level.total, "seed %d: every gem collected" % seed)
		check(level.door.is_open, "seed %d: the exit opened" % seed)

		level.hero.place(CaveData.feet_position(level.cave.exit))
		await _frames(10)
		check_eq(cleared.size(), 1, "seed %d: walking into the open exit clears the cave" % seed)
		if cleared.size() == 1:
			var r: Dictionary = cleared[0]
			check_eq(r["seed"], seed, "result has the seed")
			check_eq(r["gems"], level.total, "result has the gems")
			check_eq(r["score"], Scoring.total(r["gems"], r["time_ms"], r["no_damage"]), "score adds up")
			check(str(r["map"]).length() > 100, "result has the map picture")
		level.queue_free()
		await _frames(2)


func test_jumping_reaches_a_ledge_height() -> void:
	# Hold jump on a flat floor with nothing above: the scout must rise well
	# above the 5-cell climbs the generator plans for (Reachability.JUMP_UP).
	var arena := Node2D.new()
	tree.root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = WorldBoundaryShape2D.new()
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	var hero := Hero.new()
	arena.add_child(hero)
	hero.place(Vector2.ZERO)
	await _frames(20)
	var start_y: float = hero.position.y
	var best: float = 0.0
	Input.action_press("jump")
	for i in 40:
		await tree.physics_frame
		best = maxf(best, start_y - hero.position.y)
	Input.action_release("jump")
	check(best > (Reachability.JUMP_UP + 1) * CaveData.CELL_SIZE, "a full jump rises %.0f px (needs more than %d)" % [best, (Reachability.JUMP_UP + 1) * CaveData.CELL_SIZE])
	arena.queue_free()
	await _frames(2)


func test_scoring() -> void:
	check_eq(Scoring.total(10, 100_000, true), 1000 + 500 + (200 - 100) * 5, "gems + no damage + speed")
	check_eq(Scoring.total(10, 300_000, false), 1000, "no speed bonus past par")
	check_eq(Scoring.format_time(65_300), "1:05.3", "time format")
