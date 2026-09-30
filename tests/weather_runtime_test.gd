extends SceneTree
const Model = preload("res://world/weather/weather_model.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const View = preload("res://world/weather/weather_view.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
var failures: Array[String] = []
var captures: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		captures = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(captures)
		_expect(DisplayServer.get_name() != "headless", "Campaign captures need a real renderer.")
		var settings: Node = root.get_node("DisplaySettings")
		settings.display_mode = 0
		settings.resolution = Vector2i(960, 540)
		settings.vsync_enabled = false
		settings._apply_settings(false)
		root.size = Vector2i(960, 540)
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	await _view_contract()
	await _campaign_contract()
	for failure in failures: push_error(failure)
	print("WEATHER_RUNTIME: bounded rain/clouds, radial frames, shelter, underwater, real campaign, pause/save/reload: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _view_contract() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var view := View.new()
	scene.add_child(view)
	view.configure(15838)
	var snap: Dictionary = Model.sample("weather-fixture", 15838, 580.0)
	snap.merge(Model.preset("rain"), true)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	collision.shape = box
	floor_body.add_child(collision)
	scene.add_child(floor_body)
	floor_body.position.y = -4.0
	await physics_frame
	await physics_frame
	view.position_at(Vector3.ZERO, Vector3.UP)
	view.probe_cover([])
	_expect(view._floors[12] > -4.0 and view._floors[12] < -3.0, "Rain did not find physical ground.")
	view.present(snap, false, false)
	_expect(view._rain.visible and view._rain.multimesh.visible_instance_count > 0, "Rain preview invisible.")
	var visible_drops: int = 0
	for i in range(view._rain.multimesh.visible_instance_count):
		var transform: Transform3D = view.particle_submission(i).transform
		if transform.basis.determinant() > 0.0:
			visible_drops += 1
			_expect(transform.origin.y >= -3.35, "Rain passed through sampled floor.")
	_expect(visible_drops > 0, "No rain streaks above ground.")
	var snow: Dictionary = Regional.preview(snap, "snow")
	view.present(snow, false, false)
	var visible_flakes: int = 0
	for i in range(view._rain.multimesh.visible_instance_count):
		var submission: Dictionary = view.particle_submission(i)
		var transform: Transform3D = submission.transform
		if transform.basis.determinant() > 0.0:
			visible_flakes += 1
			_expect(transform.basis.get_scale().y < 0.1 and submission.color.r > 0.8, "Snow reused dark elongated rain streaks.")
	_expect(visible_flakes > 0, "No snowflakes visible above ground.")
	view.present(snap, true, false)
	_expect(not view._rain.visible and not view._clouds.visible, "Atmosphere rendered underwater.")
	view.present(snap, false, true)
	_expect(not view._rain.visible, "Rain rendered inside shelter.")
	view.clouds_enabled = false
	view.present(snap, false, false)
	_expect(not view._clouds.visible and view._rain.visible, "Cloud ownership toggle disabled rain.")
	for up in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		view.position_at(Vector3(120, -45, 70), up)
		_expect(view.global_basis.y.dot(up) > 0.999, "Weather used world Y on a sphere face.")
	view.position_at(Vector3(-300, 12, 25), Vector3.RIGHT)
	_expect(view.global_position == Vector3(-300, 12, 25), "View retained old floating origin.")
	_expect(view._floors[12] == INF, "Camera travel reused a stale roof/ground probe.")
	_expect(view.get_child_count() == 2 and view._rain.multimesh.instance_count == 384 and view._clouds.multimesh.instance_count == 96, "Weather render budget grew.")
	scene.queue_free()
	await process_frame

func _campaign_contract() -> void:
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	var flow: Node = root.get_node("SessionFlow")
	saves.session_managed = true
	var path: String = saves.create_slot("Weather contract", 15838, Surface.Cube.MODE)
	_expect(not path.is_empty(), "Weather campaign creation failed.")
	if path.is_empty(): return
	state.campaign.data.elapsed_seconds = 580.0
	state.set_simulation_speed(0.0)
	_expect(saves.save_now(), "Weather time checkpoint failed.")
	saves.session_active = false
	await _open(path)
	if current_scene == null or current_scene.scene_file_path != Surface.SCENE or flow.loading:
		_expect(false, "Weather campaign did not load: " + saves.last_error)
		return
	var weather: Node = current_scene.get_node("Weather")
	for i in range(3): await process_frame
	var expected: Dictionary = weather.snapshot()
	weather.set_preview_condition("sandstorm")
	for i in range(3): await process_frame
	_expect(not weather.snapshot().has("storm_phase") and not weather._storm_notice._panel.visible, "Storm preview bypassed live home protection.")
	weather.set_preview_condition("")
	for i in range(3): await process_frame
	expected = weather.snapshot() # Capture after the camera/preview guard frames.
	_expect(not expected.is_empty() and expected.body_id == state.active_body_id, "Weather child did not join campaign.")
	_expect(expected.get("regional_schema") == 1 and weather.forecast().size() == 3, "Campaign lacks regional weather/forecast port.")
	_expect(weather._forecast_panel._panel.visible and weather._forecast_panel._forecast.size() == 3
		and weather._forecast_panel._snapshot.body_id == state.active_body_id
		and weather._forecast_panel._forecast[0].in_seconds == 60.0,
		"Live forecast UI did not show this body's local forecast windows.")
	# Advance less than the expensive forecast refresh interval: the day clock
	# must still match the current atmosphere sample, including rewinding a save.
	var air: Node = current_scene._atmosphere
	var initial_clock: float = state.campaign.data.elapsed_seconds
	for clock: float in [initial_clock + 0.25, initial_clock + 0.75, initial_clock]:
		state.campaign.data.elapsed_seconds = clock
		weather._forecast_elapsed = 0.0
		weather._process(0.01)
		air.update_view(0.0, true)
		_expect(is_equal_approx(float(weather._forecast_panel._snapshot.elapsed_seconds), air._elapsed),
			"Day UI and sky read different campaign clocks between forecast refreshes.")
		_expect(absf(weather._forecast_panel._day_bar.value - air.day_progress(clock) * 100.0) < 0.001,
			"The live day bar retained a previous campaign time.")
	weather._forecast_elapsed = 1.0
	weather._process(0.0)
	if not captures.is_empty(): await _capture_campaign_days(weather, air)
	# Native day evidence is a bounded cold campaign plus fixed-clock views.
	# The default contract still executes pause, actual slot reload and travel.
	if not captures.is_empty() and "--capture-days-only" in OS.get_cmdline_user_args():
		flow.return_to_title()
		await scene_changed
		return
	expected = weather.snapshot()
	var saved_sun: Vector3 = air._sun_direction
	var saved_clouds: Vector3 = air.sky_material.get_shader_parameter("cloud_offset")
	var copy: Dictionary = weather.snapshot()
	copy.condition = "firestorm"
	_expect(weather.snapshot().condition != "firestorm", "Snapshot exposes mutable weather state.")
	var environment: Environment = current_scene.get_world_3d().environment
	var sky_color: Color = environment.background_color
	var fog_end: float = environment.fog_depth_end
	flow.toggle_pause()
	for i in range(5): await process_frame
	_expect(weather.snapshot() == expected, "Paused weather advanced.")
	_expect(air._sun_direction == saved_sun and air.sky_material.get_shader_parameter("cloud_offset") == saved_clouds,
		"Pause advanced the sun or clouds.")
	_expect(not weather._forecast_panel._panel.visible, "Paused forecast covered the menu.")
	_expect(saves.save_now(), "Weather pause save failed.")
	flow.resume()
	var camera: Camera3D = current_scene.get_viewport().get_camera_3d()
	var position_before: Vector3 = camera.global_position
	var point: Array = current_scene.terrain.origin.duplicate()
	current_scene.terrain.rebase([point[0] + 25.0, point[1] - 13.0, point[2] + 45.0])
	_expect(camera.global_position != position_before, "Fixture did not shift the camera origin.")
	# process_frame fires BEFORE Node._process; compare after presentation has
	# consumed this frame's camera pose, not between physics and presentation.
	await create_timer(0.0).timeout
	_expect(weather._view.global_position.distance_to(camera.global_position) < 0.01, "Weather missed floating-origin shift: view=%s camera=%s" % [weather._view.global_position, camera.global_position])
	_expect(environment.background_color == sky_color and environment.fog_depth_end == fog_end and camera.environment == null, "Weather overwrote renderer/camera atmosphere.")
	var second_camera := Camera3D.new()
	current_scene.add_child(second_camera)
	second_camera.global_transform = camera.global_transform
	second_camera.make_current()
	await create_timer(0.0).timeout
	_expect(weather._last_camera == second_camera and weather._view.global_position.distance_to(second_camera.global_position) < 0.01, "Weather kept the old active camera.")
	camera.make_current()
	second_camera.queue_free()
	await create_timer(0.0).timeout
	# Existing saved campaign clock is the only persistence input. Reload actual slot.
	flow.return_to_title()
	await scene_changed
	await _open(path)
	for i in range(3): await process_frame
	_expect(not flow.loading, "Weather reload exceeded the normal campaign load budget.")
	if current_scene.scene_file_path == Surface.SCENE and not flow.loading:
		var restored: Dictionary = current_scene.get_node("Weather").snapshot()
		_expect(not restored.is_empty(), "Reload did not publish campaign weather.")
		if restored.is_empty(): return
		current_scene._atmosphere.update_view(0.0, true)
		_expect(current_scene._atmosphere._sun_direction.is_equal_approx(saved_sun)
			and current_scene._atmosphere.sky_material.get_shader_parameter("cloud_offset").is_equal_approx(saved_clouds),
			"Actual slot reload changed the saved sun/cloud phase.")
		_expect(restored.body_id == expected.body_id and restored.front_index == expected.front_index and restored.elapsed_seconds == expected.elapsed_seconds, "Save/load rerolled the regional front or clock.")
		# Camera settling and saved player placement can differ by millimetres;
		# regional values must stay continuous. Exact location is covered by the
		# cold-process model test, not a pre-settled camera transform.
		for key in ["precipitation", "cloud_cover", "wind_mps", "snow_intensity"]:
			_expect(absf(float(restored[key]) - float(expected[key])) < 0.003, "Save/load changed local weather: " + key)
		_expect(get_nodes_in_group(&"campaign_weather").size() == 1, "Reload duplicated weather owners.")
		await _travel_climates()
		flow.return_to_title()
		await scene_changed
	else: _expect(false, "Weather reload failed.")
	_expect(get_nodes_in_group(&"campaign_weather").is_empty(), "Weather leaked into main menu.")

func _travel_climates() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	var flow: Node = root.get_node("SessionFlow")
	var climate = preload("res://world/weather/planet_climate.gd")
	var home: String = state.active_body_id
	var policy: Dictionary = state.campaign.data.weather_policy.duplicate(true)
	var home_reference: Dictionary = state.get_current_body_record().weather_climate.duplicate(true)
	var away: Dictionary = state.campaign.ensure_body(23757, 15838)
	# Fixed synthetic destination exercises the live vacuum path on every run,
	# independent of the random campaign identity used for normal selection.
	state.campaign.body_record(away.id).weather_climate = climate.make_reference(away.id, "airless")
	var path: String = saves.save_path
	saves.save_path = "user://missing-weather-parent/blocked.json"
	_expect(not await flow.travel_to_planet(15838, 1, 23757, away.id), "Failed climate departure reported success.")
	_expect(state.active_body_id == home and state.campaign.data.weather_policy == policy, "Failed departure changed origin.")
	saves.save_path = path
	_expect(await flow.travel_to_planet(15838, 1, 23757, away.id), "Climate destination request failed: " + saves.last_error)
	await _wait_for_arrival()
	if flow.loading or current_scene.scene_file_path != Surface.SCENE: return
	for i in range(3): await process_frame
	var weather: Node = current_scene.get_node("Weather")
	var snap: Dictionary = weather.snapshot()
	_expect(snap.get("climate_id") == "airless" and not snap.get("atmosphere_present", true), "Live weather ignored destination's stored climate.")
	_expect(snap.get("cloud_cover", -1) == 0 and snap.get("precipitation", -1) == 0 and snap.get("wind_mps", -1) == 0, "Live vacuum weather was nonzero.")
	_expect(current_scene.terrain.surface.body.atmosphere == "none", "Descriptor disagrees with weather profile.")
	for forecast in weather.forecast(): _expect(forecast.precipitation == 0 and forecast.wind_mps == 0, "Live forecast ignored vacuum.")
	_expect(weather._forecast_panel._snapshot.body_id == away.id and weather._forecast_panel._forecast.size() == 3,
		"Planet travel kept the previous body's forecast.")
	await _storm_campaign_contract(weather)
	_expect(state.campaign.data.weather_policy == policy and get_nodes_in_group(&"campaign_weather").size() == 1, "Travel changed home or duplicated weather owner.")
	_expect(await flow.travel_to_planet(15838, 0, 15838, home), "Climate home return failed.")
	await _wait_for_arrival()
	if flow.loading or current_scene.scene_file_path != Surface.SCENE: return
	for i in range(3): await process_frame
	snap = current_scene.get_node("Weather").snapshot()
	_expect(snap.get("climate_id") == "earth_temperate" and snap.get("home_protected", false), "A-B-A did not restore protected home weather.")
	_expect(state.get_current_body_record().weather_climate == home_reference and state.campaign.data.weather_policy == policy, "A-B-A mutated stored origin/profile.")
	_expect(saves.save_now(), "Climate return checkpoint failed.")

func _storm_campaign_contract(weather: Node) -> void:
	var state: Node = root.get_node("GameState")
	var flow: Node = root.get_node("SessionFlow")
	var climate = preload("res://world/weather/planet_climate.gd")
	var storm = preload("res://world/weather/storm_preview.gd")
	var body: Dictionary = state.campaign.body_record(state.active_body_id)
	var original: Dictionary = body.weather_climate.duplicate(true)
	var atmosphere: String = current_scene.terrain.surface.body.atmosphere
	var clock: float = state.campaign.data.elapsed_seconds
	weather.set_preview_condition("sandstorm")
	for i in range(3): await process_frame
	_expect(not weather.snapshot().has("storm_phase"), "Live vacuum accepted a sandstorm.")
	# The destination fixture stays outside the protected origin. Exercise both
	# diagnostic climates in the real controller without enabling normal extremes.
	for kind: String in ["sandstorm", "ashstorm"]:
		body.weather_climate = climate.make_reference(body.id, storm.PROFILES[kind].climate)
		current_scene.terrain.surface.body.atmosphere = "temperate"
		var cycle: Dictionary = storm.schedule(body.id, int(body.seed), kind)
		state.campaign.data.elapsed_seconds = cycle.calm + 5.0
		weather.set_preview_condition(kind)
		for i in range(3): await process_frame
		var warning: Dictionary = weather.snapshot()
		_expect(warning.get("storm_phase") == "warning" and weather._storm_notice._panel.visible, "Live storm warning missing.")
		_expect(not weather._forecast_panel._panel.visible, "Diagnostic storm and normal forecast overlapped.")
		flow.toggle_pause()
		for i in range(3): await process_frame
		_expect(weather.snapshot() == warning and not weather._storm_notice._panel.visible, "Pause advanced storm or left warning over modal.")
		flow.resume()
		state.campaign.data.elapsed_seconds = cycle.calm + cycle.warning + cycle.rising + 5.0
		for i in range(3): await process_frame
		_expect(weather.snapshot().get("storm_phase") == "peak", "Live preview never reached peak.")
		var saves: Node = root.get_node("SaveGameService")
		_expect(saves.save_now(), "Saving during diagnostic storm failed.")
		var saved: String = FileAccess.get_file_as_string(saves.save_path)
		_expect("storm_phase" not in saved and "storm_preview_schema" not in saved, "Diagnostic storm became persisted state.")
		weather.set_preview_condition("")
		for i in range(3): await process_frame
		_expect(not weather.snapshot().has("storm_phase") and not weather._storm_notice._panel.visible, "Turning preview off left storm state.")
	body.weather_climate = original
	current_scene.terrain.surface.body.atmosphere = atmosphere
	state.campaign.data.elapsed_seconds = clock
	weather.set_preview_condition("sandstorm")
	for i in range(3): await process_frame
	_expect(not weather.snapshot().has("storm_phase") and not weather._storm_notice._panel.visible, "Vacuum switch retained storm/warning.")
	weather.set_preview_condition("")

func _wait_for_arrival() -> void:
	var started: int = Time.get_ticks_msec()
	while root.get_node("SessionFlow").loading and Time.get_ticks_msec() - started < 90000: await process_frame
	_expect(not root.get_node("SessionFlow").loading, "Climate travel timed out.")

func _open(path: String) -> void:
	var flow: Node = root.get_node("SessionFlow")
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	if not captures.is_empty(): RenderingServer.render_loop_enabled = false
	flow.load_game(path)
	var started: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - started < 90000: await process_frame
	root.get_node("SaveGameService").autosave_enabled = false
	if not captures.is_empty(): RenderingServer.render_loop_enabled = true

func _capture_campaign_days(weather: Node, air: Node) -> void:
	var state: Node = root.get_node("GameState")
	var previous: float = state.campaign.data.elapsed_seconds
	var player: Node = current_scene.player
	player.set_physics_process(false)
	var camera: Camera3D = get_root().get_camera_3d()
	var pose: Transform3D = camera.global_transform
	var report: Array[Dictionary] = []
	for phase: Dictionary in [{"id": "dawn", "seconds": 900.0}, {"id": "noon", "seconds": 1260.0},
			{"id": "dusk", "seconds": 180.0}, {"id": "night", "seconds": 540.0}]:
		state.campaign.data.elapsed_seconds = phase.seconds
		weather._forecast_elapsed = 1.0
		weather._process(0.0)
		air.update_view(0.0, true)
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		_expect(camera.global_transform.is_equal_approx(pose), "Campaign comparison camera moved.")
		_expect(root.get_texture().get_image().save_png(captures.path_join("campaign-" + str(phase.id) + ".png")) == OK,
			"Cannot save actual campaign day capture.")
		report.append({"phase": phase.id, "campaign_seconds": air._elapsed,
			"ui_seconds": weather._forecast_panel._snapshot.elapsed_seconds,
			"sun_direction": [air._sun_direction.x, air._sun_direction.y, air._sun_direction.z],
			"sun_energy": air.sun.light_energy, "cloud_cover": weather.snapshot().cloud_cover,
			"body_id": state.active_body_id, "camera": str(camera.global_transform),
			"water_shader_time": current_scene.terrain.presentation.time,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	state.campaign.data.elapsed_seconds = previous
	weather._forecast_elapsed = 1.0
	weather._process(0.0)
	air.update_view(0.0, true)
	player.set_physics_process(true)
	FileAccess.open(captures.path_join("campaign-days.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"renderer": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(), "scope": "Actual fixed-camera spherical campaign; simulation speed zero, canonical clock explicitly advanced. Water clock discrepancy remains a shared integration proposal.",
		"samples": report}, "\t") + "\n")

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
