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
	var map: CanvasLayer = get_first_node_in_group(&"minimap_hud")
	if map != null: map._update_snapshot()
	_expect(map != null and map._camera_controls.visible, "Tribe minimap camera controls are missing.")
	root.size = Vector2i(1280, 720)
	for i in range(4): await process_frame
	map._layout()
	var map_rect := Rect2(map._panel.get_global_transform_with_canvas().origin, map._panel.size * map.transform.get_scale())
	_expect(root.get_visible_rect().encloses(map_rect), "Minimap angle controls escaped the scaled 720p view: " + str(map_rect))
	root.size = Vector2i(1920, 1080)
	for i in range(4): await process_frame
	map._layout()
	var map_yaw: float = rig.yaw
	map._camera_controls.get_node("TRIBE_MAP_TURN_RIGHT").pressed.emit()
	_expect(rig.yaw != map_yaw, "Minimap turn button did not rotate the camera.")
	map._camera_controls.get_node("TRIBE_MAP_TILT_LOW").pressed.emit()
	_expect(rig.tilt < 55.0, "Minimap tilt button did not lower the camera.")
	map._camera_controls.get_node("TRIBE_MAP_CENTER").pressed.emit()
	_expect(tribe._focus.distance_to(tribe.anchor()) < 0.01, "Minimap center button did not return to village.")
	var selected_before: Array = tribe.selected.duplicate()
	var map_center: Vector2 = map._map.screen_point(map._map.position_m)
	var screen_click: Vector2 = map._map.get_global_transform_with_canvas() * (map_center + Vector2(25, 0))
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = screen_click
	root.push_input(mouse_motion, true)
	var map_click := InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_LEFT
	map_click.pressed = true
	map_click.position = screen_click
	root.push_input(map_click, true)
	map_click.pressed = false
	root.push_input(map_click, true)
	_expect(map._map.direction.dot(Vector2.RIGHT) > 0.98, "Minimap click did not point the cone east.")
	_expect(tribe.selected == selected_before and tribe.village() == data and tribe.navigation._radius == radius, "Minimap input changed a world order or work limit.")
	rig.reset_view()
	_press(KEY_D, true)
	var travel_seconds: float = await _camera_until(func() -> bool: return tribe._focus.distance_to(tribe.anchor()) >= 64.0, 5.0)
	_expect(travel_seconds < 3.2, "Default movement took too long to cover 64 m.")
	await _camera_until(func() -> bool: return tribe._focus.distance_to(tribe.anchor()) > 108.0, 20.0)
	_press(KEY_D, false)
	print("TRIBAL_CAMERA_TRAVEL ", JSON.stringify({"metres": 64, "simulated_seconds": travel_seconds, "speed_setting": 1.0}))
	_expect(tribe._focus.distance_to(tribe.anchor()) >= 100.0, "WASD still stops near the village instead of panning at least 100 m.")
	var address: Dictionary = Space.address(tribe, tribe._focus)
	# Native software rendering publishes only two mesh operations per drawn
	# frame. Allow that bounded queue to drain without changing any LOD limit.
	await _until(func() -> bool:
		var tile: Dictionary = terrain.layout.find_at(address.face, address.u, address.v, terrain.leaves)
		return not tile.is_empty() and float(tile.width) * terrain.surface.body.radius <= 32.0 and terrain._job == null and terrain._pending.is_empty(), 90000 if not capture_dir.is_empty() else 25000)
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
	await _camera_until(func() -> bool: return rig.tilt <= rig.MIN_TILT, 5.0)
	_press(KEY_RIGHT, false)
	_press(KEY_PAGEDOWN, false)
	tribe.zoom(1000.0)
	await _camera_until(func() -> bool: return tribe.camera.size == 72.0, 5.0)
	_check_surface()
	await _capture("camera-sphere-wide")
	tribe.zoom(-1000.0)
	await _camera_until(func() -> bool: return tribe.camera.size == 12.0, 5.0)
	_check_surface()
	_expect(tribe.camera.size == 12.0 and rig.tilt == rig.MIN_TILT, "Zoom/tilt failed to clamp and settle.")
	var forward: Vector3 = -tribe.camera.global_basis.z
	_expect(absf(forward.dot(Space.up(tribe, tribe.camera.global_position))) < 0.15, "Near-ground clearance pitched the low camera too steeply.")
	var aim: Vector3 = tribe._focus + rig.view_frame().y * 1.5
	for i in range(1, 6):
		var point: Vector3 = aim.lerp(tribe.camera.global_position, float(i) / 6.0)
		var sight: Dictionary = Space.sample(tribe, point)
		_expect(float(sight.altitude) >= maxf(float(sight.height), float(sight.water_level)) + 1.0, "Eye-level view crosses the terrain or water surface.")
	_check_frame()
	print("R32_04_EYE_LEVEL ", JSON.stringify({"requested_tilt_deg": rig.tilt, "forward_up_abs": absf(forward.dot(Space.up(tribe, tribe.camera.global_position))), "eye": str(tribe.camera.global_position), "focus": str(tribe._focus)}))
	await _capture("camera-sphere-eye-level")
	# Keep the existing eye-level assertion strict. Separately verify the lens
	# transition where a safe orthographic eye can still have buried corners.
	for lens_tilt: float in [24.0, 25.0, 26.0]:
		for lens_zoom: float in [12.0, 26.0, 72.0]:
			rig.tilt = lens_tilt
			rig.current_zoom = lens_zoom
			tribe._zoom = lens_zoom
			rig.update_camera()
			_check_surface()
			_check_frame()
			if lens_tilt == 25.0 and lens_zoom == 72.0: await _capture("camera-sphere-lens-boundary")
	# Clearance at a shore/slope must not turn the lowest setting into a steep
	# downward view. Test actual spherical heights in several directions; keep
	# the original strict criterion and saved village/focus ownership.
	var home_frame: Basis = Space.frame(tribe, tribe.anchor())
	var low_cases: int = 0
	var worst_low_dot: float = 0.0
	for offset: Vector2 in [Vector2.ZERO, Vector2(64,0), Vector2(-64,0), Vector2(0,64), Vector2(0,-64)]:
		for low_yaw: float in [0.0,90.0,180.0,-90.0]:
			for low_zoom: float in [12.0,72.0]:
				rig.focus_home()
				rig.move_focus(home_frame.x * offset.x + home_frame.z * offset.y)
				rig.yaw = low_yaw
				rig.tilt = rig.MIN_TILT
				rig.current_zoom = low_zoom
				tribe._zoom = low_zoom
				rig.update_camera()
				_check_surface()
				_check_frame()
				var low_dot: float = absf((-tribe.camera.global_basis.z).dot(Space.up(tribe,tribe.camera.global_position)))
				worst_low_dot = maxf(worst_low_dot,low_dot)
				_expect(low_dot < 0.15, "Surface clearance violated eye level at " + str(offset) + "/" + str(low_yaw) + "/" + str(low_zoom))
				low_cases += 1
	print("R32_04_LOW_SURFACE_CASES ",JSON.stringify({"cases":low_cases,"maximum_forward_up_abs":worst_low_dot}))
	await _check_close_hut(rig)
	rig.focus_home()
	# Live load replaces the transient rig and observer, retaining local controls.
	_expect(saves.save_now(), "Cannot save camera test world: " + saves.last_error)
	tribe.set_physics_process(true)
	_expect(saves.load_now(), "Cannot reload camera test world.")
	await _until(func() -> bool: return tribe.is_active() and tribe.camera_rig != null and tribe.camera_rig != rig and not tribe.navigation.pending, 90000)
	tribe.set_physics_process(false)
	_expect(tribe.is_active() and tribe.camera_rig != null and not tribe.navigation.pending, "Reload did not reactivate the village and its camera within 90 seconds.")
	_expect(tribe.camera_rig != rig and not rig.orbiting and rig.held.is_empty(), "Load retained old camera input/owner.")
	var restored_distance: float = tribe._focus.distance_to(tribe.anchor())
	var restored_tilt: float = tribe.camera_rig.tilt if tribe.camera_rig != null else -1.0
	print("CAMERA_RELOAD_METRICS ", JSON.stringify({"focus_distance_m": restored_distance, "tilt_deg": restored_tilt, "saved_default_deg": float(root.get_node("DisplaySettings").input_preferences.tribe_camera.tilt)}))
	_expect(tribe.camera_rig != null and restored_distance < 0.01 and is_equal_approx(restored_tilt, float(root.get_node("DisplaySettings").input_preferences.tribe_camera.tilt)), "Load did not restore the village view with saved preferences.")
	print("CAMERA_METRICS ", JSON.stringify({"pan_m": Cube.local_position(before, ground).length(), "tiles": terrain.leaves.size(), "colliders": terrain.active.size(), "peak_meshes": terrain.peak_resident_meshes}))
	if failures.is_empty(): print("TRIBAL_CAMERA_WORLD_PASSED")
	await _finish()

