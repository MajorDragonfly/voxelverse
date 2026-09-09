extends SceneTree

const Catalog = preload("res://assets/catalog/asset_catalog.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const TerrainJob = preload("res://world/streaming/terrain_build_job.gd")
const Generator = preload("res://world/generation/world_generator_planetary_v9.gd")
const FAMILIES: Array[String] = ["ancient_oak_v2", "tall_pine_v2", "dense_bush_v2", "fern_cluster_v2", "flower_cluster_v2", "layered_rock_v2", "grass_tuft_v2"]
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_terrain_worker()
	await _test_chunk_instances()
	_test_meshes_and_palettes()
	_test_fauna_weights()
	await _test_cancel_generation()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("Environment production test passed: 63 imported LOD meshes, semantic palettes, worker parity, real staged batches and LOD switching.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if _failures.is_empty() else 1)

func _test_meshes_and_palettes() -> void:
	_expect(FileAccess.file_exists("res://art/source/.gdignore"), "Art sources are not excluded from Godot import.")
	for family: String in FAMILIES:
		var entry: Dictionary = Catalog.get_asset(family)
		_expect(not entry.is_empty(), "Benchmark asset missing: " + family)
		_expect(Catalog.validate_asset_entry(entry, true).is_empty(), "Invalid benchmark manifest: " + family)
		for variant in range(3):
			var previous_triangles: int = 2147483647
			var near_bounds: AABB
			for tier in range(3):
				var mesh: Mesh = Assets.get_mesh(family, tier, variant)
				_expect(mesh != null, "Runtime LOD failed to load: %s/%s/%s" % [family, variant, tier])
				if mesh == null:
					continue
				_expect(mesh.get_surface_count() == 1, "Benchmark does not batch as one surface: " + family)
				var arrays: Array = mesh.surface_get_arrays(0)
				var count: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				_expect(count > 0 and count < previous_triangles, "LOD does not reduce real geometry: " + family)
				previous_triangles = count
				for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
					var index: int = floori(uv.x * Slots.TEXTURE_WIDTH)
					_expect(index >= 0 and index < Slots.NAMES.size(), "Mesh references invalid semantic slot: " + family)
				var bounds: AABB = mesh.get_aabb()
				_expect(bounds.position.y >= -0.001, "Asset pivot is below ground: " + family)
				if tier == 0:
					near_bounds = bounds
				else:
					_expect(bounds.size.y > near_bounds.size.y * 0.70 and bounds.size.y < near_bounds.size.y * 1.30, "LOD changes silhouette height: " + family)
		var near_path: String = entry["lod"]["near"]
		var fallback: Mesh = Assets.resolve_mesh({"lod": {"near": near_path, "mid": "res://assets/missing_optional_mid.glb", "far": ""}}, 2)
		_expect(fallback == Assets.get_mesh(family, 0), "Runtime fallback did not resolve missing Mid/Far to shared Near mesh.")
	var a: Dictionary = Profile.create(7919)
	var b: Dictionary = Profile.create(7919 * 2)
	while b["flora_color_family"] == a["flora_color_family"]:
		b = Profile.create(int(b["planet_seed"]) + 1)
	var sa: Dictionary = Flora.create_species_variant(a, "forest", FAMILIES[0], 0)
	var sb: Dictionary = Flora.create_species_variant(b, "forest", FAMILIES[0], 0)
	var ma: ShaderMaterial = Assets.get_material(a, sa)
	var mb: ShaderMaterial = Assets.get_material(b, sb)
	_expect(ma != mb and ma.shader == mb.shader, "Planet palettes do not share the semantic shader.")
	var ta: ImageTexture = ma.get_shader_parameter("planet_palette")
	var tb: ImageTexture = mb.get_shader_parameter("planet_palette")
	_expect(ta.get_image().get_data() != tb.get_image().get_data(), "Different planets upload identical palettes.")
	for index in range(Slots.NAMES.size()):
		var actual: Color = ta.get_image().get_pixel(index, 0)
		var expected: Color = sa["palette"][Slots.NAMES[index]]
		_expect(Vector3(actual.r - expected.r, actual.g - expected.g, actual.b - expected.b).length() < 0.008, "Uploaded palette slot differs from species recipe.")

func _make_job() -> RefCounted:
	var job := TerrainJob.new()
	job.generator_script = Generator
	job.world_seed = 7919
	job.chunk_origin = Vector2(64, -32)
	job.cell_size = 0.5
	job.cells_x = 16
	job.cells_z = 16
	job.color_sample_stride = 2
	job.far_stride = 5
	return job

func _test_terrain_worker() -> void:
	var reference: RefCounted = _make_job()
	reference.run()
	var threaded: RefCounted = _make_job()
	var task: int = WorkerThreadPool.add_task(threaded.run)
	while not WorkerThreadPool.is_task_completed(task):
		await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	_expect(reference.result == threaded.result, "Worker and synchronous terrain arrays/caches differ.")
	_verify_front_faces(threaded.result["arrays"], "Near terrain")
	_verify_front_faces(threaded.result["far_arrays"], "Far terrain")
	var generator := Generator.new()
	generator.set_seed_override(7919)
	var heights: PackedFloat32Array = threaded.result["heights"]
	for z in range(18):
		for x in range(18):
			var point := Vector2(64, -32) + Vector2((x - 0.5) * 0.5 - 4.0, (z - 0.5) * 0.5 - 4.0)
			_expect(heights[z * 18 + x] == generator.get_visual_terrain_height(point.x, point.y), "Worker height cache differs from active generator sampling.")
	generator.free()

func _verify_front_faces(arrays: Array, label: String) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	var wrong: int = 0
	var targets: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	for offset in range(0, count, 3):
		var a: int = indices[offset] if not indices.is_empty() else offset
		var b: int = indices[offset + 1] if not indices.is_empty() else offset + 1
		var c: int = indices[offset + 2] if not indices.is_empty() else offset + 2
		var has_area: bool = false
		for endpoint in range(1 if targets.is_empty() else 3):
			var va: Vector3 = vertices[a]
			var vb: Vector3 = vertices[b]
			var vc: Vector3 = vertices[c]
			if endpoint > 0:
				va.y = targets[a][endpoint - 1]
				vb.y = targets[b][endpoint - 1]
				vc.y = targets[c][endpoint - 1]
			var cross: Vector3 = (vb - va).cross(vc - va)
			if cross.length_squared() < 0.00000001:
				continue
			has_area = true
			# A riser may start collapsed, but must have outward winding at
			# every non-degenerate endpoint and become a real wall in a LOD.
			if cross.dot(normals[a] + normals[b] + normals[c]) >= 0.0:
				wrong += 1
		if not has_area:
			wrong += 1
	_expect(wrong == 0, "%s has %d inward or permanently degenerate triangles." % [label, wrong])

func _test_chunk_instances() -> void:
	var generator: Node = root.get_node("WorldGenerator")
	generator.call("set_seed_override", 7919)
	var spawn: Vector3 = generator.call("get_scenic_spawn")
	var coords := Vector2i(roundi(spawn.x / 32.0), roundi(spawn.z / 32.0))
	var snapshots: Array[Dictionary] = []
	for repeat in range(2):
		var packed := load("res://world/visuals/terrain/terrain_chunk.tscn") as PackedScene
		var chunk: Node3D = packed.instantiate()
		chunk.set("chunk_coordinates", coords)
		var started: int = Time.get_ticks_usec()
		root.add_child(chunk)
		var create_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		var ecosystem: Node = chunk.get_node("ProceduralEcosystemV6")
		for frame in range(3600):
			if bool(ecosystem.get("generation_complete")):
				break
			await process_frame
		_expect(bool(chunk.get("generation_complete")) and bool(ecosystem.get("generation_complete")), "Chunk terrain or vegetation did not finish.")
		var stats: Dictionary = ecosystem.call("get_generation_stats")
		print("Chunk production metrics ", JSON.stringify({"create_ms": create_ms, "upload_ms": chunk.get("upload_ms"), "ecology": stats}))
		_expect(int(stats["instances"]) > int(stats["nodes"]) * 2, "Vegetation is not meaningfully instanced.")
		_expect(int(stats["nodes"]) <= 21, "Vegetation creates individual node hierarchies.")
		var snapshot: Dictionary = {}
		for node: Node in ecosystem.get_children():
			_expect(node is MultiMeshInstance3D and node.get_child_count() == 0, "Vegetation contains complex per-instance nodes.")
			var mm: MultiMesh = node.multimesh
			# Individual getters are no-ops in Godot's dummy renderer. Inspect the
			# actual bulk buffer used by both real rendering drivers instead.
			var buffer: PackedFloat32Array = mm.buffer
			_expect(buffer.size() == mm.instance_count * 16, "Vegetation uploaded an incomplete instance buffer.")
			snapshot[str(node.name)] = buffer
		snapshots.append(snapshot)
		var first: MultiMeshInstance3D = ecosystem.get_child(0)
		var near: Mesh = first.multimesh.mesh
		ecosystem.call("set_lod_tier", 2)
		_expect(first.multimesh.mesh != near, "Runtime vegetation LOD does not swap meshes.")
		ecosystem.call("set_lod_tier", 0)
		_expect(first.multimesh.mesh == near, "Returning to Near does not reuse its mesh.")
		chunk.call("set_lod_tier", 2)
		# The detailed mesh now morphs before the proxy takes ownership.
		chunk._process(0.7)
		_expect(chunk.get_node("FarTerrainMesh").visible and not chunk.get_node("TerrainMesh").visible, "Terrain Far proxy is not active.")
		var collision: HeightMapShape3D = chunk.get_node("TerrainCollision").shape
		_expect(collision != null and collision.map_data.size() == 65 * 65, "Terrain lost its bounded heightmap collider.")
		var water: ShaderMaterial = chunk.get_node("WaterMesh").material_override
		_verify_front_faces(chunk.get_node("WaterMesh").mesh.surface_get_arrays(0), "Water surface")
		var expected_water: Color = generator.call("get_planet_profile")["material_slots"]["water_deep"]
		expected_water.a = chunk.get_node("Visuals").deep_water_color.a
		_expect(water != null and water.get_shader_parameter("deep_color") == expected_water, "Water is not using the active planet palette and renderer opacity.")
		chunk.queue_free()
		await process_frame
	_expect(snapshots[0] == snapshots[1], "Reloading a chunk changed its vegetation transforms/colors.")

func _test_cancel_generation() -> void:
	var packed := load("res://world/visuals/terrain/terrain_chunk.tscn") as PackedScene
	var chunk: Node3D = packed.instantiate()
	chunk.set("chunk_coordinates", Vector2i(20, -10))
	root.add_child(chunk)
	var ecosystem: Node = chunk.get_node("ProceduralEcosystemV6")
	for frame in range(1800):
		await process_frame
		if ecosystem.get("_placement_job") != null:
			break
	_expect(ecosystem.get("_placement_job") != null, "Cancellation fixture did not reach active staged generation.")
	var random_ref: WeakRef = weakref(ecosystem.get("_placement_job"))
	chunk.free()
	await process_frame
	_expect(random_ref == null or random_ref.get_ref() == null, "Cancelled vegetation generation leaked its placement job.")
	Assets.finish_pending_loads()

func _test_fauna_weights() -> void:
	var script := load("res://world/simulation/region_background_simulation_v7.gd") as Script
	var simulation: Node = script.new()
	root.add_child(simulation)
	var coords := Vector2i(20, -10)
	var entries: Array = simulation.call("get_species_entries", coords)
	var original: Array = entries.duplicate(true)
	var role: String = str(entries[0]["role"])
	if role in ["climber", "scavenger"]:
		role = "forager"
	var weights: Dictionary = {"forager": 0.0, "grazer": 0.0, "predator": 0.0, "swimmer": 0.0}
	weights[role] = 1.0
	for index in range(1, 10):
		var selected: Dictionary = simulation.call("choose_species", coords, index / 10.0, weights)
		var selected_role: String = str(selected["role"])
		if selected_role in ["climber", "scavenger"]:
			selected_role = "forager"
		_expect(selected_role == role, "Biome fauna weights do not affect visible species selection.")
	_expect(simulation.call("get_species_entries", coords) == original, "Visible fauna weighting modified persisted regional populations.")
	simulation.free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
