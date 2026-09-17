extends SceneTree
const Preferences = preload("res://core/input_preferences.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await process_frame
	await process_frame
	var prefs := Preferences.new()
	var path: String = "user://camera-preferences.cfg"
	var config := ConfigFile.new()
	var old := Preferences.defaults()
	old.move_left = [KEY_LEFT, 0]
	old.inspection_mode = [-3, 0]
	for action: String in old:
		if action not in Preferences.CAMERA_DEFAULTS: config.set_value("bindings", action, old[action])
	config.save(path)
	prefs.load_saved(path)
	_check(prefs.bindings.move_left == old.move_left and prefs.bindings.inspection_mode == old.inspection_mode, "Adding camera actions replaced an old arrow/mouse binding.")
	_check(Preferences.validate(prefs.bindings).is_empty(), "Migrated camera actions conflict with older keys.")
	var options := {"pan_speed": 2.1, "tilt": 38.0}
	_check(prefs.save_and_apply(prefs.bindings, 1.5, true, 0, path, options).is_empty(), "Could not save camera comfort settings.")
	var loaded := Preferences.new()
	loaded.load_saved(path)
	_check(loaded.tribe_camera == options and loaded.bindings == prefs.bindings, "Fresh preference instance lost saved camera values or keys.")
	var bytes: String = FileAccess.get_file_as_string(path)
	for invalid: Dictionary in [{"pan_speed": NAN, "tilt": 55.0}, {"pan_speed": 0.0, "tilt": 55.0}, {"pan_speed": 1.0, "tilt": 90.0}]:
		_check(not prefs.save_and_apply(prefs.bindings, 1.0, false, 0, path, invalid).is_empty(), "Invalid camera settings were accepted.")
	_check(not prefs.save_and_apply(prefs.bindings, 1.0, false, 0, "user://missing/settings.cfg", Preferences.TRIBE_CAMERA_DEFAULTS).is_empty(), "Failed camera write reported success.")
	_check(prefs.tribe_camera == options and FileAccess.get_file_as_string(path) == bytes, "Rejected settings changed the file or live camera.")
	# Exercise the real Esc draft: Reset must wait for Apply, and Refresh discards drafts.
	var settings: Node = root.get_node("DisplaySettings")
	settings.open_menu()
	var controls: VBoxContainer = settings._control_settings
	var live: Dictionary = settings.input_preferences.tribe_camera.duplicate()
	controls.tribe_camera.pan_speed.value = 1.8
	controls.tribe_camera.tilt.value = 42.0
	_check(settings.input_preferences.tribe_camera == live, "Draft sliders applied before confirmation.")
	_check(controls.apply().is_empty(), "Esc controls could not save camera sliders.")
	loaded.load_saved()
	_check(loaded.tribe_camera == {"pan_speed": 1.8, "tilt": 42.0}, "Esc settings did not survive a fresh read.")
	controls._reset()
	_check(settings.input_preferences.tribe_camera == loaded.tribe_camera, "Reset applied before Save.")
	controls.refresh()
	_check(controls.tribe_camera.values() == loaded.tribe_camera, "Closing/discarding draft lost active values.")
	settings.close_menu()
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("TRIBAL_CAMERA_PREFERENCES_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
