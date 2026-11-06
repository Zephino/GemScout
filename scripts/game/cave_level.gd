class_name CaveLevel
extends Node2D
## One cave being played: builds it from a seed (terrain, gems, exit, doors
## and levers, beams and switches, Bouldermaws, spikes, enemies, pickups,
## the scout and the camera), and runs it: hearts, the blaster's ammo,
## power-ups, the timer and the gem count. Reports when the cave is cleared
## or the scout runs out of hearts. Leaving or restarting throws the
## progress away (a new CaveLevel is made), as the design asks.

signal gems_changed(collected: int, total: int)
signal hearts_changed(hearts: int, max_hearts: int)
signal ammo_changed(ammo: int)
signal powers_changed
signal message(text: String)
signal cleared(result: Dictionary)
signal died

const POWER_SHOT_S := 15.0
const GRAVITY_S := 10.0
const FREEZE_S := 10.0
## After reverse gravity ends: how long to watch for the scout landing
## somewhere it could be stuck, and how long it may stand there.
const RESCUE_WATCH_S := 8.0
const RESCUE_AFTER_S := 0.8

var cave: CaveData
var shape: CaveShape
var hero: Hero
var camera: Camera2D
var door: ExitDoor
var difficulty: String = "medium"
var collected: int = 0
var total: int = 0
var time_ms: int = 0
var no_damage: bool = true
var finished: bool = false
var dead: bool = false

var hearts: int = 3
var max_hearts: int = 3
## Shots left; -1 = unlimited (Easy).
var ammo: int = 6
var power_shot_left: float = 0.0
var gravity_left: float = 0.0
var freeze_left: float = 0.0

var gates: Array[GateDoor] = []
var levers: Array[Lever] = []
var beams: Array[CrystalBeam] = []
var switches: Array[BeamSwitch] = []
var boulders: Array[Bouldermaw] = []
var enemies: Array[Node] = []
var pickups: Array[Pickup] = []
var spikes: Spikes

var _timing: bool = false
var _hint_cooldown: float = 0.0
var _cooldown: float = 0.0
var _recharge: float = 0.0
var _last_safe := Vector2i(-1, -1)
var _rescue_watch: float = 0.0
var _unsafe_for: float = 0.0
var _hinted_interact: bool = false


## Builds the cave for `seed` (takes a moment: call after showing "Digging…").
func build(seed: int, difficulty_id: String = "medium") -> void:
	build_from(CaveGenerator.generate(seed), difficulty_id)


## Builds a given cave (tests use small hand-made ones).
func build_from(made: CaveData, difficulty_id: String = "medium") -> void:
	var seed: int = made.seed
	difficulty = Difficulty.valid(difficulty_id)
	max_hearts = Difficulty.get_value(difficulty, "hearts")
	hearts = max_hearts
	ammo = Difficulty.get_value(difficulty, "ammo")
	cave = made
	shape = CaveShape.new(cave)
	var terrain := CaveTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(cave, shape)

	spikes = Spikes.new()
	spikes.setup(cave.spikes)
	add_child(spikes)

	door = ExitDoor.new()
	door.position = CaveData.feet_position(cave.exit)
	door.entered.connect(_on_exit)
	door.bumped_locked.connect(_on_locked)
	add_child(door)

	for d: Dictionary in cave.doors:
		var gate := GateDoor.new()
		gate.setup(d["color"], d["rect"])
		add_child(gate)
		gates.append(gate)
		var lever := Lever.new()
		lever.setup(d["color"], d["lever"])
		add_child(lever)
		levers.append(lever)
	for b: Dictionary in cave.beams:
		var beam := CrystalBeam.new()
		beam.setup(b["rect"])
		add_child(beam)
		beams.append(beam)
		var sw := BeamSwitch.new()
		sw.setup(b["switch"], beam)
		add_child(sw)
		switches.append(sw)
	for b: Dictionary in cave.boulders:
		var boulder := Bouldermaw.new()
		boulder.level = self
		boulder.setup(b["rect"])
		add_child(boulder)
		boulders.append(boulder)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "gem colours"])
	for cell in cave.gems:
		var gem := Gem.new()
		# Gems float at the scout's chest height above the spot.
		gem.setup(CaveData.feet_position(cell) - Vector2(0, 11), rng.randi_range(0, 4))
		gem.collected.connect(_on_gem)
		add_child(gem)
	total = cave.gems.size()

	for p: Dictionary in cave.pickups:
		if p["type"] == "ammo" and not Difficulty.get_value(difficulty, "crates"):
			continue
		var pickup := Pickup.new()
		pickup.setup(p["type"], p["cell"])
		add_child(pickup)
		pickups.append(pickup)

	for e: Dictionary in cave.enemies:
		var enemy: Enemy
		match e["type"]:
			"shellback":
				enemy = Shellback.new()
			"glowmoth":
				enemy = Glowmoth.new()
			"dripjaw":
				enemy = Dripjaw.new()
			"spitter":
				enemy = Spitter.new()
		if enemy == null:
			continue
		enemy.level = self
		enemy.setup(e)
		add_child(enemy)
		enemies.append(enemy)

	hero = Hero.new()
	hero.name = "Hero"
	add_child(hero)
	hero.place(CaveData.feet_position(cave.start))
	hero.shoot_pressed.connect(shoot)
	hero.interact_pressed.connect(interact)
	_last_safe = cave.start

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
	hearts_changed.emit(hearts, max_hearts)
	ammo_changed.emit(ammo)


