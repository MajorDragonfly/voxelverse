extends "tribal_playtest_test.gd"
const Space = preload("res://world/surface/gameplay_space.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var tribe: Node
var capture_dir: String = ""

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(Playtest.start(flow), "Cannot start camera sphere test.")
	await _until(func() -> bool:
		var t: Node = current_scene.get_node_or_null("Nest/Tribe")
		return t != null and t.panel.confirmation_open, 90000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Sphere tribal setup did not complete.")
		await _finish()
		return
	saves.autosave_enabled = false
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 20000)
	if not tribe.is_active():
		_expect(false, "Sphere tribe did not activate.")
		await _finish()
		return
	tribe.set_physics_process(false)
	root.gui_release_focus()
	var terrain: Node3D = current_scene.terrain
	var rig: RefCounted = tribe.camera_rig
	var tracker: Node = get_first_node_in_group("exploration_tracker")
	tracker.update_exploration()
	var atlas: Dictionary = state.get_current_body_record().exploration_atlas.duplicate(true)
	var explorers: Array = current_scene.map_snapshot().explorers.duplicate(true)
	var data: Dictionary = tribe.village().duplicate(true)
	var radius: int = tribe.navigation._radius
	var ground: Array = Cube.global_position(tribe.anchor(), terrain.origin)
	await _capture("camera-sphere-home")
	_press(KEY_D, true)
	await _camera_until(func() -> bool: return tribe._focus.distance_to(tribe.anchor()) > 108.0, 20.0)
	_press(KEY_D, false)
	_expect(tribe._focus.distance_to(tribe.anchor()) >= 100.0, "WASD still stops near the village instead of panning at least 100 m.")
	var address: Dictionary = Space.address(tribe, tribe._focus)
	await _until(func() -> bool:
		var tile: Dictionary = terrain.layout.find_at(address.face, address.u, address.v, terrain.leaves)
		return not tile.is_empty() and float(tile.width) * terrain.surface.body.radius <= 32.0 and terrain._job == null and terrain._pending.is_empty(), 25000)
	var focus_tile: Dictionary = terrain.layout.find_at(address.face, address.u, address.v, terrain.leaves)
	_expect(float(focus_tile.width) * terrain.surface.body.radius <= 32.0, "Distant camera did not receive detailed visual terrain.")
	_expect(terrain.ground_ready(ground), "Camera streaming stole collision from the village.")
	_expect(terrain.leaves.size() <= 768 and terrain.active.size() <= 24 and terrain.peak_resident_meshes <= 1536, "Camera streaming exceeded existing budgets.")
	_check_surface()
	tracker.update_exploration()
	_expect(current_scene.map_snapshot().explorers == explorers and state.get_current_body_record().exploration_atlas == atlas, "Camera movement revealed the map or moved an explorer.")
	_expect(tribe.village() == data and tribe.navigation._radius == radius, "Camera changed resident work or navigation bounds.")
	await _capture("camera-sphere-far")
	var before: Array = Cube.global_position(tribe._focus, terrain.origin)
	var eye: Array = Cube.global_position(tribe.camera.global_position, terrain.origin)
	terrain.rebase([terrain.origin[0] + 60.0, terrain.origin[1] - 30.0, terrain.origin[2] + 20.0])
	await process_frame
	_expect(Cube.local_position(Cube.global_position(tribe._focus, terrain.origin), before).length() < 0.01, "Origin rebase moved camera focus on the planet.")
	_expect(Cube.local_position(Cube.global_position(tribe.camera.global_position, terrain.origin), eye).length() < 0.02, "Origin rebase moved the camera twice.")
	_press(KEY_HOME, true)
	_press(KEY_HOME, false)
	_expect(tribe._focus.distance_to(tribe.anchor()) < 0.01, "Return to village failed after distant rebase.")
	_press(KEY_RIGHT, true)
	_press(KEY_PAGEDOWN, true)
	await _camera_until(func() -> bool: return rig.tilt <= 30.0, 5.0)
	_press(KEY_RIGHT, false)
	_press(KEY_PAGEDOWN, false)
	tribe.zoom(1000.0)
	await _camera_until(func() -> bool: return tribe.camera.size == 72.0, 5.0)
	_check_surface()
	await _capture("camera-sphere-wide")
	tribe.zoom(-1000.0)
	await _camera_until(func() -> bool: return tribe.camera.size == 12.0, 5.0)
	_check_surface()
	_expect(tribe.camera.size == 12.0 and rig.tilt == 30.0, "Zoom/tilt failed to clamp and settle.")
	# Live load replaces the transient rig and observer, retaining local controls.
	_expect(saves.save_now(), "Cannot save camera test world: " + saves.last_error)
	tribe.set_physics_process(true)
	_expect(saves.load_now(), "Cannot reload camera test world.")
	await _until(func() -> bool: return tribe.is_active() and tribe.camera_rig != rig and not tribe.navigation.pending, 20000)
	tribe.set_physics_process(false)
	_expect(tribe.camera_rig != rig and not rig.orbiting and rig.held.is_empty(), "Load retained old camera input/owner.")
	_expect(tribe.camera_rig != null and tribe._focus.distance_to(tribe.anchor()) < 0.01 and tribe.camera_rig.tilt == 55.0, "Load did not restore the village view with saved preferences.")
	print("CAMERA_METRICS ", JSON.stringify({"pan_m": Cube.local_position(before, ground).length(), "tiles": terrain.leaves.size(), "colliders": terrain.active.size(), "peak_meshes": terrain.peak_resident_meshes}))
	if failures.is_empty(): print("TRIBAL_CAMERA_WORLD_PASSED")
	await _finish()

func _camera_until(predicate: Callable, motion_seconds: float) -> void:
	# Camera motion bounds each frame to 0.1 s. Count that observed motion time
	# instead of mistaking a slow software renderer for a camera range limit.
	# The enclosing native/headless runner retains its wall-clock deadline.
	var elapsed: float = 0.0
	while not predicate.call() and elapsed < motion_seconds:
		await process_frame
		elapsed += minf(root.get_process_delta_time(), 0.1)

func _check_surface() -> void:
	var sample: Dictionary = Space.sample(tribe, tribe._focus)
	_expect(absf(float(sample.altitude) - maxf(float(sample.height), float(sample.water_level)) - 0.08) < 0.2, "Focus floats away from ground/water.")
	var eye: Dictionary = Space.sample(tribe, tribe.camera.global_position)
	_expect(float(eye.altitude) >= maxf(float(eye.height), float(eye.water_level)) + 1.9, "Tilt/zoom put the camera underground or underwater.")

func _press(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)

func _capture(label: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(capture_dir.path_join(label + ".png"))
	image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	print("TRIBAL_CAMERA_IMAGE:" + label + ":" + Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.8)))