func _camera_until(predicate: Callable, motion_seconds: float) -> float:
	# Camera motion bounds each frame to 0.1 s. Count that observed motion time
	# instead of mistaking a slow software renderer for a camera range limit.
	# The enclosing native/headless runner retains its wall-clock deadline.
	var elapsed: float = 0.0
	while not predicate.call() and elapsed < motion_seconds:
		await process_frame
		elapsed += minf(root.get_process_delta_time(), 0.1)
	return elapsed

func _check_surface() -> void:
	var sample: Dictionary = Space.sample(tribe, tribe._focus)
	_expect(absf(float(sample.altitude) - maxf(float(sample.height), float(sample.water_level)) - 0.08) < 0.2, "Focus floats away from ground/water.")
	var eye: Dictionary = Space.sample(tribe, tribe.camera.global_position)
	_expect(float(eye.altitude) >= maxf(float(eye.height), float(eye.water_level)) + 1.9, "Tilt/zoom put the camera underground or underwater.")

func _check_frame() -> void:
	var viewport: Vector2 = tribe.camera.get_viewport().get_visible_rect().size
	for x: float in [0.0, 0.5, 1.0]:
		for y: float in [0.0, 0.5, 1.0]:
			var point: Vector3 = tribe.camera.project_position(Vector2(viewport.x * x, viewport.y * y), tribe.camera.near)
			var sample: Dictionary = Space.sample(tribe, point)
			_expect(float(sample.altitude) >= maxf(float(sample.height), float(sample.water_level)) + 0.8, "Actual camera near-plane edge clips beneath terrain/water: " + str(Vector2(x, y)))

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

