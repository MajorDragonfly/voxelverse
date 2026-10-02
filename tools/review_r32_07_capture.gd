extends "res://tools/capture_surface_transitions.gd"
## Fixed real campaign, with explicitly labelled seek/slow-worker diagnostics.
const Preferences = preload("res://core/graphics_preferences.gd")
var waypoints: Array[float] = [0.0, 20.0, 100.0, 200.0, 100.0, 20.0, 0.0]
var state: Node
var start: Dictionary
var route_basis: Basis
var origins: Array = []

func _run() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() == "headless":
		push_error("R32-07 requires a native renderer")
		quit(1)
		return
	root.size = Vector2i(960, 540)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var saves: Node = root.get_node("SaveGameService")
	var flow: Node = root.get_node("SessionFlow")
	state = root.get_node("GameState")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("R32-07 distance comparison", 15838, Cube.MODE)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	RenderingServer.render_loop_enabled = false
	flow.load_game(path)
	var deadline: int = Time.get_ticks_msec() + 180000
	while flow.loading and Time.get_ticks_msec() < deadline: await process_frame
	if flow.loading or current_scene.scene_file_path != Context.SCENE:
		push_error("R32-07 real campaign failed to load")
		quit(1)
		return
	scene = current_scene
	state.set_process(false)
	state.campaign.data.elapsed_seconds = 120.0
	scene.player.set_physics_process(false)
	camera = Camera3D.new()
	camera.far = 30000.0
	camera.near = 0.2
	camera.fov = 75.0
	scene.add_child(camera)
	camera.make_current()
	start = state.get_current_body_record().surface_context.spawn.duplicate(true)
	route_basis = scene.adapter.frame_at(start)
	scene._atmosphere.apply_graphics(Preferences.preset(0), 0)
	if is_instance_valid(scene._atmosphere._weather):
		scene._atmosphere._weather.apply_graphics(Preferences.preset(0))
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.resolution = [960, 540]
	report.engine = Engine.get_version_info().string
	report.scope = "Real spherical campaign, eye height 1.7 m, FOV 75, low preset, campaign clock fixed at 120 s. Address seeks are not physical walking or FPS acceptance. Existing unmeasured setup drains up to 64 near-flora operations/frame. Held scenery explicitly simulates a slow worker, without altering production. PNG readback is outside static frame timings."
	report.geometry = _geometry_metrics()
	report.route_metres = waypoints
	for index in range(waypoints.size()):
		paused = false
		RenderingServer.render_loop_enabled = false
		_place(waypoints[index])
		await _settle()
		_hide_ui(scene)
		scene._atmosphere.update_view(0.0, true)
		paused = true
		RenderingServer.render_loop_enabled = true
		await _sample("route-%02d-%dm" % [index, int(waypoints[index])])
		if index == 0:
			var frame: Basis = scene.adapter.frame_at(scene.player.location())
			camera.look_at(camera.position + frame.x * 200.0, frame.y)
			await _sample("side-horizon")
			_place(0.0)
	# Rebase both active and staged scenery; keep absolute positions invariant.
	paused = false
	RenderingServer.render_loop_enabled = false
	var active: Dictionary = scene.scenery._active
	var absolute: Array = Cube.global_position(active.node.position, scene.terrain.origin)
	var shifted: Array = [absolute[0] + 81.0, absolute[1] - 31.0, absolute[2] + 57.0]
	scene.terrain.rebase(shifted)
	var error: float = Cube.local_position(Cube.global_position(active.node.position, scene.terrain.origin), absolute).length()
	report.rebase_error_m = error
	if error >= 0.002: report.failures.append("Origin shift moved the active proxy set")
	# Deliberately hold a complete canonical set while following the same
	# outward/return camera addresses. This isolates the proven reserve hole.
	scene.scenery.set_process(false)
	report.held_anchor = active.anchor
	report.motion = []
	for index in range(25):
		var metres: float = 63.5 * (float(index) / 12.0 if index <= 12 else float(24 - index) / 12.0)
		_place(metres, true)
		_hide_ui(scene)
		scene._atmosphere.update_view(0.0, true)
		RenderingServer.render_loop_enabled = true
		var started: int = Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		var frame_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		var readback_started: int = Time.get_ticks_usec()
		var status: int = root.get_texture().get_image().save_png(output.path_join("motion-%03d.png" % index))
		if status != OK: report.failures.append("Motion capture failed")
		report.motion.append({"frame": index, "metres": metres, "frame_ms": frame_ms, "readback_png_ms": (Time.get_ticks_usec() - readback_started) / 1000.0, "address": scene.player.location(), "anchor_drift_m": Cube.local_position(Cube.cartesian(scene.player.location(), scene.terrain.surface.body.radius), active.anchor).length(), "scenery": scene.scenery.diagnostics()})
		if index in [0, 12, 24]:
			paused = true
			await _sample("held-%02d" % index)
			paused = false
		RenderingServer.render_loop_enabled = false
	report.origins = origins
	report.passed = report.failures.is_empty()
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("R32_07_CAPTURE ", JSON.stringify({"passed": report.passed, "samples": report.samples.size(), "motion_frames": report.motion.size(), "failures": report.failures}))
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.queue_free()
	scene = null
	camera = null
	paused = false
	RenderingServer.render_loop_enabled = true
	for _frame in range(4): await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.passed else 1)

func _place(metres: float, sideways: bool = false) -> void:
	var tangent: Vector3 = route_basis.x if sideways else -route_basis.z
	var location: Dictionary = scene.adapter.offset(start, tangent * metres, 1.1)
	if sideways:
		# Normal bounded terrain requests during the diagnostic motion clip;
		# no synchronous forced terrain build per captured frame.
		scene.adapter.place(scene.player, location)
		scene.terrain.stream_at(scene.player.up_direction)
	else:
		scene.player.place(location)
	var frame: Basis = scene.adapter.frame_at(location)
	camera.position = scene.player.position + frame.y * 0.6
	camera.look_at(camera.position + (frame.x if sideways else -frame.z) * 200.0, frame.y)
	origins.append(scene.terrain.origin.duplicate())

func _sample(label: String) -> void:
	await _capture(label)
	var sample: Dictionary = report.samples[-1]
	sample.address = scene.player.location()
	sample.camera_position = [camera.position.x, camera.position.y, camera.position.z]
	sample.camera_forward = [-camera.basis.z.x, -camera.basis.z.y, -camera.basis.z.z]
	sample.origin = scene.terrain.origin.duplicate()
	sample.clock = state.campaign.data.elapsed_seconds
	sample.sun = [scene._atmosphere._sun_direction.x, scene._atmosphere._sun_direction.y, scene._atmosphere._sun_direction.z]
	sample.weather = scene._atmosphere.campaign_sample().get("weather", {})
	sample.graphics = scene._atmosphere.graphics_values.duplicate(true)
