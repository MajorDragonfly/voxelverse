extends SceneTree

const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
const Tiles = preload("res://world/planet_lab/adaptive_sphere_tiles.gd")
const Walker = preload("res://world/planet_lab/radial_walker.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Surface = preload("res://world/space/planet_surface.gd")
const System = preload("res://world/space/celestial_system.gd")
var failures: Array[String] = []
var measurements: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var body: Dictionary = System.new().bodies["m1:aster"]
	var layout := Layout.new(body.radius)
	var maximum: int = 0
	for face in range(6):
		for uv: Vector2 in [Vector2.ZERO, Vector2(1, 0.3), Vector2(1, 1)]:
			var leaves: Dictionary = layout.choose(Cube.vector(Cube.direction(face, uv.x, uv.y)))
			maximum = maxi(maximum, leaves.size())
			_verify_cover(layout, leaves)
	measurements["maximum_layout_tiles"] = maximum
	_mesh_seams(body, layout)
	await _walk_and_stream(body)
	print("ADAPTIVE_PLANET ", JSON.stringify(measurements))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _verify_cover(layout: RefCounted, leaves: Dictionary) -> void:
	_expect(leaves.size() <= 768 and leaves.size() > 96, "Adaptive tile budget or refinement violated.")
	var areas: Array[float] = [0, 0, 0, 0, 0, 0]
	for tile: Dictionary in leaves.values():
		areas[tile.face] += tile.width * tile.width
		var parent_level: int = tile.level - 1
		while parent_level >= Layout.ROOT_LEVEL:
			var shift: int = tile.level - parent_level
			_expect(not leaves.has(Layout.key(tile.face, parent_level, tile.x >> shift, tile.y >> shift)), "Parent and children render the same surface twice.")
			parent_level -= 1
		for edge in range(4):
			for t in [0.25, 0.75]:
				var neighbor: Dictionary = layout.neighbor(tile, edge, t, leaves)
				_expect(not neighbor.is_empty(), "Missing neighbor at a cube edge or pole.")
				if not neighbor.is_empty():
					_expect(absi(int(tile.level) - int(neighbor.level)) <= 1, "Hierarchy is not balanced across a shared boundary.")
	for area in areas:
		_expect(absf(area - 4.0) < 0.000001, "Adaptive hierarchy does not cover a complete cube face.")


func _mesh_seams(body: Dictionary, layout: RefCounted) -> void:
	var surface := Surface.new(body)
	var leaves: Dictionary = layout.choose(Vector3(1, 0.2, -1).normalized())
	var built: Dictionary = {}
	var maximum_error: float = 0.0
	var maximum_water_error: float = 0.0
	var probes: int = 0
	var cross_face: int = 0
	for tile: Dictionary in leaves.values():
		for edge in range(4):
			var neighbor: Dictionary = layout.neighbor(tile, edge, 0.5, leaves)
			if neighbor.level > tile.level:
				continue
			for entry: Dictionary in [tile, neighbor]:
				if not built.has(entry.id):
					entry["anchor"] = surface.point(entry.face, entry.uv.x + entry.width * 0.5, entry.uv.y + entry.width * 0.5)
					built[entry.id] = Patch.build(entry, surface)
			var vertices: PackedVector3Array = built[tile.id].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var other_vertices: PackedVector3Array = built[neighbor.id].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for step in range(17):
				var t: float = step / 16.0
				var uv: Vector2 = tile.uv + ([Vector2(t, 0), Vector2(1, t), Vector2(t, 1), Vector2(0, t)][edge] as Vector2) * float(tile.width)
				var d: Array = Cube.direction(tile.face, uv.x, uv.y)
				var other_uv: Vector2 = (_project(neighbor.face, d) - neighbor.uv) / float(neighbor.width)
				var expected: Array = Cube.global_position(_edge_vertex(other_vertices, other_uv), neighbor.anchor)
				var actual: Array = Cube.global_position(vertices[Patch.edge_index(edge, step)], tile.anchor)
				maximum_error = maxf(maximum_error, Cube.local_position(actual, expected).length())
				if built[tile.id].water != null and built[neighbor.id].water != null:
					var water: PackedVector3Array = built[tile.id].water.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					var other_water: PackedVector3Array = built[neighbor.id].water.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					actual = Cube.global_position(water[Patch.edge_index(edge, step)], tile.anchor)
					expected = Cube.global_position(_edge_vertex(other_water, other_uv), neighbor.anchor)
					maximum_water_error = maxf(maximum_water_error, Cube.local_position(actual, expected).length())
				probes += 1
				cross_face += int(tile.face != neighbor.face)
	_expect(maximum_error < 0.001, "Actual adaptive mesh seams exceed 1 mm: %.6f m." % maximum_error)
	_expect(maximum_water_error < 0.001, "Adaptive ocean has a gap at a detail boundary.")
	_expect(cross_face > 100 and probes > 1000, "Seam test did not cover actual cube-face boundaries.")
	measurements.merge({"seam_probes": probes, "cross_face_probes": cross_face, "maximum_seam_m": maximum_error, "maximum_water_seam_m": maximum_water_error})


func _edge_vertex(vertices: PackedVector3Array, uv: Vector2) -> Vector3:
	var edge: int
	var t: float
	if absf(uv.x) < 0.0001 or absf(uv.x - 1.0) < 0.0001:
		edge = 3 if uv.x < 0.5 else 1
		t = uv.y * 16.0
	else:
		edge = 0 if uv.y < 0.5 else 2
		t = uv.x * 16.0
	t = clampf(t, 0.0, 16.0)
	var i: int = floori(t)
	return vertices[Patch.edge_index(edge, i)].lerp(vertices[Patch.edge_index(edge, mini(i + 1, 16))], t - i)


func _project(face: int, d: Array) -> Vector2:
	match face:
		0: return Vector2(-d[2] / d[0], d[1] / d[0])
		1: return Vector2(d[2] / -d[0], d[1] / -d[0])
		2: return Vector2(d[0] / d[1], -d[2] / d[1])
		3: return Vector2(d[0] / -d[1], d[2] / -d[1])
		4: return Vector2(d[0] / d[2], d[1] / d[2])
		_: return Vector2(-d[0] / -d[2], d[1] / -d[2])


func _walk_and_stream(body: Dictionary) -> void:
	var terrain := Tiles.new()
	root.add_child(terrain)
	terrain.configure(body)
	var walker := Walker.new()
	walker.terrain = terrain
	root.add_child(walker)
	var start: Dictionary = Cube.address(body.id, 0, 0.975, 0.0)
	start.height = terrain.surface.sample(start).height + 1.05
	walker.place(start)
	walker.automatic = true
	walker.orbit_axis = Vector3.UP
	walker.speed = 24.0
	var contacts: int = 0
	var faces: Dictionary = {}
	var max_clearance: float = 0.0
	var probes: int = 0
	for frame in range(600):
		await physics_frame
		var here: Dictionary = walker.location()
		var height: float = terrain.surface.sample(here).height
		faces[here.face] = true
		contacts += int(walker.is_on_floor() or walker.swimming)
		max_clearance = maxf(max_clearance, float(here.height) - maxf(height, 0.0))
		_expect(float(here.height) > height - 0.25, "Walking crossed below the physical planet surface.")
		_expect(terrain.active.size() <= 24 and terrain.tiles.size() <= 768, "Streaming exceeded its live terrain/collision budget.")
		_expect(terrain.last_build_count <= 2, "Steady streaming built too many patches in one frame.")
		if frame % 60 == 0:
			for id: String in terrain.active:
				var tile: Dictionary = terrain.leaves[id]
				for edge in range(4):
					var neighbor: Dictionary = terrain.layout.neighbor(tile, edge, 0.5, terrain.leaves)
					if neighbor.is_empty() or not terrain.active.has(neighbor.id):
						continue
					var uv: Vector2 = tile.uv + ([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)][edge] as Vector2) * float(tile.width)
					var address: Dictionary = Cube.address(body.id, tile.face, uv.x, uv.y)
					address.height = terrain.surface.sample(address).height
					var point: Vector3 = Cube.local_position(Cube.cartesian(address, body.radius), terrain.origin)
					var up: Vector3 = Cube.vector(Cube.direction(address.face, address.u, address.v))
					var ray := PhysicsRayQueryParameters3D.create(point + up * 3.0, point - up * 3.0, 1, [walker.get_rid()])
					_expect(not terrain.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Physics ray missed a streamed patch edge.")
					probes += 1
	walker.enabled = false
	_expect(contacts > 550 and faces.size() >= 2 and terrain.rebases >= 3, "Walk did not exercise a cube-face crossing with continuous ground contact and origin changes.")
	_expect(terrain.updates > 3, "Adaptive runtime never refined/retired moving terrain.")
	_expect(terrain.peak_resident_meshes <= 1536, "Prepared plus visible meshes grew without bound.")
	terrain.upload_samples.sort()
	var p95: float = terrain.upload_samples[mini(terrain.upload_samples.size() - 1, floori(terrain.upload_samples.size() * 0.95))] if not terrain.upload_samples.is_empty() else 0.0
	measurements.merge({"walk_m": walker.traveled, "contacts": contacts, "cube_faces": faces.size(), "rebases": terrain.rebases,
		"physics_edge_rays": probes, "peak_tiles": terrain.peak_tiles, "peak_resident_terrain_meshes": terrain.peak_resident_meshes,
		"publishes": terrain.updates, "maximum_mesh_upload_ms": terrain.max_build_usec / 1000.0,
		"p95_mesh_upload_ms": p95, "maximum_initial_publish_ms": terrain.max_initial_publish_usec / 1000.0,
		"maximum_publish_ms": terrain.max_publish_usec / 1000.0, "maximum_worker_ms": terrain.max_worker_usec / 1000.0, "maximum_clearance_m": max_clearance})
	# Teardown must also join a newly queued background task.
	terrain.stream_at(-walker.up_direction)
	walker.queue_free()
	terrain.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