func _check_close_hut(rig: RefCounted) -> void:
	# Additional real-surface case; retain the original route and all 40 low
	# poses above. Use the production hut geometry without changing housing.
	rig.focus_home()
	rig.yaw = 0.0
	rig.tilt = rig.MIN_TILT
	rig.current_zoom = rig.MIN_ZOOM
	tribe._zoom = rig.MIN_ZOOM
	rig.update_camera()
	var old_eye: Vector3 = tribe.camera.global_position
	var frame: Basis = rig.view_frame()
	var building := StaticBody3D.new()
	building.collision_layer = 1
	building.collision_mask = 0
	current_scene.add_child(building)
	building.global_position = rig.surface_point(tribe._focus + frame.z * 3.6)
	building.global_basis = Space.frame(tribe,building.global_position,-frame.z)
	tribe._shelters.add_model(building,"hut")
	await physics_frame
	await physics_frame
	for i in range(20): rig.advance(1.0 / 60.0)
	var sample: Dictionary = Space.sample(tribe,tribe.camera.global_position)
	var clearance: float = sample.altitude - maxf(sample.height,sample.water_level)
	var low_dot: float = absf((-tribe.camera.global_basis.z).dot(Space.up(tribe,tribe.camera.global_position)))
	_expect(tribe.camera.global_position.distance_to(old_eye) > 1.0, "Close hut did not obstruct the original camera orbit.")
	_expect(clearance >= 1.9, "A close hut lowered the stopped eye below the existing 2 m surface clearance.")
	_expect(low_dot < 0.15, "Close hut pitched the low camera beyond the original eye-level boundary.")
	var point := PhysicsPointQueryParameters3D.new()
	point.position = tribe.camera.global_position
	point.collision_mask = 1
	var overlaps: Array[Dictionary] = tribe.camera.get_world_3d().direct_space_state.intersect_point(point)
	var overlap_rows: Array[Dictionary] = []
	for hit: Dictionary in overlaps:
		var collider: CollisionObject3D = hit.collider
		var shape_owner: int = collider.shape_find_owner(hit.shape)
		var shape: Shape3D
		for index in range(collider.shape_owner_get_shape_count(shape_owner)):
			if collider.shape_owner_get_shape_index(shape_owner,index) == hit.shape:
				shape = collider.shape_owner_get_shape(shape_owner,index)
		var transform: Transform3D = collider.global_transform * collider.shape_owner_get_transform(shape_owner)
		var geometry: Dictionary = {}
		if shape is ConcavePolygonShape3D:
			var faces: PackedVector3Array = shape.get_faces()
			var minimum: float = INF
			for index in range(0,faces.size(),3):
				minimum = minf(minimum,_triangle_distance(tribe.camera.global_position,transform * faces[index],transform * faces[index+1],transform * faces[index+2]))
			geometry = {"triangles":faces.size()/3,"minimum_triangle_distance_m":minimum}
			# Jolt's point containment requires a closed manifold. These open
			# terrain patches have no interior; check their actual triangles.
			_expect(minimum >= tribe.camera.near, "Stopped eye touches an actual terrain triangle.")
		else:
			_expect(false, "Stopped eye is inside a solid physical collider: " + str(collider.get_path()))
		overlap_rows.append({"name":str(collider.name),"path":str(collider.get_path()),"class":collider.get_class(),"shape":shape.get_class(),"shape_transform":str(transform),"eye_in_shape":str(transform.affine_inverse() * tribe.camera.global_position),"eye":str(tribe.camera.global_position),"hut":str(building.global_transform),"collision_layer":collider.collision_layer,"geometry":geometry})
	print("R33_04_STOPPED_EYE_OVERLAPS ",JSON.stringify(overlap_rows))
	var sphere := SphereShape3D.new()
	sphere.radius = tribe.camera.near
	var finite := PhysicsShapeQueryParameters3D.new()
	finite.shape = sphere
	finite.transform = Transform3D(Basis.IDENTITY,tribe.camera.global_position)
	finite.collision_mask = 1
	var finite_hits: Array[Dictionary] = tribe.camera.get_world_3d().direct_space_state.intersect_shape(finite)
	var up: Vector3 = Space.up(tribe,tribe.camera.global_position)
	var floor_ray := PhysicsRayQueryParameters3D.create(tribe.camera.global_position + up * 8.0,tribe.camera.global_position - up * 8.0,1)
	var floor_hit: Dictionary = tribe.camera.get_world_3d().direct_space_state.intersect_ray(floor_ray)
	print("R33_04_PHYSICAL_SURFACE ",JSON.stringify({"sphere_radius_m":sphere.radius,"sphere_hits":finite_hits.size(),"floor_found":not floor_hit.is_empty(),"floor_eye_clearance_m":(tribe.camera.global_position - floor_hit.position).dot(up) if not floor_hit.is_empty() else null,"floor_path":str(floor_hit.collider.get_path()) if not floor_hit.is_empty() else ""}))
	_expect(finite_hits.is_empty(), "Stopped camera volume intersects a physical building or ground surface.")
	_expect(not floor_hit.is_empty() and (tribe.camera.global_position - floor_hit.position).dot(up) >= sphere.radius, "Stopped eye is below or touching its actual physical floor.")
	_check_frame()
	print("R33_04_CLOSE_HUT_WORLD ",JSON.stringify({"eye_clearance_m":clearance,"forward_up_abs":low_dot,"move_m":tribe.camera.global_position.distance_to(old_eye)}))
	await _capture("camera-sphere-close-hut")
	building.free()
	await physics_frame
	for i in range(20): rig.advance(1.0 / 60.0)
	_expect(tribe.camera.global_position.distance_to(old_eye) < 0.1, "Removing a close hut did not restore the original orbit.")

func _triangle_distance(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	# Read the actual queried mesh, independently of point/shape physics APIs.
	var normal: Vector3 = (b-a).cross(c-a)
	if normal.length_squared() > 0.00000001:
		var projected: Vector3 = point - normal * ((point-a).dot(normal) / normal.length_squared())
		if (b-a).cross(projected-a).dot(normal) >= 0.0 and (c-b).cross(projected-b).dot(normal) >= 0.0 and (a-c).cross(projected-c).dot(normal) >= 0.0:
			return point.distance_to(projected)
	return minf(point.distance_to(Geometry3D.get_closest_point_to_segment(point,a,b)),minf(point.distance_to(Geometry3D.get_closest_point_to_segment(point,b,c)),point.distance_to(Geometry3D.get_closest_point_to_segment(point,c,a))))
