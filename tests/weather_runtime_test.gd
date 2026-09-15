extends SceneTree
const Model = preload("res://world/weather/weather_model.gd")
const View = preload("res://world/weather/weather_view.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
		var transform: Transform3D = view._rain.multimesh.get_instance_transform(i)
		if transform.basis.determinant() > 0.0:
			visible_drops += 1
			_expect(transform.origin.y >= -3.35, "Rain passed through sampled floor.")
	_expect(visible_drops > 0, "No rain streaks above ground.")
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
	_expect(not expected.is_empty() and expected.precipitation > 0.0, "Weather child did not join campaign.")
	var copy: Dictionary = weather.snapshot()
	copy.condition = "firestorm"
	_expect(weather.snapshot().condition != "firestorm", "Snapshot exposes mutable weather state.")
	var environment: Environment = current_scene.get_world_3d().environment
	var sky_color: Color = environment.background_color
	var fog_end: float = environment.fog_depth_end
	flow.toggle_pause()
	for i in range(5): await process_frame
	_expect(weather.snapshot() == expected, "Paused weather advanced.")
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
	# Existing saved campaign clock is the only persistence input. Reload actual slot.
	flow.return_to_title()
	await scene_changed
	await _open(path)
	for i in range(3): await process_frame
	if current_scene.scene_file_path == Surface.SCENE:
		var restored: Dictionary = current_scene.get_node("Weather").snapshot()
		_expect(restored == expected, "Save/load rerolled weather or retained previous view state.")
		_expect(get_nodes_in_group(&"campaign_weather").size() == 1, "Reload duplicated weather owners.")
		flow.return_to_title()
		await scene_changed
	else: _expect(false, "Weather reload failed.")
	_expect(get_nodes_in_group(&"campaign_weather").is_empty(), "Weather leaked into main menu.")

func _open(path: String) -> void:
	var flow: Node = root.get_node("SessionFlow")
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	flow.load_game(path)
	var started: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - started < 50000: await process_frame
	root.get_node("SaveGameService").autosave_enabled = false

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
