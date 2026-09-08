extends SceneTree

const Cube = preload("res://world/space/cube_sphere.gd")
const Body = preload("res://world/space/celestial_body_profile.gd")
const Surface = preload("res://world/space/planet_surface.gd")
const Adapter = preload("res://world/space/legacy_surface_adapter.gd")
const System = preload("res://world/space/celestial_system.gd")
const Catalog = preload("res://world/generation/planet_catalog_v7.gd")
const Tiles = preload("res://world/planet_lab/sphere_tiles.gd")
const Save = preload("res://world/planet_lab/planet_lab_save.gd")
var failures: Array[String] = []
var max_precision_error: float = 0.0
var max_seam_error: float = 0.0
var max_far_height_error: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	_coordinates()
	_catalog()
	_surface_edges()
	_system_clock()
	_persistence()
	await process_frame
	if failures.is_empty():
		print("M1 contracts passed; maximum Earth-radius local error %.9f m; mesh seam error %.9f m." % [max_precision_error, max_seam_error])
		print("M1 far LOD maximum triangle-centroid height error: %.6f m." % max_far_height_error)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _coordinates() -> void:
	for radius in [64.0, 256.0, 6_371_000.0]:
		for face in range(6):
			for u in [-1.0, -0.321, 0.0, 0.814, 1.0]:
				for v in [-1.0, -0.72, 0.0, 0.12, 1.0]:
					var a: Dictionary = Cube.address("test", face, u, v, 23.12345)
					var p: Array = Cube.cartesian(a, radius)
					var b: Dictionary = Cube.from_cartesian("test", p, radius)
					_expect(Cube.local_position(Cube.cartesian(b, radius), p).length() < 0.001, "Global round trip failed.")
					var offset := Vector3(91.1234, -71.2468, 28.1234)
					var shifted: Array = Cube.global_position(offset, p)
					var c: Dictionary = Cube.from_cartesian("test", shifted, radius)
					var error: float = Cube.local_position(Cube.cartesian(c, radius), p).distance_to(offset)
					max_precision_error = maxf(max_precision_error, error)
					_expect(error < 0.001, "Floating-origin precision exceeded 1 mm.")
					var up: Vector3 = Cube.vector(Cube.direction(face, u, v))
					var frame: Basis = Cube.frame(up)
					_expect(absf(frame.determinant() - 1.0) < 0.00001 and frame.y.dot(up) > 0.99999, "Invalid tangent frame at pole/edge.")
	_expect(not Cube.valid({}), "Empty address accepted.")
	var invalid: Dictionary = Cube.address("test", 0, 0.0, 0.0)
	invalid.u = NAN
	_expect(not Cube.valid(invalid), "NaN address accepted.")
	invalid.u = 0.0
	invalid.face = 1.5
	_expect(not Cube.valid(invalid), "Fractional face accepted.")


func _catalog() -> void:
	var state := root.get_node("GameState")
	var generator := root.get_node("WorldGenerator")
	# Captured with the unmodified catalog at 58a6f3c, including oversized seeds.
	var golden: Dictionary = {
		12345: [12345, 1907754563, 274953348, 1965483359, 1060851193],
		15838: [15838, 2029482161, 1276690650, 968826276, 2067082427],
		2147483647: [2147483647, 3375647829, 3194119570, 2652912358, 4307332122]}
	for seed_value in [12345, 15838, 2_147_483_647]:
		var catalog: Dictionary = Catalog.create_system(seed_value)
		var actual: Array = []
		for planet: Dictionary in catalog.planets:
			actual.append(planet.planet_seed)
		_expect(actual == golden[seed_value], "Legacy catalog seed mapping changed.")
		for planet: Dictionary in catalog.planets:
			state.activate_planet(seed_value, planet.index, planet.planet_seed)
			_expect(state.get_world_seed() == planet.effective_seed, "Catalog changed effective world seed.")
			_expect(planet.profile == generator.get_planet_profile(), "Catalog/live V9 profile mismatch.")
			_expect(planet.body_profile.surface_mode == "legacy_plane_v9", "Legacy planet migrated implicitly.")
	var adapter := Adapter.new(generator, "legacy-test")
	var location: Dictionary = {"mode": "legacy_plane_v9", "body_id": "legacy-test", "position": [11.5, 0.0, -8.0]}
	var value: Dictionary = adapter.sample(location)
	_expect(value.height == generator.get_terrain_height(11.5, -8.0), "Legacy adapter changed terrain.")
	_expect(value.water_level == generator.get_water_level(11.5, -8.0), "Legacy adapter changed water.")


