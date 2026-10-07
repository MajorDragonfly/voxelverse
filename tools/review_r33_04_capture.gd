extends "res://tools/review_r32_04_campaign_capture.gd"
## Keep all nine original full campaign views. Add a real sampled-ground hut
## collision alongside them; housing data and production remain untouched.
func _capture(label: String) -> void:
	await _observe(label)
	if label not in ["home-eye-level", "home-low-wide", "slope-near"]: return
	paused = false
	var rig: RefCounted = tribe.camera_rig
	var frame: Basis = rig.view_frame()
	var building := StaticBody3D.new()
	building.name = "CameraCollisionObservationHut"
	building.collision_layer = 1
	building.collision_mask = 0
	current_scene.add_child(building)
	building.global_position = rig.surface_point(tribe._focus + frame.z * 3.6)
	building.global_basis = Space.frame(tribe, building.global_position, -frame.z)
	tribe._shelters.add_model(building, "hut")
	await physics_frame
	await physics_frame
	for i in range(20): rig.advance(1.0 / 60.0)
	await _observe(label + "-close-hut")
	var sample: Dictionary = Space.sample(tribe,tribe.camera.global_position)
	var row: Dictionary = capture_rows.back()
	row["eye_clearance_m"] = sample.altitude - maxf(sample.height,sample.water_level)
	row["collision_fixture"] = "production hut mesh/collider on real sampled campaign ground; no housing/save mutation"
	var visual_parts: Array[String] = []
	for child: Node in building.get_children():
		if child is MeshInstance3D and child.get_aabb().has_point(child.global_transform.affine_inverse() * tribe.camera.global_position):
			visual_parts.append(str(child.name))
	row["eye_inside_fixture_visual_parts"] = visual_parts
	print("R33_04_CLOSE_HUT ",JSON.stringify(row))
	_write_views()
	paused = false
	building.free()
	await physics_frame
	for i in range(20): rig.advance(1.0 / 60.0)

func _observe(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await super._capture(label)
		capture_rows.back()["physical_camera"] = _physical_camera()
		_write_views()
		return
	var camera: Camera3D = tribe.camera
	var rig: RefCounted = tribe.camera_rig
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var minimum: float = INF
	for x: float in [0.0, 0.5, 1.0]:
		for y: float in [0.0, 0.5, 1.0]:
			var point: Vector3 = camera.project_position(Vector2(size.x*x,size.y*y),camera.near)
			var sample: Dictionary = Space.sample(tribe,point)
			minimum = minf(minimum,sample.altitude-maxf(sample.height,sample.water_level))
	capture_rows.append({"label":label,"seed":15838,"clock_s":state.campaign.data.elapsed_seconds,
		"focus_address":Space.address(tribe,tribe._focus),"eye_address":Space.address(tribe,camera.global_position),
		"yaw_deg":rig.yaw,"requested_tilt_deg":rig.tilt,"zoom":rig.current_zoom,
		"projection":camera.projection,"fov_deg":camera.fov,"near":camera.near,
		"forward_up_abs":absf((-camera.global_basis.z).dot(Space.up(tribe,camera.global_position))),
		"minimum_frame_clearance_m":minimum,"viewport":[size.x,size.y]})
	capture_rows.back()["physical_camera"] = _physical_camera()
	_write_views()

func _write_views() -> void:
	var file := FileAccess.open(capture_dir.path_join("views.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"regular spherical campaign / original nine full views plus three grounded huts",
		"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"rows":capture_rows},"\t"))

func _physical_camera() -> Dictionary:
	# Additional measurements on the same full views; no replacement for the
	# original optical-axis, sampled terrain or nine near-plane checks.
	var camera: Camera3D = tribe.camera
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = camera.near
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY,camera.global_position)
	query.collision_mask = 1
	var eye_hits: Array[Dictionary] = space.intersect_shape(query)
	var points := PackedVector3Array([Vector3.ZERO])
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	for x: float in [0.0,1.0]:
		for y: float in [0.0,1.0]:
			points.append(camera.project_position(Vector2(size.x*x,size.y*y),camera.near) - camera.global_position)
	var lens := ConvexPolygonShape3D.new()
	lens.points = points
	query.shape = lens
	var lens_hits: Array[Dictionary] = space.intersect_shape(query)
	var up: Vector3 = Space.up(tribe,camera.global_position)
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position + up * 8.0,camera.global_position - up * 8.0,1)
	var floor_hit: Dictionary = space.intersect_ray(ray)
	return {"eye_radius_m":sphere.radius,"eye_contacts":eye_hits.size(),"eye_contact_paths":_contact_paths(eye_hits),
		"eye_to_near_plane_contacts":lens_hits.size(),"lens_contact_paths":_contact_paths(lens_hits),
		"floor_found":not floor_hit.is_empty(),"floor_eye_clearance_m":(camera.global_position - floor_hit.position).dot(up) if not floor_hit.is_empty() else null,
		"floor_path":str(floor_hit.collider.get_path()) if not floor_hit.is_empty() else ""}

func _contact_paths(hits: Array[Dictionary]) -> Array[String]:
	var paths: Array[String] = []
	for hit: Dictionary in hits: paths.append(str(hit.collider.get_path()))
	return paths
