extends "res://tests/tribal_camera_world_test.gd"
## Focused real-sphere slope regression in its own process and 240 s budget.
## The original World source and its complete 40-pose route remain unchanged.

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
	_expect(Playtest.start(flow), "Cannot start focused camera floor test.")
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
	var village_before: Dictionary = tribe.village().duplicate(true)
	var navigation_radius: int = tribe.navigation._radius
	await _check_slope_close_hut(rig)
	_expect(tribe.village() == village_before and tribe.navigation._radius == navigation_radius, "Floor fixture changed village state or navigation bounds.")
	# Preserve the original origin-rebase and live-save/load oracles and limits
	# in this focused process, without executing the World pan/lens/40-pose route.
	var before: Array = Cube.global_position(tribe._focus, terrain.origin)
	var eye: Array = Cube.global_position(tribe.camera.global_position, terrain.origin)
	terrain.rebase([terrain.origin[0] + 60.0, terrain.origin[1] - 30.0, terrain.origin[2] + 20.0])
	await process_frame
	_expect(Cube.local_position(Cube.global_position(tribe._focus, terrain.origin), before).length() < 0.01, "Origin rebase moved camera focus on the planet.")
	_expect(Cube.local_position(Cube.global_position(tribe.camera.global_position, terrain.origin), eye).length() < 0.02, "Origin rebase moved the camera twice.")
	rig.focus_home()
	_expect(tribe._focus.distance_to(tribe.anchor()) < 0.01, "Floor test did not restore the village focus.")
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
	print("CAMERA_FLOOR_RELOAD_METRICS ", JSON.stringify({"focus_distance_m": restored_distance, "tilt_deg": restored_tilt, "saved_default_deg": float(root.get_node("DisplaySettings").input_preferences.tribe_camera.tilt)}))
	_expect(tribe.camera_rig != null and restored_distance < 0.01 and is_equal_approx(restored_tilt, float(root.get_node("DisplaySettings").input_preferences.tribe_camera.tilt)), "Load did not restore the village view with saved preferences.")
	if failures.is_empty(): print("TRIBAL_CAMERA_FLOOR_PASSED")
	await _finish()

func _check_slope_close_hut(rig: RefCounted) -> void:
	# The original World retains its complete route and all 40 low poses.
	# This focused case uses production hut geometry without changing housing.
	rig.focus_home()
	var home_frame: Basis = Space.frame(tribe, tribe.anchor())
	rig.move_focus(home_frame.x * 64.0)
	rig.yaw = 90.0
	rig.tilt = rig.MIN_TILT
	rig.current_zoom = rig.MIN_ZOOM
	tribe._zoom = rig.MIN_ZOOM
	rig.update_camera()
	rig.advance(1.0 / 60.0)
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
	_record_frame_samples()
	await _capture("camera-sphere-slope-close-hut")
	building.free()
	await physics_frame
	for i in range(20): rig.advance(1.0 / 60.0)
	_expect(tribe.camera.global_position.distance_to(old_eye) < 0.1, "Removing a close hut did not restore the original orbit.")
	print("TRIBAL_CAMERA_FLOOR_RESTORE ", JSON.stringify({"distance_m":tribe.camera.global_position.distance_to(old_eye)}))

func _record_frame_samples() -> void:
	var viewport: Vector2 = tribe.camera.get_viewport().get_visible_rect().size
	var clearances: Array[float] = []
	for x: float in [0.0, 0.5, 1.0]:
		for y: float in [0.0, 0.5, 1.0]:
			var point: Vector3 = tribe.camera.project_position(Vector2(viewport.x * x, viewport.y * y), tribe.camera.near)
			var sample: Dictionary = Space.sample(tribe, point)
			clearances.append(float(sample.altitude) - maxf(float(sample.height), float(sample.water_level)))
	print("TRIBAL_CAMERA_FLOOR_FRAME ", JSON.stringify({"samples":clearances,"viewport":[viewport.x,viewport.y],"focus_offset_m":[64.0,0.0],"yaw_deg":90.0}))
