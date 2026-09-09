extends SceneTree

const System = preload("res://world/space/celestial_system.gd")
const Tiles = preload("res://world/planet_lab/adaptive_sphere_tiles.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var body: Dictionary = System.new(false, true).bodies["m1b:100"]
	var terrain := Tiles.new()
	root.add_child(terrain)
	terrain.configure(body)
	terrain.set_process(false)
	var start: Vector3 = Cube.vector(Cube.direction(0, 0.3, 0.2))
	terrain.rebase([start.x * body.radius, start.y * body.radius, start.z * body.radius])
	terrain.stream_at(start, true)
	var target: Vector3 = Cube.vector(Cube.direction(0, 0.3 + 96.0 / body.radius, 0.2))
	terrain.stream_at(target)
	var rebased: bool = false
	var began: int = Time.get_ticks_msec()
	while terrain._retired.is_empty() and Time.get_ticks_msec() - began < 20000:
		terrain._process(0.0)
		_expect(terrain.last_build_count <= 2 and terrain.peak_resident_meshes <= 1536, "Streaming exceeded frame or resident budgets.")
		if not rebased and terrain._pending.size() > 4:
			var next_origin: Array = terrain.origin.duplicate()
			next_origin[0] += 180.25
			terrain.rebase(next_origin)
			for tile: Dictionary in terrain._staging.values():
				if tile.has("node"):
					_expect(tile.node.position.distance_to(Cube.local_position(tile.anchor, next_origin)) < 0.0001, "Hidden staged geometry did not follow an origin change.")
			rebased = true
		await process_frame
	_expect(rebased and not terrain._retired.is_empty() and not terrain._arriving.is_empty(), "The moving terrain never prepared and published a transition.")
	if not terrain._retired.is_empty():
		for tile: Dictionary in terrain._retired:
			for child: Node in tile.node.get_children():
				_expect(not child is StaticBody3D, "Retired visual geometry kept active physics.")
		terrain._process(Tiles.TRANSITION_SECONDS * 0.5)
		_expect(is_equal_approx(terrain._fade_land.get_shader_parameter("lod_phase"), 0.5) and is_equal_approx(terrain._old_water.get_shader_parameter("lod_phase"), 0.5), "Land and water did not share the transition phase.")
		terrain._process(Tiles.TRANSITION_SECONDS)
		_expect(terrain._retired.is_empty() and terrain._arriving.is_empty(), "Completed transition retained old scene nodes.")
	var hits_before: int = terrain.cache_hits
	for u in [0.3 - 180.0 / body.radius, 0.3 + 96.0 / body.radius, 0.3]:
		terrain.stream_at(Cube.vector(Cube.direction(0, u, 0.2)), true)
		_expect(terrain._cache.size() <= 256 and terrain.peak_resident_meshes <= 1536 and terrain.active.size() == 24, "Backtracking retained unbounded meshes or colliders.")
		await process_frame
	_expect(terrain.cache_hits > hits_before, "Backtracking never reused an evicted mesh variant.")
	var checked: int = 0
	for tile: Dictionary in terrain.leaves.values():
		if tile.level < terrain.layout.max_level - 1:
			continue
		var rebuilt: Dictionary = Patch.build_arrays(tile, terrain.surface)
		var actual: PackedVector3Array = tile.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var expected: PackedVector3Array = rebuilt.land_arrays[Mesh.ARRAY_VERTEX]
		_expect(actual == expected, "Reused mesh differs from a fresh tile with the same body, address and seam mask.")
		checked += 1
		if checked == 3:
			break
	_expect(checked == 3, "Cache comparison lacked fine voxel geometry.")
	print("PLANET_STREAMING ", JSON.stringify({"cache_hits": terrain.cache_hits, "peak_resident_meshes": terrain.peak_resident_meshes, "max_prepare_ms": terrain.max_prepare_usec / 1000.0, "max_publish_ms": terrain.max_publish_usec / 1000.0}))
	terrain.stream_at(-start)
	terrain.queue_free()
	await process_frame
	await process_frame
	for message in failures:
		push_error(message)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
