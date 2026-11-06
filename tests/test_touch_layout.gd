extends TestCase
## The on-screen buttons never overlap, in landscape or portrait, on a few
## phone shapes.


func test_buttons_never_overlap() -> void:
	for size: Vector2 in [Vector2(780, 360), Vector2(640, 360), Vector2(640, 1385), Vector2(640, 1100), Vector2(640, 900)]:
		var tc := TouchControls.new()
		tree.root.add_child(tc)
		tree.root.size = Vector2i(size)
		tc._layout()
		check_eq(tc.portrait, size.y > size.x, "%s: the right layout is used" % size)
		for i in tc.buttons.size():
			for j in range(i + 1, tc.buttons.size()):
				var a: Dictionary = tc.buttons[i]
				var b: Dictionary = tc.buttons[j]
				var gap: float = a["center"].distance_to(b["center"]) - a["radius"] - b["radius"]
				check(gap >= 0.0, "%s: %s and %s don't overlap (gap %.0f)" % [size, a["action"], b["action"], gap])
			var c: Dictionary = tc.buttons[i]
			var vp: Vector2 = tc.get_viewport().get_visible_rect().size
			check(Rect2(Vector2.ZERO, vp).has_point(c["center"]), "%s: %s is on screen" % [size, c["action"]])
		tc.queue_free()
		await tree.process_frame
