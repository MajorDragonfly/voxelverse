extends SceneTree

const Drainage = preload("res://world/generation/drainage_network.gd")
const Generator = preload("res://world/generation/world_generator_planetary_v9.gd")
const Surface = preload("res://world/streaming/world_water_mesh_job.gd")
var _failures: Array[String] = []

class WaterChunk extends Node3D:
	var chunk_coordinates := Vector2i.ZERO
	func get_chunk_width() -> float:
		return 32.0
	func get_chunk_depth() -> float:
		return 32.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var generator: Node = Generator.new()
	var repeated: Node = Generator.new()
	var lakes: Array[float] = []
	var routes: int = 0
	var mouths: int = 0
	var crossings: int = 0
	var review: Array[Dictionary] = []
	for seed_value: int in [15838, 23757, 424242]:
		generator.set_seed_override(seed_value)
		repeated.set_seed_override(seed_value)
		for z in range(-2, 2):
			for x in range(-2, 2):
				var route: Dictionary = generator.get_drainage_region(Vector2i(x, z))
				if route.is_empty():
					continue
				routes += 1
				var previous: float = INF
				var previous_chunk := Vector2i.ZERO
				for i in range(161):
					var point: Vector2 = Drainage.center_at(route, i / 160.0)
					var water: float = generator.get_water_level(point.x, point.y)
					var height: float = generator.get_terrain_height(point.x, point.y)
					_expect(water <= previous + 0.015, "River flows uphill in seed %d / %s." % [seed_value, route["cell"]])
					_expect(water - height >= 1.0, "River loses its connected submerged bed.")
					_expect(generator.is_water_at(point.x, point.y), "Game interactions cannot recognize river water.")
					var chunk := Vector2i(floori((point.x + 16.0) / 32.0), floori((point.y + 16.0) / 32.0))
					crossings += int(i > 0 and chunk != previous_chunk)
					previous_chunk = chunk
					previous = water
					if i % 40 == 0:
						_expect(is_equal_approx(height, repeated.get_terrain_height(point.x, point.y)), "Worker/query ordering changes the carved bed.")
				for lake: Dictionary in route["lakes"]:
					lakes.append(float(lake["level"]))
					var center: Vector2 = lake["center"]
					for offset: Vector2 in [Vector2.ZERO, Vector2(5, 0), Vector2(-5, 3), Vector2(0, -8)]:
						var point: Vector2 = center + offset
						_expect(absf(generator.get_water_level(point.x, point.y) - float(lake["level"])) < 0.001, "Lake water is not level.")
						_expect(generator.get_biome_key(point.x, point.y) == "lake", "Elevated lake was classified as dry land.")
					if review.size() < 6:
						review.append({"seed": seed_value, "source": str(route["source"]), "lake": str(center), "level": lake["level"], "length": route["length"]})
				if route["outlet"] == "ocean":
					mouths += 1
					_expect(is_equal_approx(previous, generator.get_sea_level()), "River mouth does not meet the ocean surface.")
		var spawn: Vector3 = generator.get_scenic_spawn()
		_expect(generator.get_terrain_height(spawn.x, spawn.z) > generator.get_water_level(spawn.x, spawn.z) + 0.7, "Scenic spawn is flooded.")
		# Region boundaries include negative coordinates; independent catchments
		# must fade back to unmodified terrain before reaching their border.
		for point: Vector2 in [Vector2(-384, -90), Vector2(0, 50), Vector2(384, -410)]:
			_expect(generator.get_water_info(point.x, point.y).is_empty(), "Drainage crosses an unrelated region's boundary.")
			_expect(generator.get_terrain_height(point.x, point.y) == generator.get_base_terrain_height(point.x, point.y), "Region border cuts the original terrain.")
	_expect(routes >= 12 and crossings >= 60, "Drainage acceptance did not exercise enough routes and chunk crossings.")
	_expect(lakes.size() >= 3 and mouths > 0, "Acceptance must cover both inland lakes and coastal outlets.")
	if not lakes.is_empty():
		_expect(lakes.max() - lakes.min() > 1.0, "All receiving lakes use the same water level.")
	await _check_drinking(generator)
	_check_water_meshes()
	generator.free()
	repeated.free()
	print("Drainage acceptance ", JSON.stringify({"routes": routes, "lakes": lakes.size(), "mouths": mouths, "chunk_crossings": crossings, "review": review}))
	for failure: String in _failures.slice(0, 12):
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _check_drinking(generator: Node) -> void:
	var active: Node = root.get_node("WorldGenerator")
	active.set_seed_override(15838)
	generator.set_seed_override(15838)
	var point := Vector2.ZERO
	var found: bool = false
	for z in range(-2, 2):
		for x in range(-2, 2):
			var route: Dictionary = generator.get_drainage_region(Vector2i(x, z))
			if not route.is_empty() and not route["lakes"].is_empty():
				point = route["lakes"][0]["center"]
				found = true
				break
		if found:
			break
	if not found:
		_failures.append("No inland drinking fixture.")
		return
	var fixture := Node3D.new()
	root.add_child(fixture)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 1, 8)
	collision.shape = box
	body.add_child(collision)
	fixture.add_child(body)
	body.position = Vector3(point.x, active.get_terrain_height(point.x, point.y) - 0.5, point.y)
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	fixture.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.position = body.position + Vector3(0, 3, 0)
	var ray: RayCast3D = player.get_node("CameraPivot/SpringArm3D/Camera3D/InteractionRay")
	ray.top_level = true
	ray.global_transform = Transform3D(Basis.IDENTITY, player.position)
	ray.target_position = Vector3(0, -5, 0)
	player.current_thirst = 20.0
	await physics_frame
	await physics_frame
	player._try_primary_action()
	_expect(player.current_thirst > 20.0, "Actual interaction ray failed to drink from an elevated lake.")
	fixture.free()
	await process_frame

