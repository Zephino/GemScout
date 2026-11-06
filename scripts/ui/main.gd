extends Node
## Runs the game: shows the main screen and the menus, and plays caves.
##
## Layers: the cave (CaveLevel) at the bottom, then the HUD (4), the touch
## buttons (5), and menus on top (10). While a menu covers a cave the game
## is paused.

var _ui: CanvasLayer
var _screen: Control
var _level: CaveLevel
var _hud: Hud
var _touch: TouchControls
var _seed: int = 0
var _difficulty: String = "medium"


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)
	_touch = TouchControls.new()
	_touch.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_touch)
	_touch.layout_changed.connect(_update_view)
	_touch.set_shown(false)
	Save.changed.connect(_update_touch)
	show_title()


func _show(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	if screen != null:
		_ui.add_child(screen)


func show_title() -> void:
	_end_level()
	var title := TitleScreen.new()
	title.play.connect(show_difficulty)
	title.open_leaderboard.connect(show_leaderboard)
	title.open_settings.connect(show_settings.bind(show_title))
	title.open_suggest.connect(show_suggest)
	_show(title)


func show_difficulty() -> void:
	_show(DifficultyScreen.new(func(id: String) -> void: start_cave(CaveGenerator.random_seed(), id), show_title).root)


func show_leaderboard() -> void:
	_show(LeaderboardScreen.new(show_title, start_cave, Save.setting("difficulty")).root)


func show_settings(back: Callable) -> void:
	_show(SettingsScreen.new(back).root)


func show_suggest() -> void:
	_show(SuggestionForm.new(show_title).root)


## Plays the cave made from `seed` (a new random one, or a leaderboard
## replay) on a difficulty ("" = the last one chosen).
func start_cave(seed: int, difficulty: String = "") -> void:
	_end_level()
	_seed = seed
	_difficulty = Difficulty.valid(difficulty if difficulty != "" else Save.setting("difficulty"))
	var parts: Array = UiKit.screen("", 320)
	parts[1].add_child(UiKit.label("Digging a cave…", 22, UiKit.GOLD))
	parts[1].add_child(UiKit.label("%s · seed %d" % [Difficulty.label(_difficulty), seed], 14, UiKit.MUTED))
	_show(parts[0])
	# Let "Digging…" appear before the (brief) work of building the cave.
	await get_tree().process_frame
	await get_tree().process_frame
	_level = CaveLevel.new()
	_level.name = "Cave"
	add_child(_level)
	_level.build(seed, _difficulty)
	_level.cleared.connect(_on_cleared)
	_level.died.connect(_on_died)
	_hud = Hud.new()
	add_child(_hud)
	_hud.watch(_level)
	_hud.pause_pressed.connect(pause)
	_show(null)
	get_tree().paused = false
	_update_touch()
	_hud.show_message("Find all %d gems, then reach the exit!" % _level.total)


func _end_level() -> void:
	get_tree().paused = false
	if _touch != null:
		_touch.set_shown(false)
	if _level != null:
		_level.queue_free()
		_level = null
	if _hud != null:
		_hud.queue_free()
		_hud = null


func _update_touch() -> void:
	var playing: bool = _level != null and not _level.finished and not get_tree().paused
	_touch.set_shown(playing and TouchControls.wanted(Save.setting("touch")))
	_update_view()


## Bigger view on phones; keep the scout above the touch buttons.
func _update_view() -> void:
	if _level == null:
		return
	var zoom: float = 2.0
	if _touch.shown:
		zoom = 3.6 if _touch.portrait else 2.3
	_level.set_view(zoom, _touch.view_shift())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _level != null and not _level.finished:
		if get_tree().paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()
	# A first touch on Auto shows the buttons even if the screen didn't say it was a touch screen.
	elif event is InputEventScreenTouch and _level != null and not _touch.shown and Save.setting("touch") == "auto" and not get_tree().paused:
		_touch.set_shown(true)
		_update_view()


func pause() -> void:
	if _level == null or _level.finished:
		return
	get_tree().paused = true
	_touch.set_shown(false)
	_show(PauseMenu.new(_seed, resume, func() -> void: start_cave(_seed, _difficulty), show_title, func() -> void:
		resume()
		_level.unstick()).root)


func resume() -> void:
	_show(null)
	get_tree().paused = false
	_update_touch()


func _on_cleared(result: Dictionary) -> void:
	Save.record_clear(result)
	_touch.set_shown(false)
	var replay_seed: int = _seed
	var diff: String = _difficulty
	_show(ResultsScreen.new(result, func() -> void: start_cave(CaveGenerator.random_seed(), diff), func() -> void: start_cave(replay_seed, diff), show_title).root)


## Out of hearts: the cave starts again from scratch (same seed).
func _on_died() -> void:
	_touch.set_shown(false)
	var parts: Array = UiKit.screen("", 320)
	parts[1].add_child(UiKit.label("Out of hearts!", 26, UiKit.BAD, HORIZONTAL_ALIGNMENT_CENTER, false))
	parts[1].add_child(UiKit.label("The cave starts again…", 15, UiKit.MUTED))
	_show(parts[0])
	var seed: int = _seed
	var level: CaveLevel = _level
	await get_tree().create_timer(1.6).timeout
	# Only if nothing else happened meanwhile (like leaving to the menu).
	if _level == level and _level != null:
		start_cave(seed, _difficulty)
