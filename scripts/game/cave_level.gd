class_name CaveLevel
extends Node2D
## One cave being played: builds it from a seed (terrain, gems, exit door,
## scout, camera), times the run, counts gems, and reports when the cave is
## cleared. Leaving or restarting throws the progress away (a new
## CaveLevel is made), as the design asks.

signal gems_changed(collected: int, total: int)
signal message(text: String)
signal cleared(result: Dictionary)

var cave: CaveData
var shape: CaveShape
var hero: Hero
var camera: Camera2D
var door: ExitDoor
var collected: int = 0
var total: int = 0
var time_ms: int = 0
## No hazards yet, so this stays true; enemies and spikes will clear it.
var no_damage: bool = true
var finished: bool = false

var _timing: bool = false
var _locked_hint_cooldown: float = 0.0


## Builds the cave for `seed` (takes a moment: call after showing "Digging…").
func build(seed: int) -> void:
	cave = CaveGenerator.generate(seed)
	shape = CaveShape.new(cave)
	var terrain := CaveTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(cave, shape)

	door = ExitDoor.new()
	door.position = CaveData.feet_position(cave.exit)
	door.entered.connect(_on_exit)
	door.bumped_locked.connect(_on_locked)
	add_child(door)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "gem colours"])
	for cell in cave.gems:
		var gem := Gem.new()
		# Gems float at the scout's chest height above the spot.
		gem.setup(CaveData.feet_position(cell) - Vector2(0, 11), rng.randi_range(0, 4))
		gem.collected.connect(_on_gem)
		add_child(gem)
	total = cave.gems.size()

	hero = Hero.new()
	hero.name = "Hero"
	add_child(hero)
	hero.place(CaveData.feet_position(cave.start))

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	var size: Vector2 = cave.pixel_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
	hero.add_child(camera)
	camera.position = Vector2(0, -12)
	camera.call_deferred("make_current")
	_timing = true
	gems_changed.emit(collected, total)


## How much to zoom and how far (in screen pixels) to shift the view up,
## e.g. to keep the scout above the phone's control panel.
func set_view(zoom: float, shift_up_px: float) -> void:
	if camera == null:
		return
	camera.zoom = Vector2(zoom, zoom)
	camera.offset = Vector2(0, shift_up_px / zoom)


func _process(delta: float) -> void:
	_locked_hint_cooldown = maxf(0.0, _locked_hint_cooldown - delta)
	if _timing and not finished:
		time_ms += int(delta * 1000.0)
	# Safety net: anything that falls out of the cave goes back to the start.
	if hero != null and hero.position.y > cave.pixel_size().y + 64:
		hero.place(CaveData.feet_position(cave.start))


func _on_gem(_gem: Gem) -> void:
	collected += 1
	gems_changed.emit(collected, total)
	if collected >= total:
		door.open()
		message.emit("All gems found! The exit is open.")


func _on_locked() -> void:
	if _locked_hint_cooldown > 0.0:
		return
	_locked_hint_cooldown = 3.0
	message.emit("Sealed! %d more gem%s to find." % [total - collected, "" if total - collected == 1 else "s"])


func _on_exit() -> void:
	if finished:
		return
	finished = true
	hero.controllable = false
	cleared.emit(result())


func result() -> Dictionary:
	return {
		"seed": cave.seed,
		"gen": cave.gen,
		"gems": collected,
		"time_ms": time_ms,
		"no_damage": no_damage,
		"score": Scoring.total(collected, time_ms, no_damage),
		"map": CaveThumbnail.make_base64(cave),
	}
