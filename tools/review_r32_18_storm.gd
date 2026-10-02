extends SceneTree
## Native fixed-clock review of the actual spherical campaign weather owner.
## No preview presets, manual condition flags, protection bypass or damage.
const Surface = preload("res://core/campaign/surface_context.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Climate = preload("res://world/weather/planet_climate.gd")
const Storm = preload("res://world/weather/r32_regular_storm.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var folder: String
var weather: Node
var state: Node
var flow: Node
var camera: Camera3D
var initial_pose: Transform3D
var body: Dictionary
var cycle: Dictionary
var offset: float = 0.0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	folder = args[args.find("--capture") + 1] if "--capture" in args else ""
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		push_error("R32-18 visible review requires a capture directory and native renderer.")
		quit(1)
		return
	state = root.get_node("GameState")
	flow = root.get_node("SessionFlow")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves.session_managed = true
	var settings: Node = root.get_node("DisplaySettings")
	settings.display_mode = 0
	settings.resolution = Vector2i(960, 540)
	settings.vsync_enabled = false
	settings._apply_settings(false)
	root.size = Vector2i(960, 540)
	root.get_node("LocaleManager")._apply("de")
	var path: String = saves.create_slot("R32-18 regular rainstorm", 15838, Cube.MODE)
	_expect(not path.is_empty(), "Campaign slot creation failed.")
	if path.is_empty(): await _finish(); return
	# Use the standard seed on a naturally assigned, unprotected temperate body
	# in another system. Never remove the actual home's protection reference.
	var selected: Dictionary = {}
	var selected_system: int = 0
	for system_seed: int in range(23757, 23789):
		var candidate: Dictionary = state.campaign.ensure_body(15838, system_seed)
		if not candidate.is_empty() and candidate.weather_climate.profile_id == "earth_temperate":
			var site: Dictionary = _site(candidate)
			if not site.is_empty():
				selected = candidate
				selected_system = system_seed
				selected.surface_context.spawn = site
				state.campaign.body_record(candidate.id).surface_context.spawn = site
				break
	_expect(not selected.is_empty(), "No naturally admitted wet/warm dry storm location.")
	if selected.is_empty(): await _finish(); return
	body = state.campaign.body_record(selected.id)
	_expect(state.activate_body(body.id, selected_system, 1, false), "Away-body activation failed.")
	cycle = Storm.schedule(body.id, body.seed)
	for index in range(12):
		var warning_clock: float = float(cycle.calm) + cycle.period * index
		var phase: float = Atmosphere.day_progress(warning_clock)
		if phase > 0.30 and phase < 0.55:
			offset = cycle.period * index
			break
	state.campaign.data.elapsed_seconds = offset + float(cycle.calm) - 5.0
	state.set_simulation_speed(0.0)
	var spawn: Dictionary = body.surface_context.spawn
	var heading: Vector3 = -Cube.frame(Cube.vector(Cube.direction(spawn.face, spawn.u, spawn.v))).z
	saves._last_player_state = {"surface_address": spawn.duplicate(true), "surface_forward": [heading.x, heading.y, heading.z],
		"surface_velocity": [0.0, 0.0, 0.0], "surface_pitch": -0.10}
	saves._pending_player_state = saves._last_player_state.duplicate(true)
	_expect(saves.save_now(), "Initial normal-storm slot failed.")
	FileAccess.open(folder.path_join("reference-save.json"), FileAccess.WRITE).store_string(FileAccess.get_file_as_string(path))
	saves.session_active = false
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	RenderingServer.render_loop_enabled = false
	flow.load_game(path)
	var started: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - started < 90000: await process_frame
	_expect(not flow.loading and current_scene.scene_file_path == Surface.SCENE, "Actual campaign load failed or exceeded existing 90-s guard.")
	if flow.loading or current_scene.scene_file_path != Surface.SCENE:
		RenderingServer.render_loop_enabled = true
		await _finish(); return
	weather = current_scene.get_node("Weather")
	camera = root.get_camera_3d()
	current_scene.player.set_physics_process(false)
	initial_pose = camera.global_transform
	RenderingServer.render_loop_enabled = true
	for frame in range(4): await process_frame
	# Native sequence is explicitly time-compressed fixed campaign seconds.
	# It is not a real-time play/FPS claim. Each frame reads the normal source.
	var first: float = offset + float(cycle.calm) - 5.0
	for frame in range(125):
		var clock: float = first + frame * 3.0
		await _capture("frame-%04d.png" % frame, clock, "time-compressed")
		if not failures.is_empty(): break
	var peak: float = offset + float(cycle.calm) + Storm.WARNING_SECONDS + Storm.RISE_SECONDS + 30.0
	await _capture("storm-peak.png", peak, "peak")
	var saved_snapshot: Dictionary = weather.snapshot()
	var saved_forecast: Array = weather.forecast()
	_expect(saves.save_now(), "Real campaign peak checkpoint failed.")
	flow.toggle_pause()
	for frame in range(3): await process_frame
	_expect(weather.snapshot() == saved_snapshot and state.campaign.data.elapsed_seconds == peak, "Pause moved the normal storm.")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("storm-pause.png"))
	flow.resume()
	weather._process(0.0)
	_expect(weather.snapshot() == saved_snapshot and weather.forecast() == saved_forecast, "Resume changed derived storm or forecast.")
	root.get_node("LocaleManager")._apply("en")
	await _capture("storm-warning-en.png", offset + float(cycle.calm) + 30.0, "warning-en")
	await _capture("storm-warning-de.png", offset + float(cycle.calm) + 30.0, "warning-de", "de")
	weather.set_preview_condition("rain")
	for frame in range(3): await process_frame
	_expect(weather.snapshot().preview and weather.forecast().is_empty() and not weather._forecast_panel._panel.visible, "Diagnostic preview retained normal warning.")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("diagnostic-rain.png"))
	weather.set_preview_condition("")
	await _capture("normal-rain.png", 580.0, "normal-rain")
	# The existing session owner restores the saved peak; no weather event is
	# persisted and no new save participant is installed by this Fachbranch.
	flow.return_to_title()
	await scene_changed
	RenderingServer.render_loop_enabled = false
	flow.load_game(path)
	started = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - started < 90000: await process_frame
	_expect(not flow.loading and current_scene.scene_file_path == Surface.SCENE, "Real storm reload failed or exceeded existing 90-s guard.")
	RenderingServer.render_loop_enabled = true
	if not flow.loading and current_scene.scene_file_path == Surface.SCENE:
		weather = current_scene.get_node("Weather")
		camera = root.get_camera_3d()
		current_scene.player.set_physics_process(false)
		initial_pose = camera.global_transform
		for frame in range(4): await process_frame
		_expect(state.campaign.data.elapsed_seconds == peak, "Saved peak clock was not restored.")
		await _capture("storm-reloaded.png", peak, "reloaded-peak")
		_expect(weather.snapshot().get("storm_event_id") == saved_snapshot.get("storm_event_id")
			and weather.snapshot().get("storm_phase") == saved_snapshot.get("storm_phase"), "Actual scene reload changed storm identity/phase.")
	await _finish()

