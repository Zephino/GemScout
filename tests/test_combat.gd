extends TestCase
## Health, difficulty, the blaster, enemies, puzzles, hazards and power-ups,
## played with real physics in a small hand-made room (60 x 30 cells, flat
## floor) so every check is about the rule, not the random cave.


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


## An open room; the scout starts at the left.
func _room() -> CaveData:
	var c := CaveData.new()
	c.seed = 1
	c.gen = CaveGenerator.VERSION
	c.setup(60, 30)
	for y in range(2, 28):
		for x in range(2, 58):
			c.set_solid(x, y, false)
	c.start = Vector2i(6, 27)
	c.exit = Vector2i(54, 27)
	c.gems = [Vector2i(30, 27)] as Array[Vector2i]
	for x in range(2, 57):
		c.safe[Vector2i(x, 27)] = true
	return c


func _level(c: CaveData, difficulty: String) -> CaveLevel:
	var level := CaveLevel.new()
	tree.root.add_child(level)
	level.build_from(c, difficulty)
	return level


func _done(level: CaveLevel) -> void:
	level.queue_free()
	await _frames(2)


func test_difficulties_set_hearts_and_ammo() -> void:
	for pair: Array in [["easy", 5, -1], ["medium", 3, 6], ["hard", 1, 10]]:
		var level := _level(_room(), pair[0])
		check_eq(level.hearts, pair[1], "%s hearts" % pair[0])
		check_eq(level.ammo, pair[2], "%s ammo" % pair[0])
		await _done(level)


func test_getting_hurt_and_running_out_of_hearts() -> void:
	var level := _level(_room(), "medium")
	await _frames(10)
	var died: Array = []
	level.died.connect(func() -> void: died.append(true))
	level.hurt(level.hero.position + Vector2(10, 0))
	check_eq(level.hearts, 2, "a hit costs a heart")
	check(not level.no_damage, "and loses the no-damage bonus")
	level.hurt(level.hero.position)
	check_eq(level.hearts, 2, "no second hit while flashing")
	level.hero.invulnerable_left = 0.0
	level.hero.shielded = true
	level.hurt(level.hero.position)
	check_eq(level.hearts, 2, "a shield takes the hit")
	check(not level.hero.shielded, "and is used up")
	for i in 2:
		level.hero.invulnerable_left = 0.0
		level.hurt(level.hero.position)
	check_eq(level.hearts, 0, "out of hearts")
	check_eq(died.size(), 1, "the cave reports the scout died (Main restarts it)")
	await _done(level)


func test_blaster_ammo_rules() -> void:
	var level := _level(_room(), "hard")
	await _frames(5)
	for i in 10:
		level._cooldown = 0.0
		level.shoot()
	check_eq(level.ammo, 0, "hard: 10 shots, then empty")
	level._cooldown = 0.0
	level.shoot()
	check_eq(level.ammo, 0, "no shot when empty")
	level._tick_recharge(Difficulty.RECHARGE_S + 0.1)
	check_eq(level.ammo, 1, "an empty blaster recharges one shot")
	await _done(level)
	var easy := _level(_room(), "easy")
	await _frames(5)
	for i in 30:
		easy._cooldown = 0.0
		easy.shoot()
	check_eq(easy.ammo, -1, "easy: unlimited shots")
	await _done(easy)


func test_shots_hit_enemies_and_bouldermaws() -> void:
	var c := _room()
	c.enemies.append({"type": "glowmoth", "center": CaveData.feet_position(Vector2i(16, 27)) - Vector2(0, 12)})
	c.boulders.append({"rect": Rect2i(40, 18, 2, 10)})
	var level := _level(c, "medium")
	await _frames(10)
	var moth: Enemy = level.enemies[0]
	moth.set_process(false)
	moth.position = level.hero.muzzle() + Vector2(50, 0)
	level.hero.facing = 1
	level.shoot()
	await _frames(20)
	check(not moth.alive, "one shot defeats a Glowmoth")
	var boulder: Bouldermaw = level.boulders[0]
	# Each shot needs about 45 frames to fly 272 px; wait for it to land.
	for i in 2:
		level._cooldown = 0.0
		level.shoot()
		await _frames(60)
	check(boulder.alive, "a Bouldermaw survives 2 shots")
	check_eq(boulder.hp, 1, "and has taken 2 hits")
	level._cooldown = 0.0
	level.shoot()
	await _frames(60)
	check(not boulder.alive, "and breaks on the 3rd")
	await _done(level)

	var c2 := _room()
	c2.boulders.append({"rect": Rect2i(40, 18, 2, 10)})
	var level2 := _level(c2, "medium")
	await _frames(10)
	level2.power_shot_left = 10.0
	level2.shoot()
	await _frames(60)
	check(not level2.boulders[0].alive, "Power shot breaks a Bouldermaw at once")
	await _done(level2)


