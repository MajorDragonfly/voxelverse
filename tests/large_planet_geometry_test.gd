extends "res://tests/adaptive_planet_test.gd"


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var system := System.new(false, true)
	var bodies: Array = []
	for id: String in System.REAL_LANDABLE:
		var body: Dictionary = system.bodies[id]
		var layout := Layout.new(body.radius)
		var maximum: int = 0
		for face in range(6):
			for uv in [Vector2.ZERO, Vector2(1, 0.3), Vector2(1, 1), Vector2(0.35421, -0.74651)]:
				var d: Vector3 = Cube.vector(Cube.direction(face, uv.x, uv.y))
				var leaves: Dictionary = layout.choose(d)
				_verify_cover(layout, leaves)
				var focus: Dictionary = layout.find_at(face, uv.x, uv.y, leaves)
				_expect(focus.level == layout.max_level, "Large body silently lost its required ground resolution: " + id)
				_expect(focus.width * body.radius <= 32.01, "Large-body focus patch exceeds 32 m in cube space.")
				maximum = maxi(maximum, leaves.size())
		measurements = {"body": id, "diameter_m": body.radius * 2.0, "level": layout.max_level, "maximum_tiles": maximum}
		_large_seams(body, layout)
		_precise_surface(body)
		bodies.append(measurements.duplicate(true))
		print("LARGE_PLANET_GEOMETRY ", JSON.stringify(measurements))
	for message in failures:
		push_error(message)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _large_seams(body: Dictionary, layout: RefCounted) -> void:
	var surface := Surface.new(body)
	var focus: Array = Cube.direction(0, 1.0, 0.2)
	var observer: Array = surface.point(0, 1.0, 0.2)
	var leaves: Dictionary = layout.choose(Cube.vector(focus))
	var built: Dictionary = {}
	for tile: Dictionary in leaves.values():
		tile["anchor"] = surface.point(tile.face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
		built[tile.id] = Patch.build_arrays(tile, surface)
	var near_error: float = 0.0
	var distant_error: float = 0.0
	var pixel_error: float = 0.0
	var near_probes: int = 0
	var cross_probes: int = 0
	var water_probes: int = 0
	for tile: Dictionary in leaves.values():
		if tile.width * body.radius / 16.0 <= 8.0:
			_check_columns(Patch.upload(built[tile.id]).mesh, tile, body)
		for edge in range(4):
			var neighbor: Dictionary = layout.neighbor(tile, edge, 0.5, leaves)
			if neighbor.level > tile.level:
				continue
			for step in range(17):
				var uv: Vector2 = tile.uv + ([Vector2(step / 16.0, 0), Vector2(1, step / 16.0), Vector2(step / 16.0, 1), Vector2(0, step / 16.0)][edge] as Vector2) * tile.width
				var d: Array = Cube.direction(tile.face, uv.x, uv.y)
				var other_uv: Vector2 = (_project(neighbor.face, d) - neighbor.uv) / float(neighbor.width)
				for kind in ["land_arrays", "water_arrays"]:
					if built[tile.id][kind].is_empty() or built[neighbor.id][kind].is_empty():
						continue
					var points: PackedVector3Array = built[tile.id][kind][Mesh.ARRAY_VERTEX]
					var other: PackedVector3Array = built[neighbor.id][kind][Mesh.ARRAY_VERTEX]
					var actual: Array = Cube.global_position(points[Patch.edge_index(edge, step)], tile.anchor)
					var expected: Array = Cube.global_position(_edge_vertex(other, other_uv), neighbor.anchor)
					var error: float = Cube.local_position(actual, expected).length()
					var distance: float = Cube.local_position(actual, observer).length()
					distant_error = maxf(distant_error, error)
					# Fixed 720px / 70-degree reference projection. Far float meshes
					# are tested in pixels; the actual walking region retains 1 mm.
					pixel_error = maxf(pixel_error, error * 514.133 / maxf(distance, 3.0))
					if distance < 256.0:
						near_error = maxf(near_error, error)
						near_probes += 1
					cross_probes += int(tile.face != neighbor.face)
					water_probes += int(kind == "water_arrays")
	_expect(near_error < 0.001 and near_probes > 100, "Large-body nearby drawn seams exceed 1 mm or were not exercised.")
	_expect(pixel_error < 0.05, "Far terrain/water seams exceed 0.05 reference pixels.")
	_expect(cross_probes > 100 and water_probes > 100, "Large-body mesh checks missed water or cube boundaries.")
	measurements.merge({"near_seam_m": near_error, "maximum_world_seam_m": distant_error, "maximum_reference_pixel_seam": pixel_error,
		"near_probes": near_probes, "cross_face_probes": cross_probes, "water_probes": water_probes})


func _precise_surface(body: Dictionary) -> void:
	var surface := Surface.new(body)
	var worst: float = 0.0
	for face in range(6):
		var address: Dictionary = Cube.address(body.id, face, 0.31, -0.47)
		address.height = surface.sample(address).height
		var p: Array = Cube.cartesian(address, body.radius)
		var up: Vector3 = Cube.vector(Cube.direction(face, address.u, address.v))
		var tangent: Vector3 = Cube.frame(up).x
		var previous: float = address.height
		for step in range(1, 11):
			var shifted: Array = Cube.global_position(tangent * step * 0.01, p)
			var here: Dictionary = Cube.from_cartesian(body.id, shifted, body.radius)
			var value: Dictionary = surface.sample(here)
			worst = maxf(worst, absf(value.height - previous))
			_expect(value.normal.is_finite() and value.normal.dot(up) > 0.9, "Precision loss corrupted the large-body ground normal.")
			previous = value.height
	_expect(worst < 0.01, "Centimetre motion causes discontinuous large-world height jumps.")
	measurements["max_height_change_per_cm_m"] = worst
