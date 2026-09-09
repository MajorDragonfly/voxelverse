extends SceneTree

const Preferences = preload("res://core/input_preferences.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var prefs := Preferences.new()
	var path := "user://preferences-contract.cfg"
	var candidate := Preferences.defaults()
	candidate.inspection_mode = [KEY_R, 0]
	candidate.move_forward = [KEY_UP, 0]
	_expect(prefs.save_and_apply(candidate, 1.5, true, 120, path).is_empty(), "Could not save valid preferences.")
	_expect(Engine.max_fps == 120, "FPS cap did not reach the engine.")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	event.pressed = true
	_expect(event.is_action_pressed("inspection_mode"), "New key is not bound to the live action.")
	event.physical_keycode = KEY_E
	_expect(not event.is_action_pressed("inspection_mode"), "Old key remained bound.")
	var loaded := Preferences.new()
	loaded.load_saved(path)
	_expect(loaded.bindings == candidate and is_equal_approx(loaded.sensitivity, 1.5) and loaded.invert_y and loaded.fps_limit == 120, "Saved settings did not round-trip.")
	_expect(loaded.camera_motion(Vector2(10, 20), 0.01).is_equal_approx(Vector2(0.15, -0.3)), "Camera sensitivity/inversion changed the wrong axes.")
	var previous: String = FileAccess.get_file_as_string(path)
	var invalid := candidate.duplicate(true)
	invalid.move_back = [KEY_UP, 0]
	_expect(not prefs.save_and_apply(invalid, 1.0, false, 0, path).is_empty(), "Duplicate key was accepted.")
	invalid = candidate.duplicate(true)
	invalid.jump = [KEY_J, 0]
	_expect(not Preferences.validate(invalid).is_empty(), "Journal shortcut was accepted as a game key.")
	invalid.jump = [KEY_K, 0]
	_expect(not Preferences.validate(invalid).is_empty(), "Skilltree shortcut was accepted as a game key.")
	invalid.jump = [0, 0]
	_expect(not Preferences.validate(invalid).is_empty(), "Action with no remaining binding was accepted.")
	_expect(not prefs.save_and_apply(candidate, 1.0, false, 60, "user://no-preference-directory/settings.cfg").is_empty(), "Failed save reported success.")
	_expect(prefs.bindings == candidate and is_equal_approx(prefs.sensitivity, 1.5) and prefs.invert_y and Engine.max_fps == 120, "Failed save changed active preferences.")
	_expect(FileAccess.get_file_as_string(path) == previous, "Rejected changes overwrote the saved preferences.")
	var config := ConfigFile.new()
	config.set_value("bindings", "jump", [KEY_F8, 0])
	config.set_value("camera", "sensitivity", "bad")
	config.set_value("camera", "invert_y", "bad")
	config.set_value("display", "fps_limit", -10)
	config.save(path)
	loaded.load_saved(path)
	_expect(loaded.bindings == Preferences.defaults() and loaded.sensitivity == 1.0 and not loaded.invert_y and loaded.fps_limit == 0 and not loaded.load_message.is_empty(), "Damaged preferences did not safely fall back.")
	_expect(loaded.save_and_apply(candidate, 1.25, false, 60, path).is_empty(), "Existing preferences could not be replaced atomically.")
	loaded.load_saved(path)
	_expect(loaded.bindings == candidate and is_equal_approx(loaded.sensitivity, 1.25) and loaded.fps_limit == 60, "Replacement preferences were not persisted.")
	loaded.bindings = Preferences.defaults()
	loaded.fps_limit = 0
	loaded.apply_runtime()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("INPUT_PREFERENCES_PASSED: remapping, persistence, camera axes, frame cap, conflicts, reserved keys, failed writes and damaged-file fallback.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
