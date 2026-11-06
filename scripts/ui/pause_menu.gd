class_name PauseMenu
extends RefCounted
## Paused: carry on, get unstuck (back to the last safe spot, keeping your
## gems), restart this cave, or leave it. Restarting or leaving throws away
## this cave's progress (the design: leaving early resets it).

var root: Control


func _init(seed: int, on_resume: Callable, on_restart: Callable, on_leave: Callable, on_unstick: Callable = Callable()) -> void:
	var parts: Array = UiKit.screen("Paused", 360)
	root = parts[0]
	UiKit.keep_alive(root, self)
	var column: VBoxContainer = parts[1]
	column.add_child(UiKit.button("Resume", func() -> void: on_resume.call()))
	if on_unstick.is_valid():
		column.add_child(UiKit.button("I'm stuck", func() -> void: on_unstick.call()))
	column.add_child(UiKit.button("Restart cave", func() -> void: on_restart.call()))
	column.add_child(UiKit.button("Leave cave", func() -> void: on_leave.call()))
	column.add_child(UiKit.label("I'm stuck puts you back on safe ground and keeps your gems. Restarting or leaving loses this cave's gems.", 13, UiKit.MUTED))
	column.add_child(UiKit.label("Cave seed %d" % seed, 13, UiKit.MUTED))
	UiKit.focus_first(column)