func _check_water_meshes() -> void:
	var generator: Node = root.get_node("WorldGenerator")
	generator.set_seed_override(15838)
	# Find an actual elevated river crossing a possible 64 m horizon edge.
	# Put the old surface there, as can happen during a long teleport.
	var crossing := Vector2(INF, INF)
	for z in range(-2, 2):
		for x in range(-2, 2):
			var route: Dictionary = generator.get_drainage_region(Vector2i(x, z))
			if route.is_empty():
				continue
			for i in range(81):
				var point: Vector2 = Drainage.center_at(route, i / 80.0)
				var border: float = snappedf(point.x, 64.0)
				if absf(border - point.x) < 3.0 and generator.get_water_level(border, point.y) > generator.get_sea_level() + 1.0:
					crossing = Vector2(border, snappedf(point.y, 32.0))
					break
			if crossing.is_finite():
				break
		if crossing.is_finite():
			break
	if not crossing.is_finite():
		_failures.append("No elevated river crosses a horizon recenter edge.")
		return
	var center := Vector2(crossing.x - 384.0, snappedf(crossing.y, 64.0))
	var arrays: Array = Surface.build(generator, center, 384.0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var edge: Dictionary = {}
	for vertex: Vector3 in vertices:
		if vertex.x == crossing.x:
			edge[vertex.z] = vertex.y
	var chunk := WaterChunk.new()
	chunk.chunk_coordinates = Vector2i(roundi(crossing.x / 32.0), roundi(crossing.y / 32.0))
	chunk.position = Vector3(crossing.x, 0, crossing.y)
	var water := MeshInstance3D.new()
	water.name = "WaterMesh"
	chunk.add_child(water)
	root.add_child(chunk)
	var builder: Script = load("res://world/visuals/terrain/water_mesh_builder_v7.gd")
	var reference: Node = load("res://world/visuals/terrain/terrain_chunk.tscn").instantiate()
	var settings: Dictionary = reference.get_node("Visuals").get_water_settings()
	reference.free()
	settings["subdivisions"] = 20
	builder.build(chunk, water, settings)
	builder.set_shared_coverage(chunk, Rect2(center - Vector2.ONE * 384.0, Vector2.ONE * 768.0))
	_expect(water.visible and bool(water.material_override.get_shader_parameter("join_shared_surface")), "Partial inland-water fallback lost its shared edge.")
	var local: Array = water.mesh.surface_get_arrays(0)
	var local_vertices: PackedVector3Array = local[Mesh.ARRAY_VERTEX]
	var targets: PackedVector2Array = local[Mesh.ARRAY_TEX_UV2]
	var checked: int = 0
	var highest: float = -INF
	for i in range(local_vertices.size()):
		if local_vertices[i].x != 0.0:
			continue
		var z: float = chunk.position.z + local_vertices[i].z
		var lower: float = floorf(z / 2.0) * 2.0
		var actual: float = lerpf(float(edge[lower]), float(edge[lower + 2.0]), (z - lower) / 2.0)
		highest = maxf(highest, actual)
		_expect(absf(targets[i].x + water.position.y - actual) < 0.0001, "Fallback edge misses the actual coarse shared-water mesh.")
		checked += 1
	_expect(checked == 33, "Fallback subdivisions do not form a nested water grid.")
	_expect(highest > generator.get_sea_level() + 1.0, "Shared-edge fixture did not exercise elevated water.")
	chunk.free()

func _expect(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
