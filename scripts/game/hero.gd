class_name Hero
extends CharacterBody2D
## The scout. Runs, jumps (hold for higher, let go early for a hop), and can
## still jump a moment after running off a ledge ("coyote time") or when
## jump is pressed just before landing ("jump buffer"), so it feels fair.
##
## The node's origin is at the feet. Collision is a 10 x 20 capsule; the
## cave generator plans with a bigger box and a weaker jump than these, so
## every gem it places can really be reached (see Reachability).

signal landed

const RUN_SPEED := 140.0
const GROUND_ACCEL := 1400.0
const AIR_ACCEL := 1000.0
const FRICTION := 1600.0
const GRAVITY := 980.0
const JUMP_VELOCITY := -420.0
## Rising speed is cut to this share when jump is let go early.
const JUMP_CUT := 0.45
const MAX_FALL := 560.0
const COYOTE_S := 0.1
const BUFFER_S := 0.12

const FRAME_IDLE := 0
const FRAMES_RUN: Array[int] = [1, 2, 3, 4]
const FRAME_JUMP := 5
const FRAME_FALL := 6

## False while paused, in a menu, or after the cave is cleared.
var controllable: bool = true

var _sprite: Sprite2D
var _coyote: float = 0.0
var _buffer: float = 0.0
var _run_time: float = 0.0
var _was_on_floor: bool = true


func _ready() -> void:
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 6.0
	floor_constant_speed = true
	safe_margin = 0.5
	var shape := CapsuleShape2D.new()
	shape.radius = 5.0
	shape.height = 20.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, -10)
	add_child(collider)
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/hero.png")
	_sprite.hframes = 7
	_sprite.position = Vector2(0, -12)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	var dir: float = 0.0
	var jump_pressed: bool = false
	var jump_held: bool = false
	if controllable:
		dir = Input.get_axis("move_left", "move_right")
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")

	# Timers that make jumping forgiving.
	_coyote = COYOTE_S if is_on_floor() else maxf(0.0, _coyote - delta)
	_buffer = BUFFER_S if jump_pressed else maxf(0.0, _buffer - delta)

	# Gravity, with a cap so long falls stay readable.
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
	elif not jump_held and velocity.y < JUMP_VELOCITY * JUMP_CUT:
		# Let go early: stop rising fast, for a short hop.
		velocity.y = JUMP_VELOCITY * JUMP_CUT

	# Running: quick to start, quick to stop.
	var target: float = dir * RUN_SPEED
	var accel: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	if dir == 0.0 and is_on_floor():
		accel = FRICTION
	velocity.x = move_toward(velocity.x, target, accel * delta)

	move_and_slide()
	if is_on_ceiling() and velocity.y < 0.0:
		velocity.y = 0.0
	if is_on_floor() and not _was_on_floor:
		landed.emit()
	_was_on_floor = is_on_floor()
	_animate(dir, delta)


func _animate(dir: float, delta: float) -> void:
	if dir != 0.0:
		_sprite.flip_h = dir < 0.0
	if not is_on_floor():
		_sprite.frame = FRAME_JUMP if velocity.y < 0.0 else FRAME_FALL
		return
	if absf(velocity.x) > 10.0:
		_run_time += delta * absf(velocity.x) / RUN_SPEED
		_sprite.frame = FRAMES_RUN[int(_run_time * 10.0) % FRAMES_RUN.size()]
	else:
		_run_time = 0.0
		_sprite.frame = FRAME_IDLE


## Puts the scout somewhere, standing still.
func place(feet: Vector2) -> void:
	position = feet - Vector2(0, 1)
	velocity = Vector2.ZERO
