extends SceneTree
## Reusable on both sides of PT17-03: fixed campaign, cameras and physical data.
const Cube = preload("res://world/space/cube_sphere.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
var output: String
var report: Dictionary = {"seed": 15838, "samples": [], "failures": []}
var scene: Node3D
var camera: Camera3D

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() == "headless":
		push_error("Surface comparison requires a real renderer.")
		quit(1)
		return
	root.size = Vector2i(960, 540)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var saves: Node = root.get_node("SaveGameService")
	var flow: Node = root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("PT17-03 fixed comparison", 15838, Cube.MODE)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	RenderingServer.render_loop_enabled = false
	flow.load_game(path)
	var deadline: int = Time.get_ticks_msec() + 180000
	while flow.loading and Time.get_ticks_msec() < deadline: await process_frame
	if flow.loading or current_scene.scene_file_path != Context.SCENE:
		push_error("Surface comparison failed to load the real campaign.")
		quit(1)
		return
	scene = current_scene
	scene.player.set_physics_process(false)
	camera = Camera3D.new()
	camera.far = 30000.0
	camera.near = 0.2
	scene.add_child(camera)
	camera.make_current()
	var start: Dictionary = root.get_node("GameState").get_current_body_record().surface_context.spawn.duplicate(true)
	var frame: Basis = scene.adapter.frame_at(start)
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.resolution = [960, 540]
	report.scope = "Fixed settled views, 12 frames/view on software GPU; no walking FPS or target-PC acceptance. Fast setup drains up to 64 existing flora publication steps per unmeasured frame; runtime budgets tested separately. UI/actors hidden; wind and cloud clock frozen for comparison."
	report.geometry = _geometry_metrics()
	# Same outward and return waypoints, including origin changes and recentering.
	var route: Array[float] = [0.0, 40.0, 100.0, 200.0, 100.0, 0.0]
	for index in range(route.size()):
		paused = false
		RenderingServer.render_loop_enabled = false
		var location: Dictionary = scene.adapter.offset(start, -frame.z * route[index], 1.1)
		scene.player.place(location)
		await _settle()
		_hide_ui(scene)
		_freeze_visuals(scene)
		paused = true
		RenderingServer.render_loop_enabled = true
		var local_frame: Basis = scene.adapter.frame_at(location)
		camera.position = scene.player.position + local_frame.y * 1.7
		camera.look_at(camera.position - local_frame.z * 200.0, local_frame.y)
		await _capture("route-%d-%dm" % [index, int(route[index])])
		if index == 0:
			camera.look_at(camera.position + local_frame.x * 200.0, local_frame.y)
			await _capture("side-200m")
			camera.look_at(camera.position - local_frame.z * 200.0, local_frame.y)
			# Low sun is a controlled presentation fixture, not a persisted day clock.
			var atmosphere: Node = scene._atmosphere
			var original: Vector3 = atmosphere._sun_direction
			atmosphere._sun_direction = (local_frame.y * 0.18 + local_frame.x * 0.6 + local_frame.z * 0.78).normalized()
			atmosphere.sun.basis = Basis.looking_at(-atmosphere._sun_direction, local_frame.y)
			atmosphere.sky_material.set_shader_parameter("sun_direction", atmosphere._sun_direction)
			atmosphere.update_view(0.0, true)
			await _capture("low-sun-200m")
			atmosphere._sun_direction = original
			atmosphere.sun.basis = Basis.looking_at(-original, local_frame.y)
			atmosphere.sky_material.set_shader_parameter("sun_direction", original)
			atmosphere.update_view(0.0, true)
	report.passed = report.failures.is_empty()
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("SURFACE_TRANSITIONS_CAPTURE ", JSON.stringify(report))
	paused = false
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.passed else 1)

