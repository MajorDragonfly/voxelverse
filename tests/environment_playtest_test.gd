extends SceneTree

const Obstacles = preload("res://world/visuals/scenery/environment_obstacles.gd")
const Budget = preload("res://world/streaming/environment_generation_budget.gd")
const HorizonJob = preload("res://world/streaming/landscape_horizon_job.gd")
const Generator = preload("res://world/generation/world_generator_planetary_v9.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _collision_checks()
	await _streaming_checks()
	for failure in _failures:
		push_error(failure)
	print("Playtest regression checks: compound obstacle physics, four travel directions, horizon coverage and cancellation.")
	quit(0 if _failures.is_empty() else 1)

func _collision_checks() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var obstacle := Obstacles.new()
	fixture.add_child(obstacle)
	var families: Array[String] = ["ancient_oak_v2", "tall_pine_v2", "dense_bush_v2", "layered_rock_v2"]
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.0
	collider.shape = capsule
	body.add_child(collider)
	fixture.add_child(body)
	for family: String in families:
		for variant in range(3):
			var index: int = obstacle.shape_count
			var origin := Vector3(index * 10.0, 80.0, 0.0)
			obstacle.add_batch({"asset_id": family, "species": {"geometry_variant": variant},
				"transforms": [Transform3D(Basis(Vector3.UP, 0.23).scaled(Vector3(1.15, 0.95, 1.15)), origin)]})
			await physics_frame
			await process_frame
			var ray := PhysicsRayQueryParameters3D.create(origin + Vector3(0, 0.5, 4), origin + Vector3(0, 0.5, -4), 1)
			var hit: Dictionary = obstacle.get_world_3d().direct_space_state.intersect_ray(ray)
			_expect(hit.get("collider") == obstacle, "Ray passed through %s variant %d." % [family, variant])
			body.position = origin + Vector3(0, 0.55, 4)
			var motion: KinematicCollision3D = body.move_and_collide(Vector3(0, 0, -8))
			_expect(motion != null and motion.get_collider() == obstacle, "Character motion passed through %s variant %d." % [family, variant])
	_expect(obstacle.get_child_count() == 0 and obstacle.shape_count == 12, "Colliders created per-instance nodes or lost variants.")
	var reference: WeakRef = weakref(obstacle)
	fixture.free()
	await physics_frame
	_expect(reference.get_ref() == null, "Unloaded obstacle body survived chunk teardown.")

func _streaming_checks() -> void:
	Engine.max_fps = 120
	var generator: Node = root.get_node("WorldGenerator")
	generator.set_seed_override(15838)
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := CharacterBody3D.new()
	player.name = "Player"
	fixture.add_child(player)
	player.add_to_group(&"player")
	player.set_physics_process(false)
	var scenic: Vector3 = generator.get_scenic_spawn()
	# Start on a chunk center, making the four directional lead measurements comparable.
	player.position = Vector3(snappedf(scenic.x, 32.0), 100.0, snappedf(scenic.z, 32.0))
	var start: Vector3 = player.position
	var manager: Node = load("res://world/world_manager.tscn").instantiate()
	manager.choose_scenic_spawn_for_default_start = false
	fixture.add_child(manager)
	for frame in range(2400):
		await process_frame
		if manager.world_initialized and _inner_complete(manager):
			break
	_expect(manager.world_initialized and _inner_complete(manager), "Initial collision neighbourhood did not populate.")
	var measurements: Array[Dictionary] = []
	for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		player.position = start
		player.velocity = Vector3(direction.x * 6.0, 0.0, direction.y * 6.0)
		var origin: Vector2i = manager._world_position_to_chunk(start)
		var target: Vector2i = origin + direction * 2
		manager.refresh_streaming()
		var lead: float = -INF
		var start_time: int = Time.get_ticks_usec()
		var previous: int = start_time
		while Time.get_ticks_usec() - start_time < 9_000_000:
			await process_frame
			var now: int = Time.get_ticks_usec()
			var delta: float = minf((now - previous) / 1_000_000.0, 0.05)
			previous = now
			player.position += player.velocity * delta
			if manager.loaded_chunks.has(target):
				var chunk: Node = manager.loaded_chunks[target]
				if chunk.get_node("ProceduralEcosystemV6").generation_complete:
					lead = 48.0 - Vector2(player.position.x - start.x, player.position.z - start.z).length()
					break
		_expect(lead > 8.0, "Vegetation loaded too late in direction %s (lead %.2f m)." % [direction, lead])
		measurements.append({"direction": [direction.x, direction.y], "lead_metres": lead, "seconds": (Time.get_ticks_usec() - start_time) / 1_000_000.0})
		# Force the LOD controller to use horizontal distance on elevated terrain.
		var current: Node = manager.loaded_chunks.get(origin)
		if current != null:
			var lod: Node = current.get_node("ChunkLODControllerV7")
			lod._update_lod()
			_expect(lod._current_tier == 0, "Altitude incorrectly pushed the player's own chunk to Far LOD.")
	player.velocity = Vector3.ZERO
	var horizon: Node = manager.get_node("LandscapeHorizon")
	for frame in range(2400):
		await process_frame
		if horizon.generation_complete:
			break
	_expect(horizon.generation_complete, "Distant landscape did not publish actual runtime meshes.")
	if horizon.generation_complete:
		var mesh: Mesh = horizon.get_node("DistantLand").mesh
		_expect(mesh.get_aabb().size.x >= 768.0 and mesh.get_aabb().size.z >= 768.0, "Distant landscape does not extend beyond active chunks.")
		_expect(mesh.get_aabb().size.y > 15.0, "Distant terrain lost its mountain silhouette.")
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var slopes: int = 0
		var tops: int = 0
		for i in range(0, vertices.size(), 4):
			# ArrayMesh packs normals; allow its octahedral decoding error.
			if normals[i].y > 0.999:
				tops += 1
				for corner in range(1, 4):
					slopes += int(vertices[i].y != vertices[i + corner].y)
			else:
				slopes += int(absf(absf(normals[i].x) + absf(normals[i].z) - 1.0) > 0.001 or absf(normals[i].y) > 0.001)
		_expect(slopes == 0 and tops == 384 * 384, "Actual distant mountain mesh must contain the refined 2 m block columns.")
		_expect(vertices.size() <= 384 * 384 * 20, "Distant voxel terrain exceeds its fixed five-quad column budget.")
		print("Distant voxel geometry ", JSON.stringify({"columns": tops, "vertices": vertices.size(), "triangles": (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3}))
		horizon._update_coverage()
		# The dummy renderer ignores ImageTexture.update(). Count the exact upload
		# payload here; actual Vulkan/GL captures exercise the sampled mask.
		var covered: int = 0
		for index in range(1, horizon._coverage_bytes.size(), 3):
			covered += int(horizon._coverage_bytes[index] > 0)
		var ready_chunks: int = 0
		for chunk: Node in manager.loaded_chunks.values():
			ready_chunks += int(chunk.generation_complete)
		_expect(covered == ready_chunks, "Horizon fails to mask ready terrain chunks.")
	print("Directional streaming measurements ", JSON.stringify(measurements))
	var horizon_ref: WeakRef = weakref(horizon)
	fixture.free()
	await process_frame
	_expect(horizon_ref.get_ref() == null and Budget._placement_jobs == 0, "World teardown leaked horizon or CPU placement workers.")
	_expect(Budget.peak_placement_jobs <= 2, "Unbounded environment CPU concurrency.")
	Engine.max_fps = 0

func _inner_complete(manager: Node) -> bool:
	for z in range(-1, 2):
		for x in range(-1, 2):
			var key: Vector2i = manager.current_player_chunk + Vector2i(x, z)
			if not manager.loaded_chunks.has(key) or not manager.loaded_chunks[key].get_node("ProceduralEcosystemV6").generation_complete:
				return false
	return true

func _expect(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
