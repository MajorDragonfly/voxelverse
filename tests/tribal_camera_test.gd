extends "tribal_age_test.gd"
const Space = preload("res://world/surface/gameplay_space.gd")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Cannot prepare camera fixture.")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	if not tribe.is_active():
		_expect(false, "Tribe did not activate.")
		await _cleanup()
		await _finish()
		return
	tribe.set_physics_process(false)
	root.gui_release_focus()
	var rig: RefCounted = tribe.camera_rig
	var data: Dictionary = tribe.village()
	data.tools = 1
	for resource: String in ["wood", "stone"]:
		data.deposits[resource].remaining = 0
		data.stock[resource] = 16
	_expect(saves.save_now(), "Camera fixture does not conserve resources.")
	tribe.select_all()
	var before: Dictionary = data.duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(SAVE)
	await _capture("camera-default")
	_press(KEY_RIGHT, true)
	# Observe the turn before it wraps; software rendering does not provide a
	# fixed frame duration and forty rendered frames can exceed a full turn.
	await _until(func() -> bool: return rig.yaw > 15.0, 240)
	_press(KEY_RIGHT, false)
	_expect(rig.yaw > 15.0, "Real rotation key never reached the camera.")
	var start: Vector3 = tribe._focus
	var expected: Vector3 = -rig.view_frame().z
	_press(KEY_W, true)
	await _frames(20)
	_press(KEY_W, false)
	var movement: Vector3 = tribe._focus - start
	_expect(movement.length() > 1.0 and movement.normalized().dot(expected) > 0.99, "WASD does not follow the camera heading.")
	_key(KEY_HOME)
	await _frames(2)
	_expect(tribe._focus.distance_to(tribe.anchor()) < 0.01, "Home did not return to the village.")
	var yaw_before: float = rig.yaw
	_mouse(MOUSE_BUTTON_MIDDLE, true, Vector2(500, 220))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(570, 270)
	motion.relative = Vector2(70, 50)
	root.push_input(motion, true)
	var hud: Vector2 = tribe.panel._collapse.get_global_transform_with_canvas() * (tribe.panel._collapse.size * 0.5)
	_mouse(MOUSE_BUTTON_MIDDLE, false, hud)
	_expect(not rig.orbiting and rig.yaw != yaw_before and rig.tilt > 55.0, "Orbit or release over HUD failed.")
	var old_zoom: float = tribe.camera.size
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, Vector2(500, 220))
	_expect(tribe._zoom == old_zoom + 2.0 and tribe.camera.size == old_zoom, "Wheel bypassed the smooth zoom target.")
	await _until(func() -> bool: return tribe.camera.size > old_zoom, 120)
	_expect(tribe.camera.size > old_zoom and tribe.camera.size < tribe._zoom, "Zoom is not interpolated.")
	var target: float = tribe._zoom
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, hud)
	_expect(tribe._zoom == target, "Scrolling a HUD control zoomed the world.")
	_press(KEY_W, true)
	paused = true
	await _frames(3)
	paused = false
	var paused_at: Vector3 = tribe._focus
	await _frames(4)
	_expect(rig.held.is_empty() and tribe._focus == paused_at, "A paused held key stuck after resuming.")
	_press(KEY_W, false)
	_press(KEY_W, true)
	tribe.panel.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_expect(rig.held.is_empty(), "Losing window focus kept camera input.")
	_press(KEY_W, false)
	_key(KEY_END)
	await _frames(2)
	var selected_center := Vector3.ZERO
	for id: String in tribe.selected: selected_center += tribe.actors[id].global_position
	selected_center /= tribe.selected.size()
	_expect(tribe._focus.distance_to(selected_center) < 0.3, "End did not focus the selected residents.")
	# Mouse rays still reach the same build site after rotating and tilting.
	_key(KEY_HOME)
	tribe.issue_order("hut")
	var site: Vector3 = Space.resolve(tribe, data.sites[0])
	motion = InputEventMouseMotion.new()
	motion.position = tribe.camera.unproject_position(site)
	root.push_input(motion, true)
	await _frames(12)
	_expect(tribe.building_preview.visible and tribe.building_preview.result.get("ok", false), "Rotated camera broke the building preview ray.")
	await _capture("camera-rotated-preview")
	_key(KEY_ESCAPE)
	_expect(data == before and FileAccess.get_file_as_string(SAVE) == bytes, "Camera input changed orders, inventory or the save.")
	tribe.panel._camera_action(3)
	await _frames(3)
	var settings: Node = root.get_node("DisplaySettings")
	_expect(paused and settings._control_settings.is_visible_in_tree(), "View menu did not open the existing controls tab.")
	await _capture("camera-settings")
	settings.close_menu()
	rig.reset_view()
	await _cleanup()
	if failures.is_empty(): print("TRIBAL_CAMERA_PASSED")
	await _finish()

func _press(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)

func _mouse(button: MouseButton, down: bool, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.pressed = down
	root.push_input(event, true)
