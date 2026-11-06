extends Node
## The game's controls, set up in code so they're easy to read and change.
##
##   move_left / move_right   A/D, arrow keys, D-pad, left stick
##   jump                     Space, W, Up, Z, controller A (bottom button)
##   interact                 E, X, controller X (left button) — for levers later
##   shoot                    J, C, controller B (right button) — for the blaster later
##   pause                    Esc, P, controller Start
##
## On phones the on-screen buttons (TouchControls) press the same actions.

const STICK_DEADZONE := 0.35

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP, KEY_Z],
	"interact": [KEY_E, KEY_X],
	"shoot": [KEY_J, KEY_C],
	"pause": [KEY_ESCAPE, KEY_P],
}
const BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"jump": [JOY_BUTTON_A],
	"interact": [JOY_BUTTON_X],
	"shoot": [JOY_BUTTON_B],
	"pause": [JOY_BUTTON_START],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_actions()


static func setup_actions() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, STICK_DEADZONE)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button: int in BUTTONS[action]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = button
			InputMap.action_add_event(action, jb)
	for pair: Array in [["move_left", -1.0], ["move_right", 1.0]]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = JOY_AXIS_LEFT_X
		axis.axis_value = pair[1]
		InputMap.action_add_event(pair[0], axis)