func _site(candidate: Dictionary) -> Dictionary:
	var surface: RefCounted = Factory.create(Surface.descriptor(candidate))
	for face in range(6):
		for y in range(-15, 16):
			for x in range(-15, 16):
				var address: Dictionary = Cube.address(candidate.id, face, x / 16.0, y / 16.0)
				var direction: Array = Cube.direction(address.face, address.u, address.v)
				var point: Array = [direction[0] * surface.body.radius, direction[1] * surface.body.radius, direction[2] * surface.body.radius]
				if Storm.region(candidate.id, candidate.seed, point) < 0.90: continue
				var local: Dictionary = surface.sample(address)
				if local.get("moisture", 0.0) < 0.70 or local.get("temperature", 0.0) < 0.45: continue
				if not Surface.landing_problem(surface, address).is_empty(): continue
				address.height = local.height + 1.1
				return address
	return {}

func _capture(name: String, clock: float, label: String, locale: String = "") -> void:
	if not locale.is_empty(): root.get_node("LocaleManager")._apply(locale)
	state.campaign.data.elapsed_seconds = clock
	weather._forecast_elapsed = 1.0
	weather._process(0.0)
	current_scene._atmosphere.update_view(0.0, true)
	for frame in range(2): await process_frame
	await RenderingServer.frame_post_draw
	var snapshot: Dictionary = weather.snapshot()
	var climate: Dictionary = Space.sample(weather, camera.global_position)
	climate[Climate.FIELD] = state.get_current_body_record()[Climate.FIELD]
	climate.atmosphere = current_scene.terrain.surface.body.atmosphere
	var address: Dictionary = Space.address(weather, camera.global_position)
	var expected: Dictionary = Regional.sample(body.id, body.seed, clock, address, current_scene.terrain.surface.body.radius, climate)
	_expect(not snapshot.preview and snapshot.get("normal_storm_schema") == 1 and not snapshot.home_protected, "Native capture lacks admitted normal storm source.")
	_expect(snapshot.get("storm_phase") == expected.get("storm_phase") and snapshot.get("storm_intensity") == expected.get("storm_intensity"), "Campaign owner and normal source disagree.")
	_expect(weather._forecast_panel._warning.visible == bool(snapshot.get("storm_warning", false)), "Rendered banner disagrees with normal lead phase.")
	_expect(camera.global_transform.is_equal_approx(initial_pose), "Capture comparison camera moved.")
	_expect(weather._view._rain.multimesh.instance_count == 384 and weather._view._rain.multimesh.visible_instance_count <= 384, "Native storm grew precipitation budget.")
	_expect(root.get_texture().get_image().save_png(folder.path_join(name)) == OK, "Capture failed: " + name)
	rows.append({"file": name, "label": label, "body_id": body.id, "seed": body.seed, "clock": clock,
		"phase": snapshot.get("storm_phase"), "event": snapshot.get("storm_event_id"), "condition": snapshot.condition,
		"intensity": snapshot.get("storm_intensity"), "warning": snapshot.get("storm_warning"),
		"wind_mps": snapshot.wind_mps, "precipitation": snapshot.precipitation,
		"particles": weather._view._rain.multimesh.visible_instance_count, "camera": str(camera.global_transform),
		"locale": TranslationServer.get_locale()})

func _finish() -> void:
	var report: Dictionary = {"passed": failures.is_empty(), "failures": failures, "rows": rows,
		"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "size": [960, 540], "cycle": cycle,
		"scope": "Actual spherical campaign, naturally assigned unprotected temperate climate; fixed-clock time-compressed weather review, not target-PC/FPS acceptance. No preview storm or dangerous profile enabled."}
	FileAccess.open(folder.path_join("review.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	for failure in failures: push_error(failure)
	print("R32_18_NATIVE_STORM: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
