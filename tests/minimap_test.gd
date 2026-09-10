extends SceneTree
const Profile = preload("res://core/map/minimap_profile.gd")
const MapProjection = preload("res://core/map/surface_map_projection.gd")
const Raster = preload("res://ui/minimap/minimap_terrain.gd")
const HUD = preload("res://ui/minimap/minimap_hud.gd")
const Source = preload("res://ui/minimap/minimap_source.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
var failures: Array[String] = []
var sample_calls: int = 0
var snapshot: Dictionary = {}
var hud: CanvasLayer
var scene: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://minimap_test.json"
	var state := root.get_node("GameState")
	state.start_world_with_seed(15838)
	state.set_process(false)
	await process_frame
	_test_profiles()
	_test_projection()
	_test_raster()
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(10, 100, -15)
	scene.add_child(player)
	player.fall_acceleration = 0
	await _frames(5)
	hud = get_first_node_in_group(&"minimap_hud")
	_expect(hud != null and hud.visible, "Player did not install the map.")
	var body: Dictionary = state.get_current_body()
	var home: Dictionary = Home.create(body["id"], state.campaign.data["player_species_id"], Vector3(40, 0, -20))
	state.get_current_body_record()["home_group"] = home
	var original: Dictionary = state.campaign.export_state()
	var observation: Dictionary = root.get_node("ProgressionService").export_state()
	var real_snapshot: Dictionary = Source.campaign_snapshot(player, self)
	_expect(real_snapshot["markers"].size() == 3, "Home and exactly the two own members were not shown.")
	_expect(real_snapshot["address"]["body_id"] == home["body_id"], "Source lost body identity.")
	snapshot = real_snapshot.duplicate(true)
	snapshot["sample"] = _sample_address
	hud.snapshot_provider = func() -> Dictionary: return snapshot
	hud.invalidate()
	hud._update_snapshot()
	for i in range(90): hud.terrain.step_work()
	_expect(hud.terrain.completed, "Map raster did not finish.")
	_expect(hud._map.markers.size() == 3, "Own markers missing from canvas.")
	var shown: Vector2 = hud.projection.project(snapshot["address"])
	snapshot["address"]["position"][0] += 20.0
	snapshot["forward"] = Vector3.RIGHT
	hud._update_snapshot()
	_expect(is_equal_approx(hud._map.position_m.x - shown.x, 20.0), "Movement scale is wrong.")
	_expect(hud._map.direction.is_equal_approx(Vector2.RIGHT), "East-facing player points the wrong way.")
	var initial_range: float = hud.range_m
	await _key(KEY_MINUS)
	_expect(hud.range_m == initial_range * 2.0, "Minus did not zoom out.")
	await _key(KEY_PLUS)
	_expect(hud.range_m == initial_range, "Plus did not zoom in.")
	var future: Dictionary = state.campaign.export_state()
	for phase in range(1, 5):
		snapshot["phase"] = phase
		hud._update_snapshot()
		_expect(hud.zoom_index == 1 and hud.range_m == Profile.for_phase(phase)["radius_m"], "Phase did not reset to its wider default.")
	_expect(state.current_phase == 0 and state.campaign.export_state() == future, "Map preview enabled an unimplemented phase.")
	paused = true
	hud._process(1.0)
	var samples_before: int = hud.terrain.samples_total
	await _key(KEY_MINUS)
	_expect(not hud.visible and hud.terrain.samples_total == samples_before, "Paused map remained active.")
	paused = false
	hud._process(1.0)
	_expect(hud.visible, "Map did not return after pause.")
	for dimensions in [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(800, 900)]:
		root.size = dimensions
		await _frames(4)
		hud._layout()
		var rect := Rect2(hud._panel.get_global_transform_with_canvas().origin, hud._panel.size * hud.transform.get_scale())
		_expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(rect), "Map escaped screen at " + str(dimensions))
		_expect(hud._map.size.x >= 150, "Map is unreadably small.")
	# Source reload: the map has no parallel save file. Markers come back from
	# the same body-owned record, while phase and cache are derived afresh.
	_expect(state.campaign.export_state() == original, "Map wrote to campaign state.")
	_expect(root.get_node("ProgressionService").export_state() == observation, "Map disclosed discoveries or rewards.")
	hud.snapshot_provider = Callable()
	hud._update_snapshot()
	hud.change_zoom(1)
	_expect(hud.zoom_index == 2, "Reload fixture did not have manual zoom.")
	_expect(saves.save_now(), "Campaign with home could not save.")
	state.get_current_body_record().erase("home_group")
	_expect(saves.load_now(), "Campaign did not reload.")
	hud._update_snapshot()
	_expect(hud.phase == 0 and hud.zoom_index == 1 and hud._map.markers.size() == 3, "Reload lost home or phase scale.")
	var old_context: String = hud._context_id
	state.start_world_with_seed(63352)
	hud._update_snapshot()
	_expect(hud._context_id != old_context and hud._map.markers.is_empty(), "New world inherited old map/markers.")
	_expect(hud.terrain.coverage() == 0.0, "Old terrain remained after world reset.")
	# Real generator shoreline classification. Find actual water, don't draw a
	# decorative blue blob. Only 81 bounded point probes.
	var generator := root.get_node("WorldGenerator")
	var checked_water: int = 0
	for x in range(-4, 5):
		for z in range(-4, 5):
			var address: Dictionary = MapProjection.plane_address("probe", Vector3(x * 64, 0, z * 64))
			if generator.is_water_at(x * 64, z * 64):
				var color: Color = Source.sample_plane(address, generator)
				_expect(color.b > color.r and color.g > color.r, "Water is not mapped blue.")
				checked_water += 1
	_expect(checked_water > 0, "Water fixture found no shoreline.")
	_test_real_raster(generator)
	scene.queue_free()
	await _frames(3)
	_expect(get_nodes_in_group(&"minimap_hud").is_empty(), "Map leaked after leaving the world.")
	for failure in failures: push_error(failure)
	print("MINIMAP_OK" if failures.is_empty() else "MINIMAP_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _test_profiles() -> void:
	var previous: float = 0.0
	for phase in range(5):
		var radius: float = Profile.for_phase(phase)["radius_m"]
		_expect(radius > previous, "Later phase is not zoomed out further.")
		previous = radius
	_expect(Profile.for_phase(99)["radius_m"] == previous, "Legacy phase value broke profile lookup.")
	_expect(Profile.for_phase(4, 2, 100.0)["radius_m"] <= 65.0, "Small sphere map wraps to the antipode.")

func _test_projection() -> void:
	var plane := MapProjection.new()
	var address := {"mode": "legacy_plane_v9", "body_id": "a", "position": [1.0e9, 0.0, -1.0e9]}
	_expect(plane.configure(address), "Legacy projection rejected.")
	var close := address.duplicate(true)
	close.position[0] += 0.125
	_expect(is_equal_approx(plane.project(close).x, 0.125), "Precision lost before local subtraction.")
	close.body_id = "foreign"
	_expect(not plane.project(close).is_finite(), "Marker from another planet accepted.")
	for origin in [Cube.address("earth", 4, 0, 0), Cube.address("earth", 0, 0.99999, 0.2), Cube.address("earth", 2, 0, 0)]:
		var sphere := MapProjection.new()
		_expect(sphere.configure(origin, 6371000.0), "Earth projection rejected.")
		for offset in [Vector2(0.25, -0.5), Vector2(1200, 600), Vector2(-500, -900)]:
			var projected: Vector2 = sphere.project(sphere.address_at(offset))
			_expect(projected.distance_to(offset) < 0.002, "Sphere seam/pole metre roundtrip failed: " + str(projected - offset))
		var same_origin: Dictionary = sphere.address_at(Vector2.ZERO)
		_expect(sphere.project(same_origin).length() < 0.002, "Floating origin shifted the map center.")

func _test_raster() -> void:
	var raster := Raster.new()
	raster.request(Vector2.ZERO, 64, _sample_offset)
	var attempts: int = 0
	while not raster.completed and attempts < 500:
		raster.step_work()
		_expect(raster.last_samples <= Raster.MAX_SAMPLES, "Exceeded per-frame sample budget.")
		attempts += 1
	_expect(raster.completed and sample_calls == Raster.GRID * Raster.GRID, "Raster coverage incomplete.")
	var count: int = sample_calls
	raster.request(Vector2(0.01, 0.01), 64, _sample_offset)
	raster.step_work()
	_expect(sample_calls == count, "Stationary map resampled the whole terrain.")
	raster.request(Vector2(raster.cell * 1.1, 0), 64, _sample_offset)
	while not raster.completed: raster.step_work()
	_expect(sample_calls - count == Raster.GRID, "One-cell movement did not reuse cached terrain.")
	raster.request(Vector2.ZERO, 64, _sample_offset)
	raster.step_work()
	_expect(raster.completed, "Revisit did not reuse cached samples.")
	raster.reset()
	_expect(raster._cache.is_empty() and not raster.completed, "World invalidation retained raster cache.")
	for x in range(4):
		raster.request(Vector2(x * 150, 0), 64, _sample_offset)
		while not raster.completed: raster.step_work()
	_expect(raster._cache.size() == Raster.CACHE_LIMIT and raster._cache_order.size() == Raster.CACHE_LIMIT, "Exploration cache grew beyond its fixed limit.")

func _test_real_raster(generator: Node) -> void:
	for radius in [64.0, 160.0]:
		var raster := Raster.new()
		var projection := MapProjection.new()
		projection.configure(MapProjection.plane_address("benchmark", Vector3.ZERO))
		var sampler := func(offset: Vector2) -> Color: return Source.sample_plane(projection.address_at(offset), generator)
		var started: int = Time.get_ticks_usec()
		raster.request(Vector2.ZERO, radius, sampler)
		var steps: int = 0
		var worst: int = 0
		while not raster.completed and steps < 2400:
			raster.step_work()
			worst = maxi(worst, raster.last_usec)
			steps += 1
		_expect(raster.completed, "Real terrain map did not converge.")
		var total_usec: int = Time.get_ticks_usec() - started
		var before: int = raster.samples_total
		raster.request(Vector2.ZERO, radius, sampler)
		raster.step_work()
		_expect(raster.samples_total == before and raster.last_usec == 0, "Stationary real terrain was resampled.")
		print("MINIMAP_PERF ", JSON.stringify({"radius_m": radius, "samples": before, "steps": steps, "total_ms": total_usec / 1000.0, "worst_sampling_step_ms": worst / 1000.0, "stationary_samples": raster.last_samples}))

func _sample_offset(offset: Vector2) -> Color:
	sample_calls += 1
	return Color("3c8195") if offset.x < 0.0 else Color("6e865e")

func _sample_address(address: Dictionary) -> Color:
	return Color("3c8195") if float(address.position[0]) < 0 else Color("6e865e")

func _key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