func test_levers_open_doors_and_switches_turn_off_beams() -> void:
	var c := _room()
	c.doors.append({"color": 1, "rect": Rect2i(20, 18, 2, 10), "lever": Vector2i(8, 27)})
	c.beams.append({"rect": Rect2i(30, 18, 2, 10), "switch": Vector2i(10, 27)})
	var level := _level(c, "medium")
	await _frames(10)
	check(level.is_blocked(Vector2(20.5 * 8, 25 * 8)), "the blue door is shut")
	level.hero.place(CaveData.feet_position(Vector2i(8, 27)))
	await _frames(3)
	level.interact()
	check(level.gates[0].is_open, "pulling the blue lever opens the blue door")
	await _frames(5)
	check(not level.is_blocked(Vector2(20.5 * 8, 25 * 8)), "and it no longer blocks")
	var beam: CrystalBeam = level.beams[0]
	var on_beam := Rect2(beam.rect.get_center().x - 4, beam.rect.end.y - 20, 10, 20)
	check(beam.hurts(on_beam), "the beam hurts while on")
	level.hero.place(CaveData.feet_position(Vector2i(10, 27)))
	await _frames(3)
	level.interact()
	check(not beam.hurts(on_beam), "its switch turns it off")
	await _done(level)


func test_spikes_hurt() -> void:
	var c := _room()
	c.spikes.append(Rect2i(14, 27, 3, 1))
	var level := _level(c, "easy")
	await _frames(5)
	level.hero.place(CaveData.feet_position(Vector2i(14, 27)))
	await _frames(3)
	check_eq(level.hearts, 4, "standing on spikes costs a heart")
	await _done(level)


func test_pickups() -> void:
	var c := _room()
	c.pickups.append({"type": "heart", "cell": Vector2i(12, 27)})
	c.pickups.append({"type": "ammo", "cell": Vector2i(16, 27)})
	c.pickups.append({"type": "freeze", "cell": Vector2i(20, 27)})
	c.pickups.append({"type": "gravity", "cell": Vector2i(24, 27)})
	c.enemies.append({"type": "glowmoth", "center": Vector2(400, 150)})
	var level := _level(c, "medium")
	await _frames(5)
	level.hearts = 1
	for cell: Vector2i in [Vector2i(12, 27), Vector2i(16, 27), Vector2i(20, 27)]:
		level.hero.place(CaveData.feet_position(cell))
		await _frames(3)
	check_eq(level.hearts, 2, "a heart pickup gives a heart back")
	check_eq(level.ammo, 6 + Difficulty.CRATE_AMMO, "an ammo crate gives 5 shots (Medium)")
	check(level.freeze_left > 0.0, "freeze is on")
	var moth: Enemy = level.enemies[0]
	check(not moth.touches(moth.body_center()), "frozen enemies can't hurt")
	level.hero.place(CaveData.feet_position(Vector2i(24, 27)))
	await _frames(40)
	check_eq(level.hero.gravity_sign, -1, "reverse gravity flips the scout")
	check(level.hero.position.y < 20 * 8, "and they rise to the ceiling (y %.0f)" % level.hero.position.y)
	await _done(level)
	var hard := _level(c, "hard")
	check(hard.pickups.all(func(p: Pickup) -> bool: return p.type != "ammo"), "no ammo crates on Hard")
	await _done(hard)


func test_enemies_hurt_on_touch() -> void:
	var c := _room()
	c.enemies.append({"type": "shellback", "cell": Vector2i(20, 27), "from_x": 18, "to_x": 30})
	var level := _level(c, "medium")
	await _frames(5)
	var bug: Enemy = level.enemies[0]
	level.hero.place(bug.position)
	await _frames(3)
	check_eq(level.hearts, 2, "touching a Shellback costs a heart")
	await _done(level)
