extends TestCase
## Every button on every screen still works after the screen is shown.
## Screens are built by small helper objects; Main keeps only the visible
## part (`root`). If the helper object went away, its buttons would silently
## do nothing (the "Send score does nothing" bug), so every button's
## connections must still point at something alive.


func _result() -> Dictionary:
	var cave: CaveData = CaveGenerator.generate(647539422)
	return {"seed": cave.seed, "gen": cave.gen, "difficulty": "medium", "gems": cave.gems.size(), "time_ms": 180000, "no_damage": false, "score": 1700, "map": CaveThumbnail.make_base64(cave)}


## Like Main: keep only `.root`, drop the helper object.
func _roots() -> Dictionary:
	var noop := func() -> void: pass
	return {
		"results": ResultsScreen.new(_result(), noop, noop, noop).root,
		"suggest": SuggestionForm.new(noop).root,
		"settings": SettingsScreen.new(noop).root,
		"leaderboard": LeaderboardScreen.new(noop, func(_s: int, _d: String) -> void: pass).root,
		"pause": PauseMenu.new(1, noop, noop, noop).root,
		"difficulty": DifficultyScreen.new(func(_d: String) -> void: pass, noop).root,
	}


func test_every_button_still_works() -> void:
	var roots: Dictionary = _roots()
	for name: String in roots:
		var root: Control = roots[name]
		tree.root.add_child(root)
	await tree.process_frame
	for name: String in roots:
		var root: Control = roots[name]
		var buttons: Array[Node] = root.find_children("*", "Button", true, false)
		check(not buttons.is_empty(), "%s has buttons" % name)
		for b: Button in buttons:
			# Dropdowns (OptionButton) work by themselves; every other button needs a working connection.
			if b is OptionButton:
				continue
			check(not b.pressed.get_connections().is_empty(), "%s: the \"%s\" button is connected" % [name, b.text])
			for c: Dictionary in b.pressed.get_connections():
				var callable: Callable = c["callable"]
				check(callable.is_valid(), "%s: the \"%s\" button still works" % [name, b.text])
	# And the real thing: Send score with no name says so (no network needed).
	var results: Control = roots["results"]
	var send: Button = null
	for b: Button in results.find_children("*", "Button", true, false):
		if b.text == "Send score":
			send = b
	var name_box: LineEdit = results.find_children("*", "LineEdit", true, false)[0]
	name_box.text = ""
	send.pressed.emit()
	var said: bool = false
	for l: Label in results.find_children("*", "Label", true, false):
		if l.text.begins_with("Type a name"):
			said = true
	check(said, "pressing Send score does something")
	for name: String in roots:
		roots[name].queue_free()
	await tree.process_frame
