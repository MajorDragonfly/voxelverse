extends SceneTree
const Preferences = preload("res://core/input_preferences.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await process_frame
	await process_frame
	if "--r32-camera-restart" in OS.get_cmdline_user_args():
		await _restart_check()
		return
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
	_check(prefs.bindings.tribe_turn_left[0] == KEY_Q and prefs.bindings.tribe_turn_right[0] == KEY_E, "Old profiles did not receive phase-specific Q/E rotation.")
	_check(Preferences.validate(prefs.bindings).is_empty(), "Migrated camera actions conflict with older keys.")
	var previous_camera := ConfigFile.new()
	for action: String in Preferences.ACTIONS:
		previous_camera.set_value("bindings", action, Preferences.defaults()[action])
	previous_camera.set_value("bindings", "tribe_turn_left", [KEY_LEFT, 0])
	previous_camera.set_value("bindings", "tribe_turn_right", [KEY_RIGHT, 0])
	previous_camera.save(path)
	prefs.load_saved(path)
	_check(prefs.bindings.tribe_turn_left == [KEY_Q, KEY_LEFT] and prefs.bindings.tribe_turn_right == [KEY_E, KEY_RIGHT], "Saved arrow-only camera did not gain Q/E while retaining arrows.")
	var options := {"pan_speed": 2.1, "tilt": 38.0}
	_check(prefs.save_and_apply(prefs.bindings, 1.5, true, 0, path, options).is_empty(), "Could not save camera comfort settings.")
	var loaded := Preferences.new()
	loaded.load_saved(path)
	_check(loaded.tribe_camera == options and loaded.bindings == prefs.bindings, "Fresh preference instance lost saved camera values or keys.")
	options.tilt = 3.0
	_check(prefs.save_and_apply(prefs.bindings, 1.5, true, 0, path, options).is_empty(), "Eye-level tilt could not be saved.")
	loaded.load_saved(path)
	_check(loaded.tribe_camera.tilt == 3.0, "Eye-level tilt did not survive a fresh read.")
	options.tilt = 38.0
	prefs.save_and_apply(prefs.bindings, 1.5, true, 0, path, options)
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
	# Explicit camera rebindings must survive a real process restart without
	# gaining Q/E again. Old arrows stay usable; Q/E retain creature actions.
	var rebound: Dictionary = settings.input_preferences.bindings.duplicate(true)
	rebound.tribe_turn_left = [KEY_Z, KEY_LEFT]
	rebound.tribe_turn_right = [KEY_X, KEY_RIGHT]
	_check(settings.input_preferences.save_and_apply(rebound, 1.25, false, 60, Preferences.CONFIG_PATH, {"pan_speed": 2.1, "tilt": 3.0}).is_empty(), "Camera rebinding could not be saved.")
	_check(_pressed(KEY_Z, "tribe_turn_left") and _pressed(KEY_X, "tribe_turn_right") and _pressed(KEY_LEFT, "tribe_turn_left") and _pressed(KEY_RIGHT, "tribe_turn_right"), "Rebinding/arrow alternative did not reach InputMap.")
	_check(not _pressed(KEY_Q, "tribe_turn_left") and not _pressed(KEY_E, "tribe_turn_right") and _pressed(KEY_Q, "bite_action") and _pressed(KEY_E, "inspection_mode"), "Rebinding retained obsolete turn keys or removed creature Q/E.")
	var conflict: Dictionary = rebound.duplicate(true)
	conflict.move_left = [KEY_Z, 0]
	_check(not Preferences.validate(conflict).is_empty(), "Rebound camera/movement conflict was accepted.")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/tribal_camera_preferences_test.gd", "--", "--r32-camera-restart"]), output, true)
	var child_log: String = str(output)
	_check(code == 0 and "R32_04_CAMERA_PREF_RESTART_PASSED" in child_log and not "SCRIPT ERROR" in child_log and not "ERROR:" in child_log and not "ObjectDB instances leaked" in child_log, "Fresh process lost camera preferences/rebindings: " + child_log)
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("TRIBAL_CAMERA_PREFERENCES_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _pressed(code: Key, action: String) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event.is_action_pressed(action)

func _restart_check() -> void:
	var prefs: RefCounted = root.get_node("DisplaySettings").input_preferences
	_check(prefs.tribe_camera == {"pan_speed": 2.1, "tilt": 3.0} and prefs.sensitivity == 1.25 and prefs.fps_limit == 60, "Restart lost camera settings.")
	_check(prefs.bindings.tribe_turn_left == [KEY_Z, KEY_LEFT] and prefs.bindings.tribe_turn_right == [KEY_X, KEY_RIGHT], "Restart replaced explicit turn bindings.")
	_check(_pressed(KEY_Z, "tribe_turn_left") and _pressed(KEY_LEFT, "tribe_turn_left") and _pressed(KEY_X, "tribe_turn_right") and _pressed(KEY_RIGHT, "tribe_turn_right") and not _pressed(KEY_Q, "tribe_turn_left") and not _pressed(KEY_E, "tribe_turn_right"), "Restart InputMap disagrees with saved camera bindings.")
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("R32_04_CAMERA_PREF_RESTART_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
