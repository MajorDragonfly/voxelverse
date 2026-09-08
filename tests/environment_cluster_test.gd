extends SceneTree

const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var generator: Node = root.get_node("WorldGenerator")
	generator.call("set_seed_override", 15838)
	var spawn: Vector3 = generator.call("get_scenic_spawn")
	var scenes: Array[Node3D] = []
	for repeat in range(2):
		var chunk: Node3D = load("res://world/visuals/terrain/terrain_chunk.tscn").instantiate()
		var width: float = float(chunk.call("get_chunk_width"))
		chunk.set("chunk_coordinates", Vector2i(roundi(spawn.x / width), roundi(spawn.z / width)))
		root.add_child(chunk)
		scenes.append(chunk)
	for frame in range(6000):
		await process_frame
		if scenes.all(func(chunk: Node): return bool(chunk.get_node("ProceduralEcosystemV6").get("generation_complete"))):
			break
	for chunk: Node in scenes:
		var ecology: Node = chunk.get_node("ProceduralEcosystemV6")
		_expect(bool(ecology.get("generation_complete")), "Base vegetation never completed.")
		_expect(int(ecology.call("get_generation_stats")["cluster_nodes"]) == 0, "Near vegetation eagerly allocated a cluster.")
		ecology.call("set_lod_tier", 2)
	var previous_nodes: int = 0
	for frame in range(6000):
		await process_frame
		var count: int = 0
		var complete: bool = true
		for chunk: Node in scenes:
			var stats: Dictionary = chunk.get_node("ProceduralEcosystemV6").call("get_generation_stats")
			count += int(stats["cluster_nodes"])
			complete = complete and bool(stats["cluster_complete"])
		_expect(count - previous_nodes <= 1, "Multiple cluster meshes uploaded in the same frame.")
		previous_nodes = count
		if complete:
			break
	var snapshots: Array[Dictionary] = []
	for chunk: Node in scenes:
		var ecology: Node = chunk.get_node("ProceduralEcosystemV6")
		var stats: Dictionary = ecology.call("get_generation_stats")
		print("Environment cluster metrics ", JSON.stringify(stats))
		_expect(bool(stats["cluster_ready"]), "Dense fixture unexpectedly fell back or never finished.")
		_expect(int(stats["cluster_nodes"]) == 2 and int(stats["visible_batches"]) == 2, "Far does not replace the original batches with two clusters.")
		_expect(int(stats["nodes"]) <= 23, "Clusters created individual plant hierarchies.")
		var snapshot: Dictionary = {}
		for group: String in ["trees", "low"]:
			var node := ecology.get_node_or_null("FarCluster_" + group) as MeshInstance3D
			if node == null:
				continue
			_expect(node.mesh.get_surface_count() == 1, "Cluster has multiple material surfaces.")
			_expect(node.custom_aabb.encloses(node.mesh.get_aabb()), "Cluster culling bounds omit geometry.")
			var arrays: Array = node.mesh.surface_get_arrays(0)
			var texture: Texture2D = node.material_override.get_shader_parameter("planet_palette")
			snapshot[group] = [arrays, texture.get_image().get_data()]
			_verify_payload(ecology, group, arrays, texture.get_image())
		snapshots.append(snapshot)
		ecology.call("set_lod_tier", 0)
		_expect(int(ecology.call("get_generation_stats")["visible_batches"]) == int(stats["batches"]), "Returning Near did not restore every original batch.")
		ecology.call("set_lod_tier", 2)
		_expect(int(ecology.call("get_generation_stats")["visible_batches"]) == 2 and not ecology.is_processing(), "Cached Far clusters were rebuilt or not restored.")
	_expect(snapshots[0] == snapshots[1], "Same seed/placement produced different cluster geometry or palette rows.")
	for chunk: Node in scenes:
		chunk.free()
	scenes.clear()
	await process_frame
	await _test_capacity_fallback(generator)
	await _test_cancel_builder(generator)
	Assets.finish_pending_loads()
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("Environment cluster test passed: exact transformed Far geometry, semantic atlas, deterministic clusters, shared upload budget, fallback and cancellation.")
	quit(0 if _failures.is_empty() else 1)