## How much to zoom and how far (in screen pixels) to shift the view up,
## e.g. to keep the scout above the phone's control panel.
func set_view(zoom: float, shift_up_px: float) -> void:
	if camera == null:
		return
	camera.zoom = Vector2(zoom, zoom)
	camera.offset = Vector2(0, shift_up_px / zoom)


# --- Questions other parts ask ------------------------------------------------

## Rock or a closed door here (shots and globs stop).
func is_blocked(p: Vector2) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= cave.pixel_size().x or p.y >= cave.pixel_size().y:
		return true
	if shape.is_rock_at(p):
		return true
	for g in gates:
		if g.blocks(p):
			return true
	return false


## The floor's height near x (for walking enemies), close to `near_y`.
func floor_y_at(x: float, near_y: float) -> float:
	var cx: int = roundi(x / CaveData.CELL_SIZE) - 1
	var cy: int = int(near_y / CaveData.CELL_SIZE) - 1
	for dy: int in [0, -1, 1, -2, 2]:
		for dx: int in [0, -1, 1]:
			if cave.safe.has(Vector2i(cx + dx, cy + dy)):
				return lerpf(near_y, float((cy + dy + 1) * CaveData.CELL_SIZE), 0.25)
	return near_y


func enemies_alive() -> Array[Node]:
	var out: Array[Node] = []
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			out.append(e)
	for c in get_children():
		if c is Glob and c.alive:
			out.append(c)
	return out


func hero_body() -> Rect2:
	return Rect2(hero.position.x - 5.0, hero.position.y - 20.0, 10.0, 20.0)


# --- Every frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	_hint_cooldown = maxf(0.0, _hint_cooldown - delta)
	if _timing and not finished and not dead:
		time_ms += int(delta * 1000.0)
	# Safety net: anything that falls out of the cave goes back to the start.
	if hero != null and (hero.position.y > cave.pixel_size().y + 64 or hero.position.y < -64):
		hero.set_reverse_gravity(false)
		gravity_left = 0.0
		hero.place(CaveData.feet_position(_last_safe))


func _physics_process(delta: float) -> void:
	if hero == null or finished or dead:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_tick_powers(delta)
	_tick_recharge(delta)
	_check_touches()
	_check_pickups()
	_update_near()
	_watch_safety(delta)


func _tick_powers(delta: float) -> void:
	var before: Array = [power_shot_left > 0.0, gravity_left > 0.0, freeze_left > 0.0]
	power_shot_left = maxf(0.0, power_shot_left - delta)
	freeze_left = maxf(0.0, freeze_left - delta)
	if gravity_left > 0.0:
		gravity_left = maxf(0.0, gravity_left - delta)
		if gravity_left == 0.0:
			hero.set_reverse_gravity(false)
			_rescue_watch = RESCUE_WATCH_S
	var after: Array = [power_shot_left > 0.0, gravity_left > 0.0, freeze_left > 0.0]
	if before != after or power_shot_left > 0.0 or gravity_left > 0.0 or freeze_left > 0.0:
		powers_changed.emit()


## Medium and Hard: an empty blaster slowly recharges one shot.
func _tick_recharge(delta: float) -> void:
	if ammo != 0:
		_recharge = 0.0
		return
	_recharge += delta
	if _recharge >= Difficulty.RECHARGE_S:
		_recharge = 0.0
		ammo = 1
		ammo_changed.emit(ammo)
		message.emit("Your blaster recharged one shot.")


func recharge_progress() -> float:
	return _recharge / Difficulty.RECHARGE_S if ammo == 0 else 0.0


func _check_touches() -> void:
	var body: Rect2 = hero_body()
	if spikes.hurts(body):
		hurt(hero.position + Vector2(0, 4))
		return
	for b in beams:
		if b.hurts(body):
			hurt(b.rect.get_center())
			return
	for e in enemies_alive():
		if e.touches(hero.center()):
			hurt(e.body_center())
			return


