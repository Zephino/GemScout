class_name PauseMenu
extends RefCounted
## Paused: carry on, restart this cave, or leave it. Restarting or leaving
## throws away this cave's progress (the design: leaving early resets it).

var root: Control


func _init(seed: int, on_resume: Callable, on_restart: Callable, on_leave: Callable) -> void:
	var parts: Array = UiKit.screen("Paused", 360)
	root = parts[0]
	var column: VBoxContainer = parts[1]
	column.add_child(UiKit.button("Resume", func() -> void: on_resume.call()))
	column.add_child(UiKit.button("Restart cave", func() -> void: on_restart.call()))
	column.add_child(UiKit.button("Leave cave", func() -> void: on_leave.call()))
	column.add_child(UiKit.label("Restarting or leaving loses this cave's gems.", 13, UiKit.MUTED))
	column.add_child(UiKit.label("Cave seed %d" % seed, 13, UiKit.MUTED))
	UiKit.focus_first(column)