func _surface_edges() -> void:
	var system := System.new()
	var surface := Surface.new(system.bodies["m1:haven"])
	var seen: Dictionary = {}
	# Every perimeter point is generated independently through both incident faces.
	for face in range(6):
		for edge in range(4):
			for step in range(65):
				var t: float = -1.0 + step / 32.0
				var uv: Vector2 = [Vector2(-1, t), Vector2(1, t), Vector2(t, -1), Vector2(t, 1)][edge]
				var d: Vector3 = Cube.vector(Cube.direction(face, uv.x, uv.y))
				var key: String = "%.7f,%.7f,%.7f" % [d.x, d.y, d.z]
				var sample: Dictionary = surface.sample_direction(d)
				if seen.has(key):
					_expect(sample == seen[key], "Height/water/normal/climate disagree across cube faces.")
				seen[key] = sample
	var tiles := Tiles.new()
	tiles.configure(system.bodies["m1:haven"])
	var perimeter: Dictionary = {}
	for tile: Dictionary in tiles.tiles:
		var far_vertices: PackedVector3Array = tile.far.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var far_indices: PackedInt32Array = tile.far.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		for triangle in range(0, far_indices.size(), 3):
			var centroid: Vector3 = (far_vertices[far_indices[triangle]] + far_vertices[far_indices[triangle + 1]] + far_vertices[far_indices[triangle + 2]]) / 3.0
			var p: Vector3 = Cube.vector(Cube.global_position(centroid, tile.anchor))
			var error: float = absf(p.length() - 256.0 - surface.height_at(p.normalized()))
			max_far_height_error = maxf(max_far_height_error, error)
		var near_mesh: ArrayMesh = tiles.build_mesh(tile, true)
		var near_vertices: PackedVector3Array = near_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for perimeter_index in range(64):
			var edge: int = perimeter_index / 16
			var t: float = float(perimeter_index % 16) / 16.0
			var xy: Vector2 = [Vector2(t, 0), Vector2(1, t), Vector2(1 - t, 1), Vector2(0, 1 - t)][edge]
			var vertex: Vector3 = near_vertices[roundi(xy.x * 16) + roundi(xy.y * 16) * 17]
			var closest: float = INF
			for far_vertex in far_vertices:
				closest = minf(closest, far_vertex.distance_to(vertex))
			_expect(closest < 0.001, "Far/near perimeter disagrees.")
			var global: Array = Cube.global_position(vertex, tile.anchor)
			var d: Vector3 = Cube.vector(Cube.direction(tile.face, -1.0 + (tile.x + xy.x) * 0.5, -1.0 + (tile.y + xy.y) * 0.5))
			var key := Vector3i((d * 1_000_000.0).round())
			if perimeter.has(key):
				max_seam_error = maxf(max_seam_error, Cube.local_position(global, perimeter[key].point).length())
				perimeter[key].count += 1
			else:
				perimeter[key] = {"count": 1, "point": global}
	for entry: Dictionary in perimeter.values():
		_expect(entry.count >= 2, "Mesh perimeter has an unmatched edge vertex.")
	_expect(max_seam_error < 0.001, "Mesh seam exceeds 1 mm.")
	_expect(max_far_height_error <= 2.0, "Orbit terrain height error %.6f m exceeds 2 m at triangle centroids." % max_far_height_error)
	tiles.free()


func _system_clock() -> void:
	for binary in [false, true]:
		var system := System.new(binary)
		_expect(system.bodies.size() == (5 if binary else 4), "System fixture body count changed.")
		for t in range(0, 240, 5):
			system.elapsed = float(t)
			var here: Vector3 = Vector3.RIGHT * 256.0
			for id: String in system.bodies:
				if id == "m1:haven":
					continue
				var observer: Vector3 = system.position_at("m1:haven") + system.rotation_at("m1:haven") * here
				var expected: Vector3 = (system.position_at(id) - observer).normalized()
				var actual: Vector3 = system.rotation_at("m1:haven") * system.sky_direction("m1:haven", id, here)
				_expect(expected.distance_to(actual) < 0.00001, "Sky and system positions differ.")
			for id: String in system.bodies:
				for other: String in system.bodies:
					if id != other:
						_expect(system.position_at(id).distance_to(system.position_at(other)) > system.bodies[id].radius + system.bodies[other].radius, "Celestial bodies overlap.")
		var dawn: float = system.sky_direction("m1:haven", "m1:sol").dot(Vector3.RIGHT)
		system.elapsed += 120.0
		var dusk: float = system.sky_direction("m1:haven", "m1:sol").dot(Vector3.RIGHT)
		_expect(dawn * dusk < 0.0, "Rotation does not produce day and night.")


func _persistence() -> void:
	var path: String = "user://m1_contract_save.json"
	var data: Dictionary = {"schema": 1, "surface_version": Cube.MODE, "body_id": "m1:haven",
		"location": Cube.address("m1:haven", 2, 0.5, -1.0, 3.0), "forward": [0.0, 0.0, -1.0], "elapsed": 237.125, "binary": true}
	_expect(Save.write(data, path) == OK, "M1 save failed.")
	var loaded: Dictionary = Save.read(path)
	_expect(loaded.body_id == data.body_id and loaded.elapsed == data.elapsed and loaded.binary == data.binary,
		"Save round trip changed system state.")
	_expect(Cube.local_position(Cube.cartesian(loaded.location, 256.0), Cube.cartesian(data.location, 256.0)).length() < 0.02,
		"Save round trip changed location.")
	_expect(Cube.vector(loaded.forward).distance_to(Cube.vector(data.forward)) < 0.00001, "Save changed orientation.")
	data.elapsed += 1.0
	_expect(Save.write(data, path) == OK, "Second M1 save failed.")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	_expect(Save.read(path).elapsed == 237.125, "Atomic backup not recovered.")
	data.schema = 99
	_expect(Save.write(data, path) == ERR_INVALID_DATA, "Unknown save version overwritten.")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_expect(Save.read(path).is_empty(), "Newer save silently replaced by an older backup.")
	data.schema = 1
	_expect(Save.write(data, path) == ERR_UNAVAILABLE, "Existing newer save was overwritten.")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