func _check_pickups() -> void:
	for p in pickups.duplicate():
		if not is_instance_valid(p) or p.position.distance_to(hero.center()) > 13.0:
			continue
		match p.type:
			"heart":
				if hearts >= max_hearts:
					continue
				hearts += 1
				hearts_changed.emit(hearts, max_hearts)
				message.emit("+1 heart")
			"ammo":
				ammo += Difficulty.CRATE_AMMO
				ammo_changed.emit(ammo)
				message.emit("+%d shots" % Difficulty.CRATE_AMMO)
			"power_shot":
				power_shot_left = POWER_SHOT_S
				message.emit("Power shot! Shots go through enemies.")
			"gravity":
				gravity_left = GRAVITY_S
				hero.set_reverse_gravity(true)
				message.emit("Reverse gravity! Walk on the ceiling.")
			"freeze":
				freeze_left = FREEZE_S
				message.emit("Freeze! Enemies can't move or hurt you.")
			"shield":
				hero.shielded = true
				message.emit("Shield! Your next hit is free.")
		pickups.erase(p)
		p.take()
		powers_changed.emit()


## Shows the arrow over a lever or switch the scout can use.
func _update_near() -> void:
	var target: Node2D = _interactable()
	for l in levers:
		l.near = l == target
	for s in switches:
		s.near = s == target
	if target != null and not _hinted_interact:
		_hinted_interact = true
		message.emit("Press E (controller X, or the hand button) to use it.")


func _interactable() -> Node2D:
	var best: Node2D = null
	var best_d: float = 18.0
	for n: Node2D in levers + switches:
		if n is Lever and n.pulled:
			continue
		var d: Vector2 = n.position - hero.position
		if absf(d.x) < best_d and absf(d.y) < 26.0:
			best_d = absf(d.x)
			best = n
	return best


## After reverse gravity: if the scout lands somewhere the cave check never
## saw as safe, bring them back to the last safe spot (so they can't get stuck).
func _watch_safety(delta: float) -> void:
	if not hero.is_on_floor() or hero.gravity_sign < 0:
		return
	var cell := Vector2i(roundi(hero.position.x / CaveData.CELL_SIZE) - 1, int((hero.position.y - 1.0) / CaveData.CELL_SIZE))
	var safe: bool = false
	for dy: int in [0, -1, 1]:
		for dx: int in [0, -1, 1]:
			if cave.safe.has(cell + Vector2i(dx, dy)):
				safe = true
				if dx == 0 and dy == 0:
					_last_safe = cell
	if _rescue_watch > 0.0:
		_rescue_watch -= delta
		_unsafe_for = 0.0 if safe else _unsafe_for + delta
		if _unsafe_for >= RESCUE_AFTER_S:
			_unsafe_for = 0.0
			_rescue_watch = 0.0
			hero.place(CaveData.feet_position(_last_safe))
			message.emit("Whoa! Back to safe ground.")


# --- Actions ------------------------------------------------------------------

func shoot() -> void:
	if finished or dead or _cooldown > 0.0:
		return
	if ammo == 0:
		if _hint_cooldown <= 0.0:
			_hint_cooldown = 2.0
			message.emit("Out of shots! It recharges in a moment.")
		return
	_cooldown = Difficulty.get_value(difficulty, "cooldown")
	if ammo > 0:
		ammo -= 1
		ammo_changed.emit(ammo)
	var bullet := Bullet.new()
	bullet.level = self
	bullet.dir = hero.facing
	bullet.power = power_shot_left > 0.0
	bullet.position = hero.muzzle()
	add_child(bullet)


func interact() -> void:
	var target: Node2D = _interactable()
	if target is Lever:
		var lever: Lever = target
		if lever.pull():
			var opened: int = 0
			for g in gates:
				if g.color == lever.color:
					g.open()
					opened += 1
			message.emit("The %s door%s opened!" % [GateDoor.NAMES[lever.color], "s" if opened > 1 else ""])
	elif target is BeamSwitch:
		var sw: BeamSwitch = target
		sw.toggle()
		message.emit("Beam off." if not sw.beam.on else "Beam on.")


## The scout touched something dangerous at `from`.
func hurt(from: Vector2) -> void:
	if finished or dead or hero.invulnerable_left > 0.0:
		return
	if hero.shielded:
		hero.shielded = false
		hero.knock_back(from)
		message.emit("Your shield took the hit!")
		powers_changed.emit()
		return
	hearts -= 1
	no_damage = false
	hero.knock_back(from)
	hearts_changed.emit(hearts, max_hearts)
	if hearts <= 0:
		dead = true
		hero.controllable = false
		died.emit()


func _on_gem(_gem: Gem) -> void:
	collected += 1
	gems_changed.emit(collected, total)
	if collected >= total:
		door.open()
		message.emit("All gems found! The exit is open.")


func _on_locked() -> void:
	if _hint_cooldown > 0.0:
		return
	_hint_cooldown = 3.0
	message.emit("Sealed! %d more gem%s to find." % [total - collected, "" if total - collected == 1 else "s"])


func _on_exit() -> void:
	if finished or dead:
		return
	finished = true
	hero.controllable = false
	cleared.emit(result())


func result() -> Dictionary:
	return {
		"seed": cave.seed,
		"gen": cave.gen,
		"difficulty": difficulty,
		"gems": collected,
		"time_ms": time_ms,
		"no_damage": no_damage,
		"score": Scoring.total(collected, time_ms, no_damage),
		"map": CaveThumbnail.make_base64(cave),
	}
