extends Node

## Explicit --input-smoke acceptance entry for release templates, which do not
## support --script. Uses real Viewport events and quits with a failure code.
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	var tree := get_tree()
	# Headless windows default to 64x64; use an actual supported test extent.
	tree.root.size = Vector2i(1280, 720)
	var settings := get_node("/root/DisplaySettings")
	get_node("/root/SaveGameService").autosave_enabled = false
	# The water/GUI acceptance needs a reproducible actual world. A random
	# starting planet can have no ocean inside this deliberately small fixture.
	get_node("/root/SaveGameService").create_slot("Historical GUI fixture", 15838, "legacy_plane_v9")
	await tree.process_frame
	_expect(tree.change_scene_to_file("res://core/diagnostics/legacy_world.tscn") == OK, "The native acceptance world failed to load.")
	await tree.scene_changed
	for frame in range(4):
		await tree.process_frame
	_expect(get_node("/root/WorldGenerator").get_planet_profile().planet_seed == 15838,
		"Native water/GUI acceptance did not use its deterministic world.")
	await _probe_underwater_camera()
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
	_expect(tree.current_scene.scene_file_path == "res://ui/frontend/main_menu.tscn", "Legacy diagnostic returned to a playable plane.")
	# Continue this historical GUI fixture explicitly. Production lab returns
	# restore a spherical campaign or leave the player at the title screen.
	get_node("/root/SaveGameService").session_active = true
	_expect(tree.change_scene_to_file("res://core/diagnostics/legacy_world.tscn") == OK, "Legacy regression fixture could not resume.")
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
	await tree.process_frame
	_click(lab.find_child("OpenTerra", true, false))
	for frame in range(8):
		await tree.process_frame
		if lab.body_id == "m1b:terra":
			break
	lab.walker.enabled = false
	_expect(lab.body_id == "m1b:terra" and lab.system.bodies[lab.body_id].radius == 6371000.0,
		"The packaged Terra button did not open a physically Earth-sized planet.")
	_expect(lab.terrain.layout.max_level == 19 and lab.terrain.active.size() == 24,
		"The packaged Earth did not retain local voxel detail and collision.")
	_expect(lab.save_lab() and lab.snapshot().schema == 3, "The packaged Earth save failed.")
	address = lab.walker.location()
	lab.load_lab()
	lab.walker.enabled = false
	var cube = preload("res://world/space/cube_sphere.gd")
	_expect(lab.body_id == "m1b:terra" and cube.local_position(cube.cartesian(address, 6371000.0),
		cube.cartesian(lab.walker.location(), 6371000.0)).length() < 0.001, "The packaged Earth save lost millimetre location precision.")
	await tree.process_frame
	_click(lab.find_child("OpenGalaxy", true, false))
	await tree.process_frame
	await tree.process_frame
	var panel: Node = lab.galaxy_panel
	_expect(is_instance_valid(panel) and not panel.systems.is_empty() and not panel.record.is_empty(), "Packaged Galaxy button did not open usable catalog metadata.")
	if is_instance_valid(panel) and not panel.record.is_empty():
		var original_body: String = lab.body_id
		panel.note.text = "Native Eingabe und Wiederbesuch"
		_click(panel.save_button)
		await tree.process_frame
		_expect(panel.record.note == "Native Eingabe und Wiederbesuch", "Native Galaxy save click failed.")
		_key(KEY_ESCAPE)
		await tree.process_frame
		_expect(not is_instance_valid(lab.galaxy_panel) and not settings.is_menu_open() and lab.body_id == original_body, "Escape opened settings or changed the body behind the Galaxy panel.")
		_click(lab.find_child("OpenGalaxy", true, false))
		await tree.process_frame
		_expect(is_instance_valid(lab.galaxy_panel) and lab.galaxy_panel.note.text == "Native Eingabe und Wiederbesuch", "Native Galaxy reopen lost its note.")
		panel = lab.galaxy_panel
		var destination: String = panel.body_list.get_item_metadata(panel.body_list.selected)
		_click(panel.visit_button)
		for frame in range(8):
			await tree.process_frame
			if not is_instance_valid(lab.galaxy_panel):
				break
		lab.walker.enabled = false
		_expect(lab.body_id == destination and lab.system.real_scale and lab.terrain.active.size() == 24,
			"Native catalog Visit click did not open its real physical planet.")
		var visit: Dictionary = lab.snapshot()
		_expect(lab.save_lab() and visit.schema == 4, "Native catalog surface did not persist its return point.")
		lab._open_body("m1:aster")
		lab.load_lab()
		lab.walker.enabled = false
		var radius: float = lab.system.bodies[lab.body_id].radius
		_expect(lab.body_id == destination and cube.local_position(cube.cartesian(visit.location, radius),
			cube.cartesian(lab.walker.location(), radius)).length() < 0.001, "Native catalog return lost its body or precise location.")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MENU_INPUT_PASSED: underwater optics, Esc/F8, actual GUI clicks, VSync, mouse restoration, physical F4, lab round trip, real Terra, Galaxy notes/modal Escape, catalog Visit and precise saved return.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)


func _probe_underwater_camera() -> void:
	var tree := get_tree()
	var effect: Node = tree.get_first_node_in_group(&"underwater_view")
	_expect(effect != null, "Packaged main scene has no underwater effect.")
	if effect == null:
		return
	var generator := get_node("/root/WorldGenerator")
	var spawn: Vector3 = generator.get_scenic_spawn()
	var dive := Vector3.ZERO
	var found: bool = false
	for z in range(-6, 7):
		for x in range(-6, 7):
			var point: Vector3 = spawn + Vector3(x * 32, 0, z * 32)
			var level: float = generator.get_water_level(point.x, point.z)
			if generator.get_terrain_height(point.x, point.z) < level - 3.0:
				dive = Vector3(point.x, level - 1.0, point.z)
				found = true
				break
		if found:
			break
	_expect(found, "Native input fixture has no water for its camera check.")
	if not found:
		return
	var previous: Camera3D = get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	tree.current_scene.add_child(camera)
	camera.position = dive
	camera.make_current()
	effect.update_view()
	_expect(effect.submerged and camera.environment != null and camera.environment.fog_depth_end < 40.0, "Native eye did not enter the actual world's water.")
	camera.position.y += 2.0
	effect.update_view()
	_expect(not effect.submerged and camera.environment == null, "Native camera kept its water atmosphere on surfacing.")
	previous.make_current()
	camera.queue_free()
	await tree.process_frame


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
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
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