func _settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var flora: Node = scene.flora
		# Software Vulkan can spend a second servicing a viewport frame. The
		# real one-shape-per-frame publisher then cannot warm 25 cells in 60 s,
		# even on the unchanged baseline. Drain the existing bounded publisher
		# only during unmeasured setup; no copied placements or runtime changes.
		for step in range(64):
			flora._tick(0.0)
			if flora.patches.size() == flora.wanted.size() and flora._publication.is_empty(): break
		if flora.patches.size() == flora.wanted.size() and flora._task < 0 and flora._publication.is_empty() and scene.scenery._task < 0 and scene.scenery._staging.is_empty():
			if flora.has_method("_advance_scenery_transitions"): flora._advance_scenery_transitions(1.0)
			return
	report.failures.append("Streaming did not settle for a comparison waypoint")

func _hide_ui(node: Node) -> void:
	if node is CanvasLayer: node.visible = false
	if node is CharacterBody3D or node.name == "Nest": node.hide()
	for child in node.get_children(): _hide_ui(child)

func _freeze_visuals(node: Node) -> void:
	if node is GeometryInstance3D and node.material_override is ShaderMaterial:
		node.material_override.set_shader_parameter("wind_strength", 0.0)
	for child in node.get_children(): _freeze_visuals(child)
	if node == scene:
		var sample: Dictionary = scene._atmosphere.campaign_sample()
		sample.seconds = 120.0
		scene._atmosphere.source = func() -> Dictionary: return sample
		scene._atmosphere.update_view(0.0, true)

func _capture(label: String) -> void:
	for i in range(6): await process_frame
	var times: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var rid: RID = root.get_viewport_rid()
	for i in range(12):
		var started: int = Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		times.append((Time.get_ticks_usec() - started) / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	var status: int = root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if status != OK: report.failures.append("Capture failed: " + label)
	var rings: Array[int] = [0, 0, 0, 0]
	for batch: Dictionary in scene.scenery._active.batches:
		for transform: Transform3D in batch.transforms:
			var distance: float = (scene.scenery._active.node.position + transform.origin).distance_to(camera.position)
			var ring: int = 0 if distance <= 20.0 else (1 if distance <= 100.0 else (2 if distance <= 200.0 else 3))
			rings[ring] += 1
	report.samples.append({"label": label, "frame_ms": _distribution(times), "render_cpu_ms": _distribution(cpu), "render_gpu_ms": _distribution(gpu),
		"scenery": scene.scenery.diagnostics(), "near_patches": scene.flora.patches.size(), "distance_rings_20_100_200_outer": rings,
		"tiles": scene.terrain.leaves.size(), "nodes": scene.get_tree().get_node_count(),
		"draw_calls": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)})

func _distribution(values: Array[float]) -> Dictionary:
	values.sort()
	return {"count": values.size(), "p50": values[int(values.size() * 0.5)], "p95": values[mini(values.size() - 1, int(values.size() * 0.95))], "p99": values[-1], "max": values[-1]}

func _geometry_metrics() -> Dictionary:
	var body: Dictionary = scene.terrain.surface.body
	var level: int = Layout.new(body.radius).max_level - 2
	var side: int = 1 << level
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var maximum: float = 0.0
	for face in range(6):
		var tile: Dictionary = Layout.patch(face, level, side / 2, side / 2)
		tile.mask = 5
		tile.anchor = scene.terrain.surface.point(face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
		var arrays: Array = Patch.build_arrays(tile, scene.terrain.surface).land_arrays
		digest.update(var_to_bytes(Patch.collision_faces(arrays)))
		for y in range(16):
			for x in range(16):
				var up: Vector3 = Cube.vector(Cube.direction(face, tile.uv.x + (x + 0.5) * tile.width / 16.0, tile.uv.y + (y + 0.5) * tile.width / 16.0))
				var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][arrays[Mesh.ARRAY_INDEX][(y * 16 + x) * 6]]
				maximum = maxf(maximum, normal.distance_to(up))
	return {"collision_sha256": digest.finish().hex_encode(), "maximum_top_normal_error": maximum, "patches": 6}
