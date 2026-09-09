extends SceneTree

const Surface = preload("res://world/streaming/world_water_mesh_job.gd")
const Style = preload("res://world/visuals/terrain/water_surface_style.gd")
var _horizon_script: Script
var _builder: Script
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_horizon_script = load("res://world/visuals/terrain/landscape_horizon.gd")
	_builder = load("res://world/visuals/terrain/water_mesh_builder_v7.gd")
	root.get_node("SaveGameService").autosave_enabled = false
	var generator: Node = root.get_node("WorldGenerator")
	generator.set_seed_override(15838)
	_check_mesh(generator)
	_check_style(generator)
	_check_recentering()
	await _check_ownership(generator)
	for failure: String in _failures:
		push_error(failure)
	print("Water continuity: closed interior mesh edges, world style, settings, atomic ownership, partial overlap, teleport, teardown and recenter hysteresis.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if _failures.is_empty() else 1)

func _check_mesh(generator: Node) -> void:
	var arrays: Array = Surface.build(generator, Vector2(-64, 128), 384.0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_expect(vertices.size() == 37249 and indices.size() == 73728 * 3, "Shared water exceeded its fixed geometry budget.")
	var edges: Dictionary = {}
	var winding_ok: bool = true
	for index in range(0, indices.size(), 3):
		var a: int = indices[index]
		var b: int = indices[index + 1]
		var c: int = indices[index + 2]
		winding_ok = winding_ok and (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).y < 0.0
		for edge: Vector2i in [Vector2i(a, b), Vector2i(b, c), Vector2i(c, a)]:
			var key := Vector2i(mini(edge.x, edge.y), maxi(edge.x, edge.y))
			edges[key] = int(edges.get(key, 0)) + 1
	_expect(winding_ok, "Water contains degenerate or inward triangles.")
	var open_interior: int = 0
	var perimeter: int = 0
	for edge: Vector2i in edges:
		if int(edges[edge]) == 2:
			continue
		var a: Vector3 = vertices[edge.x]
		var b: Vector3 = vertices[edge.y]
		var on_boundary: bool = (a.x == b.x and a.x in [-448.0, 320.0]) or (a.z == b.z and a.z in [-256.0, 512.0])
		if int(edges[edge]) == 1 and on_boundary:
			perimeter += 1
		else:
			open_interior += 1
	_expect(open_interior == 0 and perimeter == 768, "Fine/coarse water grid contains cracks or overlapping triangles.")
	var axis: PackedFloat32Array = Surface.axis_values(384.0)
	_expect(axis[33] - axis[32] == 2.0 and axis[1] - axis[0] == 8.0, "Near water lost its denser mesh.")
	print("Shared water geometry: ", vertices.size(), " vertices, ", indices.size() / 3, " triangles; interior open edges ", open_interior)

func _check_style(generator: Node) -> void:
	var first_cache: Dictionary = {}
	var second_cache: Dictionary = {}
	for point: Vector2 in [Vector2(-32, -64), Vector2(16, 48), Vector2(0, 0), Vector2(32, -32)]:
		var a: float = Style.sample_stillness(generator, point, first_cache)
		var b: float = Style.sample_stillness(generator, point, second_cache)
		_expect(a == b and a >= 0.0 and a <= 1.0, "Water style depends on the owning chunk/cache.")
		for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
			var before: float = Style.sample_stillness(generator, point - direction * 0.001, first_cache)
			var after: float = Style.sample_stillness(generator, point + direction * 0.001, first_cache)
			_expect(absf(before - after) < 0.001, "Water style jumps across a world-grid edge.")
	# Exercise an actual calm/rough transition even when the selected seed's
	# inspected coastline is ocean. These are samples, not a replacement generator.
	var gradient: Dictionary = {Vector2i(0, 0): 0.0, Vector2i(1, 0): 1.0, Vector2i(0, 1): 0.0, Vector2i(1, 1): 1.0}
	_expect(is_equal_approx(Style.sample_stillness(generator, Vector2(16, 16), gradient), 0.5), "Calm water failed to interpolate between sampled regions.")

func _check_recentering() -> void:
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_expect(_horizon_script.recenter_target(direction * 33.0, Vector2.ZERO) == Vector2.ZERO, "Pacing near a rounding edge rebuilds the horizon.")
		_expect(_horizon_script.recenter_target(direction * 95.0, Vector2.ZERO) == Vector2.ZERO, "Horizon movement hysteresis is missing.")
		_expect(_horizon_script.recenter_target(direction * 97.0, Vector2.ZERO) == direction * 128.0, "Horizon failed to follow sustained travel.")
	_expect(_horizon_script.recenter_target(Vector2(1025, -1025), Vector2.ZERO) == Vector2(1024, -1024), "Teleport did not request a new world-aligned surface.")

func _check_ownership(generator: Node) -> void:
	Engine.max_fps = 120
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := CharacterBody3D.new()
	player.name = "Player"
	fixture.add_child(player)
	player.add_to_group(&"player")
	player.position = generator.get_scenic_spawn()
	var manager: Node = load("res://world/world_manager.tscn").instantiate()
	manager.render_distance = 0
	manager.choose_scenic_spawn_for_default_start = false
	fixture.add_child(manager)
	await _wait_for_surface(manager, player)
	_expect(manager.shared_water_bounds.has_area(), "Shared water never became active.")
	var chunk: Node3D = manager.loaded_chunks.get(manager.current_player_chunk)
	if chunk == null:
		_failures.append("Water fixture has no player chunk.")
		fixture.free()
		return
	var water: MeshInstance3D = chunk.get_node("WaterMesh")
	var horizon: Node = manager.get_node("LandscapeHorizon")
	var shared: MeshInstance3D = horizon.get_node("DistantWater")
	_expect(not water.visible and shared.mesh != null, "World and local water overlap after publication.")
	for name: String in ["deep_color", "shallow_color", "wave_height", "wave_speed", "wave_scale", "secondary_wave_height", "secondary_wave_speed", "water_roughness", "water_specular", "foam_distance", "depth_fade_distance", "refraction_strength"]:
		_expect(water.material_override.get_shader_parameter(name) == shared.material_override.get_shader_parameter(name), "Fallback and shared water disagree on " + name)
	# Inspector parameters must reach the shader; they previously stopped in V7.
	var settings: Dictionary = chunk.get_node("Visuals").get_water_settings()
	settings["wave_height"] = 0.073
	settings["foam_distance"] = 1.37
	settings["refraction_strength"] = 0.027
	var material: ShaderMaterial = _builder.make_material(generator.get_planet_profile(), settings)
	for name: String in ["wave_height", "foam_distance", "refraction_strength"]:
		_expect(is_equal_approx(float(material.get_shader_parameter(name)), float(settings[name])), "Ignored water inspector setting " + name)

	horizon.set_process(false)
	var original: Rect2 = manager.shared_water_bounds
	var center := Vector2(chunk.position.x, chunk.position.z)
	manager.set_shared_water_bounds(Rect2(center, Vector2(384, 384)))
	_expect(water.visible and water.material_override.get_shader_parameter("clip_shared_surface"), "Partial overlap must retain and clip the local fallback.")
	manager.set_shared_water_bounds(Rect2(center + Vector2(512, 512), Vector2(384, 384)))
	_expect(water.visible, "Distant shared surface hid unrelated local water.")
	manager.set_shared_water_bounds(original)
	horizon.set_process(true)
	# Travel outside the old mesh before the replacement can complete.
	player.position += Vector3(1024, 0, -1024)
	manager.current_player_chunk = manager._world_position_to_chunk(player.position)
	manager._create_chunk(manager.current_player_chunk)
	var destination: Node3D = manager.loaded_chunks[manager.current_player_chunk]
	_expect(destination.get_node("WaterMesh").visible, "Teleport destination lost water while waiting for the horizon worker.")
	await _wait_for_surface(manager, player)
	_expect(not destination.get_node("WaterMesh").visible, "New destination fallback survived shared-water publication.")
	var reference: WeakRef = weakref(horizon)
	horizon.free()
	_expect(reference.get_ref() == null and not manager.shared_water_bounds.has_area(), "Surface teardown retained ownership.")
	_expect(destination.get_node("WaterMesh").visible and not destination.get_node("WaterMesh").material_override.get_shader_parameter("clip_shared_surface"), "Removing the horizon failed to restore local water.")
	fixture.free()
	await process_frame
	Engine.max_fps = 0

func _wait_for_surface(manager: Node, player: Node3D) -> void:
	for frame in range(2400):
		await process_frame
		if not manager.world_initialized:
			continue
		var horizon: Node = manager.get_node("LandscapeHorizon")
		var point := Vector2(player.position.x, player.position.z)
		var chunk: Node = manager.loaded_chunks.get(manager.current_player_chunk)
		if horizon.generation_complete and (horizon.published_center - point).length() < 100.0 and chunk != null and chunk.generation_complete:
			return
	_failures.append("Timed out waiting for the water surface at the player's current location.")

func _expect(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
