extends SceneTree

const Cube = preload("res://world/space/cube_sphere.gd")
const System = preload("res://world/space/celestial_system.gd")
const Surface = preload("res://world/surface/living_planet_surface.gd")
const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
const Depth = preload("res://world/surface/visuals/living_water_depth.gd")
const Materials = preload("res://world/surface/visuals/living_surface_materials.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var system := System.new(false, true)
	var count: int = 0
	var max_depth_error: float = 0.0
	var max_phase_error: float = 0.0
	var base_usec: int = 0
	var depth_usec: int = 0
	var water_vertices: int = 0
	for id in System.REAL_LANDABLE:
		var body: Dictionary = system.bodies[id].duplicate(true)
		body.surface_generation = Surface.GENERATION
		var surface := Surface.new(body)
		var layout := Layout.new(body.radius)
		for face in range(6):
			var lowest: Dictionary = {}
			var height: float = INF
			for x in range(-3, 4):
				for y in range(-3, 4):
					var candidate: Dictionary = Cube.address(id, face, x * 0.25, y * 0.25)
					var value: float = surface.sample(candidate).height
					if value < height:
						height = value
						lowest = candidate
			var cells: int = 1 << layout.max_level
			var tile: Dictionary = Layout.patch(face, layout.max_level,
				floori((lowest.u + 1.0) * 0.5 * cells), floori((lowest.v + 1.0) * 0.5 * cells))
			tile.mask = 5 # Exercise stitched edges as well as ordinary vertices.
			tile.anchor = surface.point(face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
			var started: int = Time.get_ticks_usec()
			var original: Dictionary = Patch.build_arrays(tile, surface)
			base_usec += Time.get_ticks_usec() - started
			var enriched: Dictionary = original.duplicate(true)
			started = Time.get_ticks_usec()
			Depth.enrich(enriched, tile)
			depth_usec += Time.get_ticks_usec() - started
			_expect(var_to_bytes(original.land_arrays) == var_to_bytes(enriched.land_arrays), "Presentation changed the physical terrain")
			if not original.water_arrays.is_empty():
				for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX]:
					_expect(original.water_arrays[slot] == enriched.water_arrays[slot], "Water position/topology changed")
				var uv: PackedVector2Array = enriched.water_arrays[Mesh.ARRAY_TEX_UV]
				_expect(uv.size() == original.water_arrays[Mesh.ARRAY_VERTEX].size(), "Missing water depth samples")
				water_vertices += uv.size()
				for index in range(uv.size()):
					if index % 17 == 0 or index < 17 or index > 271 or index % 17 == 16:
						continue # Stitched boundary represents the coarse neighbour.
					var x: int = index % 17
					var y: int = index / 17
					var direction: Array = Cube.direction(face, tile.uv.x + x * tile.width / 16.0, tile.uv.y + y * tile.width / 16.0)
					max_depth_error = maxf(max_depth_error, absf(uv[index].x + surface.height_precise(direction)))
			var old: Array = tile.anchor
			var next: Array = [old[0] + 83.25, old[1] - 77.5, old[2] + 129.125]
			var fixed: Array = [old[0] + 5.25, old[1] + 3.0, old[2] - 8.75]
			var before: Vector3 = Materials.phase_at(old) + Cube.local_position(fixed, old)
			var after: Vector3 = Materials.phase_at(next) + Cube.local_position(fixed, next)
			for axis in range(3):
				max_phase_error = maxf(max_phase_error, absf(wrapf(before[axis] - after[axis], -64.0, 64.0)))
			count += 1
	_expect(water_vertices > 2000 and max_depth_error < 0.001, "Depth no longer follows the actual spherical terrain")
	_expect(max_phase_error < 0.0001, "Ground and water pattern slid during origin shift")
	print("SURFACE_MATERIAL_METRICS ", JSON.stringify({"patches": count, "water_vertices": water_vertices,
		"max_depth_error_m": max_depth_error, "max_pattern_shift_m": max_phase_error,
		"base_mesh_ms": base_usec / 1000.0, "depth_enrichment_ms": depth_usec / 1000.0}))
	for message in failures:
		push_error(message)
	print("SURFACE_MATERIAL_PASSED ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _expect(value: bool, message: String) -> void:
	if not value and message not in failures:
		failures.append(message)
