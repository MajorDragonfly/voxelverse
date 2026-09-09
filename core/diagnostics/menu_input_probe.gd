extends Node

## Explicit --input-smoke acceptance entry for release templates, which do not
## support --script. Uses real Viewport events and quits with a failure code.
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	var tree := get_tree()
	var settings := get_node("/root/DisplaySettings")
	get_node("/root/SaveGameService").autosave_enabled = false
	for frame in range(4):
		await tree.process_frame
	var old_mouse: int = Input.mouse_mode
	_key(KEY_F8)
	await tree.process_frame
	_expect(settings.is_menu_open() and tree.paused, "F8 did not open/pause the settings.")
	var vsync: CheckButton = settings._vsync_option
	var old_value: bool = vsync.button_pressed
	_click(vsync)
	await tree.process_frame
	_expect(vsync.button_pressed != old_value, "Paused settings ignored a real left click.")
	_click(settings._menu_panel.find_child("Apply", true, false))
	await tree.process_frame
	_expect(settings.vsync_enabled != old_value, "Apply did not use the clicked setting.")
	var config := ConfigFile.new()
	_expect(config.load(settings.CONFIG_PATH) == OK and bool(config.get_value("display", "vsync", old_value)) != old_value,
		"The selected setting was not saved.")
	_click(settings._menu_panel.find_child("Resume", true, false))
	await tree.process_frame
	_expect(not settings.is_menu_open() and not tree.paused, "Resume left the game paused.")
	_expect(Input.mouse_mode == old_mouse, "Resume changed the previous mouse mode.")
	_key(KEY_F8)
	await tree.process_frame
	_expect(settings.is_menu_open(), "F8 stopped opening the settings.")
	_key(KEY_ESCAPE)
	await tree.process_frame
	_expect(not settings.is_menu_open(), "Esc failed to close settings.")
	# F4 is tested with a physical-only key event, as well as the visible button.
	_key(KEY_F4, true)
	await tree.scene_changed
	_expect(tree.current_scene.scene_file_path == "res://world/planet_lab/planet_lab.tscn", "Exported F4 did not open the lab.")
	var lab: Node = tree.current_scene
	lab.walker.enabled = false
	_key(KEY_ESCAPE)
	await tree.process_frame
	_expect(settings.is_menu_open() and not settings._lab_button.visible, "Lab settings did not open correctly.")
	_key(KEY_ESCAPE)
	await tree.process_frame
	_expect(not tree.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Lab menu captured the previously visible cursor.")
	lab.return_to_game()
	await tree.scene_changed
	for frame in range(3):
		await tree.process_frame
	_key(KEY_F8)
	await tree.process_frame
	_click(settings._lab_button)
	await tree.scene_changed
	_expect(tree.current_scene.scene_file_path == "res://world/planet_lab/planet_lab.tscn" and not tree.paused,
		"The paused menu's Planet Lab button failed to transition.")
	lab = tree.current_scene
	lab._open_body("m1:aster")
	lab.walker.enabled = false
	_expect(lab.terrain.tiles.size() > 96 and lab.terrain.tiles.size() <= 768 and lab.terrain.active.size() == 24,
		"The packaged large planet did not publish adaptive terrain and collision.")
	var address: Dictionary = lab.walker.location()
	_expect(lab.save_lab(), "Large-planet save failed.")
	lab.load_lab()
	lab.walker.enabled = false
	_expect(lab.body_id == "m1:aster" and absf(float(lab.walker.location().u) - float(address.u)) < 0.000001,
		"Large-planet load did not restore the selected body and address.")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MENU_INPUT_PASSED: Esc, F8, actual paused GUI clicks, saved VSync, mouse restoration, physical F4, menu-to-lab round trip and adaptive Aster save/load.")
	tree.quit(0 if failures.is_empty() else 1)


func _key(code: Key, physical_only: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = 0 if physical_only else code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)


func _click(control: Control) -> void:
	if control == null:
		_expect(false, "Missing menu control.")
		return
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
