extends SceneTree

const Transition = preload("res://world/streaming/terrain_transition.gd")
const TerrainJob = preload("res://world/streaming/terrain_build_job.gd")
const Generator = preload("res://world/generation/world_generator_planetary_v9.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var generator: Node = Generator.new()
	generator.set_seed_override(15838)
	var meshes: Array[Dictionary] = []
	for origin: Vector2 in [Vector2(-32, -32), Vector2(0, -32)]:
		var job := TerrainJob.new()
		job.generator_script = Generator
		job.world_seed = 15838
		job.chunk_origin = origin
		job.cell_size = 0.5
		job.cells_x = 64
		job.cells_z = 64
		job.color_sample_stride = 2
		job.run()
		_verify_columns(job.result["arrays"], origin, generator, false)
		_verify_columns(job.result["far_arrays"], origin, generator, true)
		meshes.append({"arrays": job.result["arrays"], "origin": origin})
	# At a nested block edge the two tops intentionally have different heights.
	# Actual riser triangles must close that gap, including at negative coords.
	var walls: int = 0
	for z in range(64):
		var point := Vector2(-16.0, -48.0 + (z + 0.5) * 0.5)
		for endpoint in range(3):
			var a: float = _endpoint(generator, point - Vector2(0.25, 0), endpoint)
			var b: float = _endpoint(generator, point + Vector2(0.25, 0), endpoint)
			if absf(a - b) < 0.001:
				continue
			walls += 1
			var covered: bool = false
			for entry in meshes:
				covered = covered or _wall_covers(entry["arrays"], entry["origin"], point, endpoint, minf(a,b), maxf(a,b))
			_expect(covered, "A shared negative-coordinate block boundary has an open riser at endpoint %d." % endpoint)
	_expect(walls > 20, "Boundary acceptance did not exercise enough real vertical block faces.")
	generator.free()
	await _runtime_transition()
	for failure: String in _failures.slice(0, 12):
		push_error(failure)
	print("Terrain transition: horizontal block tops, vertical risers, closed negative-coordinate LOD boundaries, gradual handoff, reversal and collision preservation.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if _failures.is_empty() else 1)

func _endpoint(generator: Node, point: Vector2, endpoint: int) -> float:
	if endpoint == 0:
		return generator.get_visual_terrain_height(point.x, point.y)
	return Transition.height_at(generator, point, Transition.HORIZON_STEP if endpoint == 1 else Transition.PROXY_STEP, {})

func _level(vertices: PackedVector3Array, targets: PackedVector2Array, index: int, endpoint: int) -> float:
	return vertices[index].y if endpoint == 0 else targets[index][endpoint - 1]

func _verify_columns(arrays: Array, origin: Vector2, generator: Node, proxy: bool) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var targets: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	_expect(vertices.size() == targets.size(), "Terrain vertices lack a morph endpoint.")
	var tops: int = 0
	for i in range(0, vertices.size(), 4):
		_expect(absf(normals[i].x) + absf(normals[i].y) + absf(normals[i].z) == 1.0, "A distant face has a smooth sloping normal.")
		if normals[i] != Vector3.UP:
			continue
		tops += 1
		var center: Vector3 = (vertices[i] + vertices[i + 2]) * 0.5
		var point: Vector2 = origin + Vector2(center.x, center.z)
		for endpoint in range(3):
			var expected: float = _endpoint(generator, point, 2 if proxy and endpoint == 0 else endpoint)
			for corner in range(4):
				_expect(is_equal_approx(_level(vertices, targets, i + corner, endpoint), expected), "A block top slopes or samples the wrong LOD column.")
	_expect(tops == (1024 if proxy else 4096), "Terrain changed its fixed column count.")
	if proxy:
		_expect(vertices.size() <= 20480, "Voxel proxy exceeds five indexed quads per column.")

func _wall_covers(arrays: Array, origin: Vector2, point: Vector2, endpoint: int, low: float, high: float) -> bool:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var targets: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for i in range(0, vertices.size(), 4):
		if absf(normals[i].x) < 0.99 or not is_equal_approx(origin.x + vertices[i].x, point.x):
			continue
		var a: float = origin.y + vertices[i].z
		var b: float = origin.y + vertices[i + 2].z
		if point.y <= minf(a,b) or point.y >= maxf(a,b):
			continue
		if _level(vertices, targets, i, endpoint) <= low + 0.001 and _level(vertices, targets, i + 1, endpoint) >= high - 0.001:
			return true
	return false

func _runtime_transition() -> void:
	var chunk: Node3D = load("res://world/visuals/terrain/terrain_chunk.tscn").instantiate()
	chunk.threaded_generation = false
	chunk.get_node("ProceduralEcosystemV6").process_mode = Node.PROCESS_MODE_DISABLED
	chunk.get_node("ChunkLODControllerV7").process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(chunk)
	await process_frame
	chunk.set_process(false)
	var collider: Shape3D = chunk.get_node("TerrainCollision").shape
	chunk.set_lod_tier(2)
	chunk._process(0.2)
	_expect(chunk.get_node("TerrainMesh").visible and not chunk.get_node("FarTerrainMesh").visible, "Far mesh appeared before the geometry transition completed.")
	_expect(chunk._terrain_lod_blend > 0.0 and chunk._terrain_lod_blend < 1.0, "LOD transition still switches in one frame.")
	chunk._process(0.65)
	_expect(not chunk.get_node("TerrainMesh").visible and chunk.get_node("FarTerrainMesh").visible, "Completed transition did not release the detailed mesh.")
	chunk.set_lod_tier(0)
	chunk._process(0.2)
	_expect(chunk.get_node("TerrainMesh").visible and chunk._terrain_lod_blend > 0.0, "Reverse LOD transition is not continuous.")
	chunk.terrain_presence = 1.0
	chunk.terrain_retiring = true
	chunk._process(0.2)
	_expect(chunk.terrain_presence > 0.0 and chunk.terrain_presence < 1.0, "Unloading drops coverage abruptly.")
	chunk.terrain_retiring = false
	var before: float = chunk.terrain_presence
	chunk._process(0.1)
	_expect(chunk.terrain_presence > before and chunk.terrain_presence < 1.0, "Re-entering a retiring chunk resets its transition.")
	_expect(chunk.get_node("TerrainCollision").shape == collider and not chunk.get_node("TerrainCollision").disabled, "Visual LOD changed the playable collision surface.")
	chunk.free()
	await process_frame

func _expect(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
