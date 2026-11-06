extends TestCase
## The smooth rock drawn (and collided with) must match the cell grid the
## generator checked: wherever Reachability says the scout can stand, the
## drawn shape has ground under the feet and room for the hero's body.


func _check_cave(seed: int) -> Array[int]:
	var cave: CaveData = CaveGenerator.generate(seed)
	var shape := CaveShape.new(cave)
	var reach := Reachability.new(cave)
	var bad_ground: int = 0
	var bad_body: int = 0
	var spots: Array[Vector2i] = reach.analyse(cave.start).safe
	for c in spots:
		var feet: Vector2 = CaveData.feet_position(c)
		# Ground: rock just under the feet somewhere across the body's width
		# (thin ledge tips are drawn a pixel or two lower, so look 5 px down).
		var ground: bool = false
		for dx in range(-7, 8):
			for dy in range(1, 6):
				if shape.is_rock_at(feet + Vector2(dx, dy)):
					ground = true
		if not ground:
			print("      no ground at ", c)
		if not ground:
			bad_ground += 1
		# Body: the hero's capsule (10 x 20, round ends; centred on the feet,
		# standing on the ground) is air.
		var clear: bool = true
		for p: Vector2 in [Vector2(0, -2), Vector2(-4, -6), Vector2(4, -6), Vector2(-4, -10), Vector2(4, -10), Vector2(-4, -14), Vector2(4, -14), Vector2(0, -19)]:
			if shape.is_rock_at(feet + p):
				clear = false
		if not clear:
			bad_body += 1
			print("      no body room at ", c)
	return [spots.size(), bad_ground, bad_body, shape.triangles.size() / 3, shape.segments.size() / 2]


func test_shape_matches_cells() -> void:
	for seed: int in [1, 2, 3, 12345, 99999, 4000000000]:
		var r: Array[int] = _check_cave(seed)
		print("    seed %d: %d spots, %d without ground, %d without body room; %d triangles, %d edges" % [seed, r[0], r[1], r[2], r[3], r[4]])
		check_eq(r[1], 0, "seed %d: ground under every standing spot" % seed)
		check_eq(r[2], 0, "seed %d: room for the body at every standing spot" % seed)
		check(r[4] > 100, "seed %d: has collision edges" % seed)
