class_name DifficultyScreen
extends RefCounted
## Pick a difficulty before a cave: it sets your hearts and the blaster.

var root: Control


func _init(on_pick: Callable, on_back: Callable) -> void:
	var parts: Array = UiKit.screen("Choose difficulty", 420)
	root = parts[0]
	var column: VBoxContainer = parts[1]
	var last: String = Difficulty.valid(Save.setting("difficulty"))
	var first: Button = null
	for id in Difficulty.IDS:
		var b := UiKit.button(Difficulty.label(id), func() -> void:
			Save.set_setting("difficulty", id)
			on_pick.call(id))
		column.add_child(b)
		column.add_child(UiKit.label(str(Difficulty.get_value(id, "about")), 13, UiKit.MUTED))
		if id == last:
			first = b
	column.add_child(UiKit.label("Each difficulty has its own leaderboard.", 13, UiKit.MUTED))
	column.add_child(UiKit.button("Back", func() -> void: on_back.call()))
	if first != null:
		first.call_deferred("grab_focus")
