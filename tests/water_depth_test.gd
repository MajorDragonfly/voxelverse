extends SceneTree

const Generator = preload("res://world/generation/world_generator_planetary_v9.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var generator: Node = Generator.new()
	var measurements: Array[Dictionary] = []
	for seed_value in [15838, 23757, 424242]:
		generator.set_seed_override(seed_value)
		var deep_samples: int = 0
		var maximum_depth: float = 0.0
		for z in range(-16, 17):
			for x in range(-16, 17):
				var point := Vector2(x * 24.0, z * 24.0)
				var depth: float = generator.get_water_level(point.x, point.y) - generator.get_terrain_height(point.x, point.y)
				deep_samples += int(depth > 10.0)
				maximum_depth = maxf(maximum_depth, depth)
		_expect(deep_samples >= 12 and maximum_depth > 15.0, "Actual generated oceans remain wading-depth on seed %d." % seed_value)
		var lake_count: int = 0
		var lake_minimum: float = INF
		for z in range(-2, 2):
			for x in range(-2, 2):
				var route: Dictionary = generator.get_drainage_region(Vector2i(x, z))
				for lake: Dictionary in route.get("lakes", []):
					var point: Vector2 = lake["center"]
					var depth: float = generator.get_water_level(point.x, point.y) - generator.get_terrain_height(point.x, point.y)
					lake_minimum = minf(lake_minimum, depth)
					lake_count += 1
		_expect(lake_count > 0 and lake_minimum >= 5.4, "Generated spring lakes still have shallow flat beds.")
		measurements.append({"seed": seed_value, "deep_ocean_samples": deep_samples, "maximum_depth_m": maximum_depth, "lakes": lake_count, "minimum_lake_depth_m": lake_minimum})
	generator.free()
	await _swimming_and_collision()
	print("Water depth acceptance ", JSON.stringify(measurements))
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _swimming_and_collision() -> void:
	var generator: Node = root.get_node("WorldGenerator")
	generator.set_seed_override(15838)
	var point := Vector2(103.2928, -526.2283)
	var level: float = generator.get_water_level(point.x, point.y)
	var fixture := Node3D.new()
	root.add_child(fixture)
	var chunk: Node3D = load("res://world/visuals/terrain/terrain_chunk.tscn").instantiate()
	chunk.chunk_coordinates = Vector2i(roundi(point.x / 32.0), roundi(point.y / 32.0))
	chunk.threaded_generation = false
	chunk.get_node("ProceduralEcosystemV6").process_mode = Node.PROCESS_MODE_DISABLED
	chunk.get_node("ChunkLODControllerV7").process_mode = Node.PROCESS_MODE_DISABLED
	fixture.add_child(chunk)
	await physics_frame
	var ray := RayCast3D.new()
	ray.position = Vector3(point.x, level + 1.0, point.y)
	ray.target_position = Vector3(0, -20, 0)
	ray.collision_mask = 1
	fixture.add_child(ray)
	await physics_frame
	ray.force_raycast_update()
	_expect(ray.is_colliding() and level - ray.get_collision_point().y > 5.0, "The rendered deep basin still has a shallow physical floor.")
	var player: CharacterBody3D = load("res://creatures/player/player.tscn").instantiate()
	fixture.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.position = Vector3(point.x, level - 1.4, point.y)
	player.velocity = Vector3(0, -2, 0)
	for frame in range(150):
		await physics_frame
		player._physics_process(1.0 / 60.0)
	_expect(player.is_swimming and absf(player.position.y - (level - 0.65)) < 0.15, "Creature sinks to the deep bed instead of floating at local lake level.")
	_expect(absf(player.velocity.y) < 0.25, "Buoyancy does not settle.")
	player.current_thirst = 20.0
	player._try_primary_action()
	_expect(player.current_thirst > 20.0, "Swimming creature cannot drink when the bed is out of ray reach.")
	var dry: Vector3 = generator.get_scenic_spawn()
	player.position = dry
	player._update_water_movement(1.0 / 60.0)
	_expect(not player.is_swimming and player.floor_snap_length > 0.0, "Leaving water does not restore walking and step snapping.")
	fixture.free()
	await process_frame

func _expect(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
