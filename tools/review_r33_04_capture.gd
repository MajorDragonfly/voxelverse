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
	print("R33_04_CLOSE_HUT ",JSON.stringify(row))
	var file := FileAccess.open(capture_dir.path_join("views.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"rows":capture_rows},"\t"))
	paused = false
	building.free()
	await physics_frame
	for i in range(20): rig.advance(1.0 / 60.0)

func _observe(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await super._capture(label)
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
