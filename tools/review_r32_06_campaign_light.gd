extends SceneTree
## Capture the regular SessionFlow campaign, never a replacement material world.
## Diagnostic placement/clock is recorded; production sun is never overridden.
const Cube = preload("res://world/space/cube_sphere.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Stats = preload("res://tools/performance_stats.gd")
const Shutdown = preload("res://core/runtime_shutdown.gd")
var config: Dictionary
var scene: Node3D
var air: Node3D
var camera: Camera3D
var state: Node
var report: Dictionary
var failures: Array[String] = []
var captures: Array = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	state = root.get_node("GameState")
	var saves := root.get_node("SaveGameService")
	var flow := root.get_node("SessionFlow")
	saves.autosave_enabled = false
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var settings := root.get_node("DisplaySettings")
	settings.display_mode = 0
	settings.resolution = Vector2i(960, 540)
	settings.vsync_enabled = false
	settings.graphics_values = preload("res://core/graphics_preferences.gd").preset(1)
	settings.atmosphere_quality = 1
	settings._apply_settings(false)
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	if config.has("initial_save"):
		var slot: String = saves.create_slot("R32-06 replay", 15838, Cube.MODE)
		if preload("res://core/persistence/atomic_json.gd").write(slot, config.initial_save, false) != OK:
			failures.append("Cannot write isolated replay save")
		else: flow.load_game(slot)
	else: flow.new_game("R32-06 light", 15838)
	var deadline: int = Time.get_ticks_msec() + 150000
	while flow.loading and Time.get_ticks_msec() < deadline: await process_frame
	if current_scene == null or current_scene.scene_file_path != Surface.SCENE or flow.loading:
		failures.append("Public campaign load failed: " + JSON.stringify(flow.startup_diagnostics()))
		await _finish(); return
	scene = current_scene
	air = scene._atmosphere
	scene.player.set_physics_process(false)
	# No input/AI/survival advance during visual preparation; procedural streaming
	# remains the normal campaign streaming path until the final pause.
	scene.player.process_mode = Node.PROCESS_MODE_DISABLED
	scene.population.process_mode = Node.PROCESS_MODE_DISABLED
	if not saves.save_now(): failures.append("Initial campaign snapshot failed")
	paused = true
	report = {"seed": 15838, "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(), "initial_save": saves._read_save(saves.save_path),
		"body": state.get_current_body_record().duplicate(true), "captures": captures,
		"target_pc_acceptance": false, "scene": scene.scene_file_path,
		"scope": "Regular public spherical campaign; diagnostic camera/clock/placement, frozen pose. No FPS or gameplay acceptance.",
		"component_note": "One-factor diagnostics retain production geometry/materials. No-sun/no-ambient/exposure are diagnostic overrides only; material pigment values are recorded, never changed."}
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.2
	camera.far = 30000.0
	scene.add_child(camera)
	camera.make_current()
	var views: Array = config.views if config.has("views") else _choose_views()
	report.views = views
	for view: Dictionary in views:
		print("R32_06_PREPARE ", view.id)
		# Freeze every simulation owner throughout preparation; only the actual
		# streaming owners run. Thus home animals cannot drift between replays.
		scene.flora.process_mode = Node.PROCESS_MODE_ALWAYS
		scene.scenery.process_mode = Node.PROCESS_MODE_ALWAYS
		scene.terrain.process_mode = Node.PROCESS_MODE_ALWAYS
		var address: Dictionary = view.address.duplicate(true)
		scene.player.place(address)
		scene.flora._refresh()
		var began: int = Time.get_ticks_msec()
		deadline = began + 90000
		while Time.get_ticks_msec() < deadline:
			await process_frame
			if _streamed(): break
		var ready: bool = _streamed()
		view["preparation"] = {"ms": Time.get_ticks_msec() - began, "complete": ready, "flora": scene.flora.streaming_diagnostics()}
		if not ready: failures.append("Incomplete campaign flora at " + str(view.id))
		var frame: Basis = scene.adapter.frame_at(address)
		var local: Vector3 = scene.adapter.to_local(address)
		camera.global_position = local + frame * Cube.vector(view.camera_offset)
		camera.look_at(local + frame * Cube.vector(view.target_offset), frame.y)
		scene.flora.process_mode = Node.PROCESS_MODE_INHERIT
		scene.scenery.process_mode = Node.PROCESS_MODE_INHERIT
		scene.terrain.process_mode = Node.PROCESS_MODE_INHERIT
		for phase: String in ["day", "night"]:
			# Find the actual clock giving the maximum/minimum elevation at this
			# canonical camera. Do not assign a direction that update_view resets.
			var seconds: float = _clock_for(phase == "day")
			state.campaign.data.elapsed_seconds = seconds
			scene.get_node("Weather")._physics_process(0.5)
			scene.get_node("Weather")._process(0.0)
			air.update_view(0.0, true)
			scene.terrain.presentation.advance(0.0)
			await _capture(str(view.id) + "-" + phase, "production", view)
			if phase == "day" and bool(config.get("components", true)):
				for mode: String in ["no-sun", "no-ambient", "exposure-half", "white-one", "albedo"]:
					air.apply_graphics(air.graphics_values, 1)
					match mode:
						"no-sun": air.sun.light_energy = 0.0
						"no-ambient": air.environment.ambient_light_energy = 0.0
						"exposure-half": air.environment.tonemap_exposure *= 0.5
						"white-one": air.environment.tonemap_white = 1.0
						"albedo":
							root.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
							air.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
							air.environment.tonemap_exposure = 1.0
							air.environment.adjustment_enabled = false
							air.environment.fog_enabled = false
							air.environment.glow_enabled = false
					await _capture(str(view.id) + "-day-" + mode, mode, view)
					root.debug_draw = Viewport.DEBUG_DRAW_DISABLED
					air.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
				air.update_view(0.0, true)
				air.apply_graphics(air.graphics_values, 1)
	paused = false
	flow.return_to_title()
	await scene_changed
	await _finish()

func _streamed() -> bool:
	return scene.flora.patches.size() == scene.flora.wanted.size() and scene.flora._publication.is_empty() and scene.flora._task < 0 and scene.scenery._task < 0 and scene.scenery._staging.is_empty()

func _choose_views() -> Array:
	var start: Dictionary = scene.player.location()
	var frame: Basis = scene.adapter.frame_at(start)
	var choices: Dictionary = {"forest": start.duplicate(true), "snow": {}, "water": {}}
	var scores: Dictionary = {"forest": -1.0, "snow": -1.0, "water": -1.0}
	# Deterministic local field search, independent of renderer or timing.
	for z: int in range(-6, 7):
		for x: int in range(-6, 7):
			var at: Dictionary = scene.adapter.offset(start, frame.x * x * 160 + frame.z * z * 160, 1.1)
			var sample: Dictionary = scene.terrain.surface.sample(at)
			for kind: String in ["forest", "snow", "water"]:
				var score: float = 0.0
				if kind == "forest": score = float(sample.biome_weights.get("forest", 0.0)) + float(sample.biome_weights.get("dense_forest", 0.0))
				elif kind == "snow": score = float(sample.biome_weights.get("snow", 0.0))
				else: score = 1.0 if sample.water else -1.0
				if score > scores[kind]: scores[kind] = score; choices[kind] = at
	# If no local snow/water exists, search canonical face cells; remain on the
	# same generated body and record the biome, never inject pale fixture boxes.
	for face: int in range(6):
		for y: int in range(-4, 5):
			for x: int in range(-4, 5):
				var at: Dictionary = Cube.address(scene.terrain.surface.body.id, face, x * 0.22, y * 0.22)
				var sample: Dictionary = scene.terrain.surface.sample(at)
				at.height = maxf(float(sample.height), float(sample.water_level)) + 1.1
				for kind: String in ["snow", "water"]:
					var score: float = float(sample.biome_weights.get("snow", 0.0)) if kind == "snow" else (1.0 if sample.water else -1.0)
					if score > scores[kind]: scores[kind] = score; choices[kind] = at
	var result: Array = []
	for kind: String in ["forest", "snow", "water"]:
		if choices[kind].is_empty(): failures.append("No real " + kind + " location"); continue
		var chosen: Dictionary = scene.terrain.surface.sample(choices[kind])
		choices[kind].height = maxf(float(chosen.height), float(chosen.water_level)) + 1.1
		result.append({"id": kind, "address": choices[kind], "sample": scene.terrain.surface.sample(choices[kind]),
			"camera_offset": [14, 10, 20], "target_offset": [0, -1, -22]})
	result.append({"id": "creature-horizon", "address": start, "sample": scene.terrain.surface.sample(start),
		"camera_offset": [5, 3, 9], "target_offset": [0, 1, -12]})
	return result

func _clock_for(day: bool) -> float:
	var sample: Dictionary = air.campaign_sample()
	var best: float = -INF if day else INF
	var result: float = 0.0
	for seconds: int in range(0, 1440, 4):
		var direction: Vector3 = air._base_sun_direction.rotated(air._day_axis, TAU * seconds / 1440.0)
		var elevation: float = sample.up.dot(direction)
		if (day and elevation > best) or (not day and elevation < best): best = elevation; result = seconds
	return result

func _capture(id: String, mode: String, view: Dictionary) -> void:
	var measured: Array = []
	var cpu: Array = []
	var gpu: Array = []
	# Draw only the paused scene, outside capture/readback times. These are
	# force_draw wall times, not frame intervals or gameplay FPS.
	for i: int in range(10):
		await process_frame
		var began: int = Time.get_ticks_usec()
		RenderingServer.force_draw(false)
		if i >= 4:
			measured.append((Time.get_ticks_usec() - began) / 1000.0)
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu())
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	var began: int = Time.get_ticks_usec()
	var image: Image = root.get_texture().get_image()
	var readback_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	if image.save_png(str(config.output).path_join(id + ".png")) != OK: failures.append("Cannot save " + id)
	var lighting: Dictionary = {"sun": air.sun.light_energy, "ambient": air.environment.ambient_light_energy,
		"exposure": air.environment.tonemap_exposure, "white": air.environment.tonemap_white,
		"sun_direction": [air._sun_direction.x, air._sun_direction.y, air._sun_direction.z],
		"sun_color": str(air.sun.light_color), "ambient_color": str(air.environment.ambient_light_color),
		"sample": air.campaign_sample(), "fog": air.environment.fog_enabled, "ssao": air.environment.ssao_enabled,
		"bloom": air.environment.glow_enabled, "preset": air.quality, "graphics": air.graphics_values}
	captures.append({"id": id, "mode": mode, "view": view.id, "clock": state.campaign.data.elapsed_seconds,
		"camera": str(camera.global_transform), "camera_address": scene.adapter.location(camera), "fov": camera.fov,
		"size": [image.get_width(), image.get_height()], "lighting": lighting,
		"palette": scene.terrain.surface.terrain.palette, "material_slots": scene.terrain.surface.terrain.material_slots,
		"draw_wall_ms": Stats.distribution(measured), "render_cpu_ms": Stats.distribution(cpu),
		"render_gpu_ms": Stats.distribution(gpu) if gpu.max() > 0.0 else null, "readback_ms": readback_ms,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"debug_draw": root.debug_draw, "tonemap": air.environment.tonemap_mode, "pixels": _pixels(image)})
	print("R32_06_CAPTURE ", id)

func _pixels(image: Image) -> Dictionary:
	var values: Array = []
	var clipped: int = 0
	var dark: int = 0
	for y: int in range(image.get_height() / 2, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var pixel: Color = image.get_pixel(x, y)
			values.append(pixel.get_luminance())
			if minf(pixel.r, minf(pixel.g, pixel.b)) > 0.98: clipped += 1
			if pixel.get_luminance() < 0.015: dark += 1
	return {"lower_half_luminance": Stats.distribution(values), "white_fraction": float(clipped) / values.size(), "black_fraction": float(dark) / values.size(), "note": "Display-referred sRGB luminance, lower-half grid; descriptive, not isolated material albedo."}

func _finish() -> void:
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var file := FileAccess.open(str(config.output).path_join("campaign-light.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	for failure: String in failures: push_error(failure)
	print("R32_06_LIGHT_PASSED" if failures.is_empty() else "R32_06_LIGHT_FAILED")
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)
