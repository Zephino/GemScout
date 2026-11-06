class_name SettingsScreen
extends RefCounted
## Settings: fullscreen, install / update the app (web), touch controls, and
## the account: Sign in with Google (to carry progress between phone and
## web), who you're signed in as, and your username (shown on the
## leaderboard instead of your Google name).

var root: Control
var _column: VBoxContainer
var _on_close: Callable
var _status: Label
var _account_box: VBoxContainer
var _name_edit: LineEdit
var _name_note: Label


func _init(on_close: Callable) -> void:
	_on_close = on_close
	var parts: Array = UiKit.screen("Settings", 480)
	root = parts[0]
	_column = parts[1]
	_build()
	Cloud.status_changed.connect(_refresh_account)
	Cloud.sign_in.changed.connect(_refresh_account)
	root.tree_exiting.connect(func() -> void:
		if Cloud.status_changed.is_connected(_refresh_account):
			Cloud.status_changed.disconnect(_refresh_account)
		if Cloud.sign_in.changed.is_connected(_refresh_account):
			Cloud.sign_in.changed.disconnect(_refresh_account))


func _section(text: String) -> void:
	var l := UiKit.label(text, 18, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_column.add_child(l)


func _build() -> void:
	_section("Display")
	if AppActions.can_fullscreen():
		var fs := UiKit.button("", func() -> void: pass)
		var fs_text := func() -> void: fs.text = "Fullscreen: " + ("On" if AppActions.is_fullscreen() else "Off")
		fs.pressed.connect(func() -> void:
			AppActions.toggle_fullscreen()
			# The browser switches a moment later.
			await root.get_tree().create_timer(0.3).timeout
			fs_text.call())
		fs_text.call()
		_column.add_child(fs)
	var touch := UiKit.button("", func() -> void: pass)
	var touch_text := func() -> void:
		touch.text = "Touch controls: " + {"auto": "Auto", "on": "On", "off": "Off"}[Save.setting("touch")]
	touch.pressed.connect(func() -> void:
		var order: Array[String] = ["auto", "on", "off"]
		Save.set_setting("touch", order[(order.find(Save.setting("touch")) + 1) % 3])
		touch_text.call())
	touch_text.call()
	_column.add_child(touch)

	if AppActions.is_web():
		_section("App")
		var state: String = AppActions.install_state()
		match state:
			"ready":
				_column.add_child(UiKit.button("Install app", func() -> void: AppActions.install()))
			"installed":
				_column.add_child(UiKit.label("Installed as an app.", 15, UiKit.GOOD))
			"ios":
				_column.add_child(UiKit.label("To install: tap Share, then Add to Home Screen.", 15, UiKit.MUTED))
			_:
				_column.add_child(UiKit.label("To install, use your browser's menu (Install app / Add to Home screen).", 15, UiKit.MUTED))
		_column.add_child(UiKit.button("Update app", func() -> void: AppActions.update_now()))
		_column.add_child(UiKit.label("Gets the newest version. Your progress is kept.", 13, UiKit.MUTED))

	_section("Account")
	_account_box = VBoxContainer.new()
	_column.add_child(_account_box)

	_section("Username")
	_column.add_child(UiKit.label("Shown on the leaderboard instead of your Google name. Letters, numbers, space, _ and -, up to 12.", 13, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var row := HBoxContainer.new()
	_name_edit = LineEdit.new()
	_name_edit.max_length = Save.MAX_USERNAME
	_name_edit.placeholder_text = "Your username"
	_name_edit.text = Save.username()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(0, 38)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
	row.add_child(_name_edit)
	row.add_child(UiKit.button("Save", _save_name, 90))
	_column.add_child(row)
	_name_note = UiKit.label("", 14, UiKit.MUTED)
	_column.add_child(_name_note)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_column.add_child(gap)
	_column.add_child(UiKit.button("Back", func() -> void: _on_close.call()))
	_refresh_account()
	UiKit.focus_first(_column)


func _save_name() -> void:
	var cleaned: String = Save.clean_username(_name_edit.text)
	if cleaned == "":
		_name_note.text = "Pick a name with at least one letter or number."
		_name_note.add_theme_color_override("font_color", UiKit.BAD)
		return
	Save.set_username(cleaned)
	_name_edit.text = cleaned
	_name_note.text = "Saved." + (" It will sync to your other devices." if CloudSync.signed_in() else "")
	_name_note.add_theme_color_override("font_color", UiKit.GOOD)


func _refresh_account() -> void:
	if _account_box == null:
		return
	for child in _account_box.get_children():
		child.queue_free()
	var sign_in: AccountSignIn = Cloud.sign_in
	if CloudSync.signed_in():
		var who: String = CloudSync.email()
		_account_box.add_child(UiKit.label("Signed in with Google" + (" as " + who if who != "" else ""), 15, UiKit.GOOD, HORIZONTAL_ALIGNMENT_LEFT))
		var sync_text: String = {"syncing": "Syncing your progress…", "synced": "Progress synced between your devices.", "error": "Couldn't sync right now; will try again.", "off": ""}[Cloud.state]
		_account_box.add_child(UiKit.label(sync_text, 13, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		_account_box.add_child(UiKit.button("Sign out", func() -> void: Cloud.sign_out()))
	elif sign_in.busy():
		_account_box.add_child(UiKit.label("Finish signing in on the Google page that opened, then come back here.", 15, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		_account_box.add_child(UiKit.button("Cancel", func() -> void: sign_in.cancel()))
	else:
		_account_box.add_child(UiKit.label("Not signed in. Sign in to carry your progress between your phone and the web.", 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		var b := UiKit.button("Sign in with Google", func() -> void: sign_in.start())
		b.disabled = not AccountSignIn.available()
		_account_box.add_child(b)
	if sign_in.error != "":
		_account_box.add_child(UiKit.label(sign_in.error, 14, UiKit.BAD, HORIZONTAL_ALIGNMENT_LEFT))
