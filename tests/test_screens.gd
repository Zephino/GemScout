extends TestCase
## Every screen opens without errors, and the main flow works: play a cave,
## pause, resume, clear it, see the results, go back.


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func test_main_flow() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await _frames(3)
	check(main._screen is TitleScreen, "starts on the main screen")
	main.show_settings(main.show_title)
	await _frames(2)
	main.show_suggest()
	await _frames(2)
	main.show_leaderboard()
	await _frames(2)
	main.start_cave(4242)
	await _frames(6)
	check(main._level != null and main._level.total > 0, "a cave is being played")
	main.pause()
	await _frames(2)
	check(tree.paused, "pause stops the game")
	main.resume()
	await _frames(2)
	check(not tree.paused, "resume carries on")
	main._level._on_exit()
	await _frames(3)
	check(main._screen != null, "the results screen shows")
	main.show_title()
	await _frames(3)
	check(main._level == null, "leaving ends the cave")
	main.queue_free()
	await _frames(2)


func test_save_merge_and_username_rules() -> void:
	var save: Node = tree.root.get_node("Save")
	check_eq(save.clean_username("  Gem<Scout>!! 123456789"), "GemScout 123", "only safe characters, 12 at most")
	var a: Dictionary = {"username": "Old", "username_updated": 10, "records": {"best_score": 900, "best_time_ms": 50_000, "caves_cleared": 2, "gems_collected": 20}}
	var b: Dictionary = {"username": "New", "username_updated": 20, "records": {"best_score": 700, "best_time_ms": 40_000, "caves_cleared": 5, "gems_collected": 30}}
	var m: Dictionary = save.merge(a, b)
	check_eq(m["username"], "New", "newest username wins")
	check_eq(m["records"]["best_score"], 900, "best score wins")
	check_eq(m["records"]["best_time_ms"], 40_000, "fastest time wins")
	check_eq(m["records"]["caves_cleared"], 5, "most caves cleared")
	check_eq(save.sanitize({"records": {"best_score": -5}, "settings": {"touch": "weird"}})["settings"]["touch"], "auto", "bad settings are reset")