func _verify_payload(ecology: Node, group: String, arrays: Array, atlas: Image) -> void:
	var batches: Array[Dictionary] = []
	for batch: Dictionary in ecology.get("_batches").values():
		if batch["asset_id"] in ["fern_cluster_v2", "flower_cluster_v2", "grass_tuft_v2"]:
			continue
		if ("trees" if bool(batch["tree"]) else "low") == group:
			batches.append(batch)
	_expect(atlas.get_height() == batches.size(), "Atlas row count differs from species count.")
	var offset: int = 0
	var expected_indices: int = 0
	for row in range(batches.size()):
		var batch: Dictionary = batches[row]
		var mesh: Mesh = Assets.get_mesh(batch["asset_id"], 2, int(batch["species"]["geometry_variant"]))
		var source: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		for instance_index in range(batch["transforms"].size()):
			var transform: Transform3D = batch["transforms"][instance_index]
			for index in [0, vertices.size() / 2, vertices.size() - 1]:
				var actual: Vector3 = arrays[Mesh.ARRAY_VERTEX][offset + index]
				_expect(actual.is_equal_approx(transform * vertices[index]), "Cluster changed the authored silhouette or placement.")
				var expected_normal: Vector3 = (transform.basis.inverse().transposed() * source[Mesh.ARRAY_NORMAL][index]).normalized()
				_expect((arrays[Mesh.ARRAY_NORMAL][offset + index] as Vector3).distance_to(expected_normal) < 0.0001, "Cluster normals ignore nonuniform individual scale.")
				var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][offset + index]
				_expect(is_equal_approx(uv.x, source[Mesh.ARRAY_TEX_UV][index].x) and floori(uv.y * batches.size()) == row, "Cluster changed semantic slots or species rows.")
				_expect(is_equal_approx(arrays[Mesh.ARRAY_TEX_UV2][offset + index].x, batch["custom"][instance_index].r), "Cluster lost individual shade.")
			for slot in range(Slots.NAMES.size()):
				var expected: Color = batch["species"]["palette"][Slots.NAMES[slot]]
				var actual: Color = atlas.get_pixel(slot, row)
				_expect(Vector3(actual.r - expected.r, actual.g - expected.g, actual.b - expected.b).length() < 0.008, "Cluster atlas lost the species palette.")
			offset += vertices.size()
			expected_indices += source[Mesh.ARRAY_INDEX].size()
	_expect(arrays[Mesh.ARRAY_VERTEX].size() == offset and arrays[Mesh.ARRAY_INDEX].size() == expected_indices, "Cluster omitted or duplicated Far geometry.")


func _new_fixture(generator: Node) -> Node3D:
	var spawn: Vector3 = generator.call("get_scenic_spawn")
	var chunk: Node3D = load("res://world/visuals/terrain/terrain_chunk.tscn").instantiate()
	var width: float = float(chunk.call("get_chunk_width"))
	chunk.set("chunk_coordinates", Vector2i(roundi(spawn.x / width), roundi(spawn.z / width)))
	root.add_child(chunk)
	for frame in range(6000):
		await process_frame
		if bool(chunk.get_node("ProceduralEcosystemV6").get("generation_complete")):
			break
	return chunk


func _test_capacity_fallback(generator: Node) -> void:
	var chunk: Node3D = await _new_fixture(generator)
	var ecology: Node = chunk.get_node("ProceduralEcosystemV6")
	ecology.set("cluster_vertex_limit", 0)
	ecology.call("set_lod_tier", 2)
	for frame in range(200):
		await process_frame
		if bool(ecology.call("get_generation_stats")["cluster_complete"]):
			break
	var stats: Dictionary = ecology.call("get_generation_stats")
	_expect(int(stats["cluster_nodes"]) == 0 and stats["cluster_fallbacks"].size() == 2, "Capacity guard did not retain the fallback path.")
	_expect(int(stats["visible_batches"]) > 2, "Capacity fallback hid the original Far vegetation.")
	chunk.free()
	await process_frame


func _test_cancel_builder(generator: Node) -> void:
	var chunk: Node3D = await _new_fixture(generator)
	var ecology: Node = chunk.get_node("ProceduralEcosystemV6")
	ecology.call("set_lod_tier", 2)
	await process_frame
	var builders: Dictionary = ecology.get("_cluster_builders")
	_expect(not builders.is_empty(), "Cancellation fixture never reached active cluster work.")
	var reference: WeakRef = weakref(builders.values()[0]) if not builders.is_empty() else null
	builders = {}
	chunk.free()
	await process_frame
	_expect(reference == null or reference.get_ref() == null, "Unloading a chunk retained its in-progress cluster arrays.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
