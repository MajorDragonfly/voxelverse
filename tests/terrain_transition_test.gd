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
	var edge_samples: Dictionary = {}
	var comparisons: int = 0
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
		var arrays: Array = job.result["arrays"]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var targets: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		_expect(vertices.size() == targets.size(), "Terrain vertices lack a transition endpoint.")
		var horizon_cache: Dictionary = {}
		var proxy_cache: Dictionary = {}
		for i in range(vertices.size()):
			var point: Vector2 = origin + Vector2(vertices[i].x, vertices[i].z)
			if point.x == -16.0:
				if edge_samples.has(point):
					_expect(targets[i].is_equal_approx(edge_samples[point]), "Adjacent chunks disagree on a shared transition edge.")
					comparisons += 1
				else:
					edge_samples[point] = targets[i]
			if i % 127 == 0:
				_expect(absf(targets[i].x - Transition.height_at(generator, point, 8.0, horizon_cache)) < 0.0001, "Near terrain does not collapse onto the horizon triangles.")
				_expect(absf(targets[i].y - Transition.height_at(generator, point, 2.0, proxy_cache)) < 0.0001, "LOD morph endpoint differs from the proxy surface.")
		var far: Array = job.result["far_arrays"]
		var far_vertices: PackedVector3Array = far[Mesh.ARRAY_VERTEX]
		_expect(far_vertices.size() == 289, "Proxy exceeds its nested grid budget.")
		for vertex: Vector3 in far_vertices:
			var point: Vector2 = origin + Vector2(vertex.x, vertex.z)
			_expect(is_equal_approx(vertex.y, generator.get_visual_terrain_height(point.x, point.y)), "Proxy corner still samples an offset column centre.")
	_expect(comparisons > 60, "Shared-edge acceptance did not exercise an entire negative-coordinate chunk boundary.")
	generator.free()
	await _runtime_transition()
	for failure: String in _failures.slice(0, 12):
		push_error(failure)
	print("Terrain transition: shared world-grid endpoints, negative chunk boundaries, delayed LOD handoff, reversal, retirement and collision preservation.")
	quit(0 if _failures.is_empty() else 1)

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
