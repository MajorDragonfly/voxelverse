extends SceneTree

const System = preload("res://world/space/celestial_system.gd")
const Tiles = preload("res://world/planet_lab/adaptive_sphere_tiles.gd")
const Walker = preload("res://world/planet_lab/radial_walker.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var system := System.new(false, true)
	for id: String in System.REAL_LANDABLE:
		await _walk(system.bodies[id])
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)


func _walk(body: Dictionary) -> void:
	var terrain := Tiles.new()
	root.add_child(terrain)
	terrain.configure(body)
	var walker := Walker.new()
	walker.terrain = terrain
	root.add_child(walker)
	var start: Dictionary = {}
	for face in range(6):
		for v in [0.0, 0.2, -0.2, 0.6, -0.6]:
			var candidate: Dictionary = Cube.address(body.id, face, 1.0 - 96.0 / float(body.radius), v)
			var sample: Dictionary = terrain.surface.sample(candidate)
			if sample.height > 3.0 and sample.normal.dot(Cube.vector(Cube.direction(face, candidate.u, candidate.v))) > 0.98:
				candidate.height = sample.height + 1.05
				start = candidate
				break
		if not start.is_empty():
			break
	_expect(not start.is_empty(), "No dry cube-boundary walking fixture: " + body.id)
	if start.is_empty():
		walker.queue_free()
		terrain.queue_free()
		return
	var load_started: int = Time.get_ticks_usec()
	walker.place(start)
	var terrain_ready_ms: float = (Time.get_ticks_usec() - load_started) / 1000.0
	var tangent: Vector3 = (Cube.vector(Cube.direction(start.face, start.u + 0.0001, start.v)) - walker.up_direction).slide(walker.up_direction).normalized()
	walker.orbit_axis = walker.up_direction.cross(tangent).normalized()
	walker.automatic = true
	walker.speed = 24.0
	var contacts: int = 0
	var faces: Dictionary = {}
	var rays: int = 0
	var minimum: float = INF
	var peak_static_bytes: int = 0
	var frame_count: int = 420 if body.id == "m1b:terra" else 240
	for frame in range(frame_count):
		await physics_frame
		var here: Dictionary = walker.location()
		peak_static_bytes = maxi(peak_static_bytes, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		var h: float = terrain.surface.sample(here).height
		minimum = minf(minimum, here.height - h)
		contacts += int(walker.is_on_floor() or walker.swimming)
		faces[here.face] = true
		_expect(here.height > h - 0.25, "Large-world walker fell beneath its actual terrain: " + body.id)
		_expect(terrain.tiles.size() <= 768 and terrain.active.size() <= 24 and terrain.last_build_count <= 2, "Large-world streaming exceeded its bounded budgets.")
		var owner: Dictionary = terrain.layout.find_at(here.face, here.u, here.v, terrain.leaves)
		_expect(not owner.is_empty() and terrain.active.has(owner.id), "Nearest collider selection omitted the player's own tile.")
		_expect(owner.width * body.radius / 16.0 <= 4.0, "Moving player lost metre-scale voxel terrain: %s frame=%d level=%d cell_m=%.3f" % [body.id, frame, owner.level, owner.width * body.radius / 16.0])
		if frame % 30 == 0:
			for id: String in terrain.active:
				var tile: Dictionary = terrain.leaves[id]
				for edge in range(4):
					var adjacent: Dictionary = terrain.layout.neighbor(tile, edge, 0.5, terrain.leaves)
					if adjacent.is_empty() or not terrain.active.has(adjacent.id):
						continue
					var uv: Vector2 = tile.uv + ([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)][edge] as Vector2) * tile.width
					var address: Dictionary = Cube.address(body.id, tile.face, uv.x, uv.y)
					address.height = terrain.surface.sample(address).height
					var point: Vector3 = Cube.local_position(Cube.cartesian(address, body.radius), terrain.origin)
					var up: Vector3 = Cube.vector(Cube.direction(address.face, address.u, address.v))
					var ray := PhysicsRayQueryParameters3D.create(point + up * 3.0, point - up * 3.0, 1, [walker.get_rid()])
					_expect(not terrain.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Physical ray missed %s frame=%d edge=%d tiles=%s,%s" % [body.id, frame, edge, id, adjacent.id])
					rays += 1
	walker.enabled = false
	_expect(contacts > frame_count * 0.95 and faces.size() >= 2 and walker.traveled > 80.0, "Large-body walking did not maintain contact across the cube boundary.")
	_expect(terrain.rebases >= 2 and terrain.updates >= 3 and terrain.peak_resident_meshes <= 1536, "Large-body movement missed origin changes or streaming publication.")
	var metrics: Dictionary = {"body": body.id, "frames": frame_count, "contacts": contacts, "walk_m": walker.traveled, "faces": faces.size(),
		"rebases": terrain.rebases, "publishes": terrain.updates, "rays": rays, "minimum_clearance_m": minimum,
		"peak_tiles": terrain.peak_tiles, "peak_resident_terrain_meshes": terrain.peak_resident_meshes,
		"terrain_ready_ms": terrain_ready_ms, "peak_engine_static_bytes": peak_static_bytes,
		"jobs": terrain.job_samples.duplicate(true),
		"initial_publish_ms": terrain.max_initial_publish_usec / 1000.0, "max_worker_ms": terrain.max_worker_usec / 1000.0,
		"max_upload_ms": terrain.max_build_usec / 1000.0, "max_publish_ms": terrain.max_publish_usec / 1000.0}
	if body.id == "m1b:terra":
		for face in [2, 3]:
			var pole: Dictionary = Cube.address(body.id, face, 0.0, 0.0)
			pole.height = maxf(0.0, terrain.surface.sample(pole).height) + 1.05
			walker.place(pole)
			walker.automatic = false
			walker.enabled = true
			for frame in range(60):
				await physics_frame
			_expect(walker.is_on_floor() or walker.swimming, "Earth pole lost floor contact or buoyancy.")
			walker.enabled = false
	print("LARGE_PLANET_RUNTIME ", JSON.stringify(metrics))
	terrain.stream_at(-walker.up_direction)
	walker.queue_free()
	terrain.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
