extends SceneTree

const PlanetCatalogV7 = preload(
	"res://world/generation/planet_catalog_v7.gd"
)
const FarMeshJobV7 = preload(
	"res://world/streaming/terrain_far_mesh_job_v7.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_test_layered_chunk_scene()
	_test_far_mesh_job()
	_test_planet_catalog()
	_test_required_resources()
	_finish()


func _test_layered_chunk_scene() -> void:
	var packed_scene := load(
		"res://world/visuals/terrain/terrain_chunk.tscn"
	) as PackedScene
	_expect(packed_scene != null, "Layered terrain chunk scene could not load.")
	if packed_scene == null:
		return
	var chunk := packed_scene.instantiate()
	_expect(chunk != null, "Layered terrain chunk could not instantiate.")
	if chunk == null:
		return
	_expect(
		chunk.get_node_or_null("FarTerrainMesh") != null,
		"Terrain chunk has no FarTerrainMesh."
	)
	_expect(
		chunk.get_node_or_null("ChunkLODControllerV7") != null,
		"Terrain chunk has no V7 LOD controller."
	)
	_expect(
		chunk.get_node_or_null("MicroVoxelSurfaceV6") == null,
		"Floating MicroVoxelSurfaceV6 overlay is still active."
	)
	_expect(
		chunk.has_method("set_lod_tier"),
		"Terrain chunk cannot switch real mesh LOD tiers."
	)
	chunk.free()


func _test_far_mesh_job() -> void:
	var columns: int = 3
	var rows: int = 3
	var local_x := PackedFloat32Array([-1.0, 0.0, 1.0])
	var local_z := PackedFloat32Array([-1.0, 0.0, 1.0])
	var heights := PackedFloat32Array([
		0.0, 0.2, 0.0,
		0.1, 0.4, 0.1,
		0.0, 0.2, 0.0,
	])
	var colors := PackedColorArray()
	for _index in range(columns * rows):
		colors.append(Color(0.25, 0.55, 0.24, 1.0))
	var job := FarMeshJobV7.new({
		"columns": columns,
		"rows": rows,
		"local_x_values": local_x,
		"local_z_values": local_z,
		"heights": heights,
		"colors": colors,
	})
	job.run()
	var result: Dictionary = job.get_result()
	_expect(
		int(result.get("vertex_count", 0)) == columns * rows,
		"Far mesh job produced the wrong vertex count."
	)
	_expect(
		int(result.get("triangle_count", 0)) == 8,
		"Far mesh job produced the wrong triangle count."
	)
	var arrays_value: Variant = result.get("arrays")
	_expect(
		arrays_value is Array and arrays_value.size() == Mesh.ARRAY_MAX,
		"Far mesh job did not return complete mesh arrays."
	)


func _test_planet_catalog() -> void:
	var first: Dictionary = PlanetCatalogV7.create_system(424_242)
	var repeated: Dictionary = PlanetCatalogV7.create_system(424_242)
	_expect(
		str(first.get("system_name", "")) == str(repeated.get("system_name", "")),
		"Same system seed produced a different system name."
	)
	var planet_count: int = PlanetCatalogV7.get_planet_count(first)
	_expect(
		planet_count >= 3 and planet_count <= 6,
		"Planet catalog count is outside the supported range."
	)
	var first_planet: Dictionary = PlanetCatalogV7.get_planet(first, 0)
	var repeated_planet: Dictionary = PlanetCatalogV7.get_planet(repeated, 0)
	_expect(
		int(first_planet.get("planet_seed", 0)) == 424_242,
		"Planet one no longer represents the current world seed."
	)
	_expect(
		first_planet == repeated_planet,
		"Planet catalog is not deterministic."
	)


func _test_required_resources() -> void:
	for path in [
		"res://world/resources/terrain/terrain_chunk_v7.gd",
		"res://world/streaming/terrain_mesh_pool_v7.gd",
		"res://world/streaming/terrain_far_mesh_job_v7.gd",
		"res://world/streaming/chunk_lod_controller_v7.gd",
		"res://world/visuals/terrain/terrain_chunk_visuals_v7.gd",
		"res://world/visuals/terrain/terrain_surface.gdshader",
		"res://world/visuals/terrain/ocean_surface.gdshader",
		"res://world/simulation/region_background_simulation_v7.gd",
		"res://world/fauna/fauna_streamer_v7.gd",
		"res://world/generation/planet_catalog_v7.gd",
		"res://world/space/star_system_runtime_v7.gd",
		"res://main/main.tscn",
	]:
		_expect(load(path) != null, "Layered World V7 resource failed: %s" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Layered World V7 test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
