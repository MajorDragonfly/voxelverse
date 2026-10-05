extends "res://tests/tribal_playtest_test.gd"
## Regular title/confirmation/campaign route. A comparison reloads the exact
## reference slot; captures freeze the genuine clock, not a separate sun.
const Space = preload("res://world/surface/gameplay_space.gd")
var tribe: Node
var capture_dir: String = ""
var capture_rows: Array[Dictionary] = []

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	if "--reference-slot" in args:
		await flow.load_game(args[args.find("--reference-slot") + 1])
		await _until(func() -> bool:
			var owner: Node = current_scene.get_node_or_null("Nest/Tribe")
			return not flow.loading and owner != null and owner._active and not owner.navigation.pending, 90000)
		if paused: flow.toggle_pause()
	else:
		_expect(Playtest.start(flow), "Could not begin ordinary tribe campaign.")
		await _until(func() -> bool:
			var owner: Node = current_scene.get_node_or_null("Nest/Tribe")
			return owner != null and owner.panel.confirmation_open, 90000)
		tribe = current_scene.get_node_or_null("Nest/Tribe")
		if tribe != null and tribe.panel.confirmation_open:
			tribe.panel.confirm.pressed.emit()
			await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 20000)
	tribe = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.is_active() or tribe.navigation.pending:
		_expect(false, "Regular campaign preparation failed.")
		await _finish()
		return
	saves.autosave_enabled = false
	state.set_process(false)
	state.campaign.data.elapsed_seconds = 120.0
	tribe.set_physics_process(false)
	var before: Dictionary = tribe.village().duplicate(true)
	var rig: RefCounted = tribe.camera_rig
	var map: Node = get_first_node_in_group(&"minimap_hud")
	if map != null: map.set_process(false)
	_expect(saves.save_now(), "Reference slot could not be saved.")
	var reference := {"slot":saves.save_path, "save_sha256":FileAccess.get_file_as_string(saves.save_path).sha256_text(), "body_id":state.get_current_body_record().id}
	var file := FileAccess.open(capture_dir.path_join("reference.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(reference,"\t"))
	for pose: Dictionary in [
		{"label":"home-overview", "tilt":55.0,"zoom":26.0,"yaw":0.0,"offset":Vector2.ZERO},
		{"label":"home-eye-level", "tilt":3.0,"zoom":12.0,"yaw":0.0,"offset":Vector2.ZERO},
		{"label":"home-eye-level-side", "tilt":3.0,"zoom":12.0,"yaw":90.0,"offset":Vector2.ZERO},
		{"label":"home-low-wide", "tilt":3.0,"zoom":72.0,"yaw":0.0,"offset":Vector2.ZERO},
		{"label":"lens-24-wide", "tilt":24.0,"zoom":72.0,"yaw":0.0,"offset":Vector2.ZERO},
		{"label":"lens-25-wide", "tilt":25.0,"zoom":72.0,"yaw":0.0,"offset":Vector2.ZERO},
		{"label":"lens-26-wide", "tilt":26.0,"zoom":72.0,"yaw":0.0,"offset":Vector2.ZERO},
		{"label":"slope-near", "tilt":3.0,"zoom":12.0,"yaw":90.0,"offset":Vector2(64,0)},
		{"label":"slope-wide", "tilt":3.0,"zoom":72.0,"yaw":90.0,"offset":Vector2(64,0)}]:
		paused = false
		rig.focus_home()
		rig.yaw = pose.yaw
		var frame: Basis = Space.frame(tribe, tribe.anchor())
		rig.move_focus(frame.x * pose.offset.x + frame.z * pose.offset.y)
		rig.tilt = pose.tilt
		rig.current_zoom = pose.zoom
		tribe._zoom = pose.zoom
		rig.update_camera()
		if map != null: map._update_snapshot()
		await _capture(pose.label)
	_expect(tribe.village() == before, "Camera captures changed village orders or stock.")
	if failures.is_empty(): print("R32_04_CAMPAIGN_CAPTURE_PASSED")
	await _finish()

func _capture(label: String) -> void:
	if capture_dir.is_empty(): return
	var camera: Camera3D = tribe.camera
	var rig: RefCounted = tribe.camera_rig
	var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
	var clearance: float = INF
	for x: float in [0.0, 0.5, 1.0]:
		for y: float in [0.0, 0.5, 1.0]:
			var point: Vector3 = camera.project_position(Vector2(viewport.x * x, viewport.y * y), camera.near)
			var sample: Dictionary = Space.sample(tribe, point)
			clearance = minf(clearance, sample.altitude - maxf(sample.height, sample.water_level))
	capture_rows.append({"label":label, "seed":15838, "clock_s":state.campaign.data.elapsed_seconds,
		"focus_address":Space.address(tribe, tribe._focus), "eye_address":Space.address(tribe, camera.global_position),
		"yaw_deg":rig.yaw, "requested_tilt_deg":rig.tilt, "zoom":rig.current_zoom,
		"projection":camera.projection, "fov_deg":camera.fov, "near":camera.near,
		"forward_up_abs":absf((-camera.global_basis.z).dot(Space.up(tribe, camera.global_position))),
		"minimum_frame_clearance_m":clearance, "viewport":[viewport.x, viewport.y]})
	for i in range(2): await process_frame
	paused = true
	current_scene._atmosphere.update_view(0.0, true)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(capture_dir.path_join(label + ".png"))
	var file := FileAccess.open(capture_dir.path_join("views.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"regular spherical campaign / title entry / real tribe handoff", "engine":Engine.get_version_info(), "renderer":RenderingServer.get_current_rendering_method(), "rows":capture_rows}, "\t"))
