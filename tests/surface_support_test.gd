extends SceneTree

const Support = preload("res://world/surface/surface_support.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Profile = preload("res://world/space/celestial_body_profile.gd")
const System = preload("res://world/space/celestial_system.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
const Terrain = preload("res://world/surface/surface_terrain.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")
var failures: Array[String] = []
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	_admission()
	for radius in [Support.MIN_TEST_RADIUS, 512.0, 50000.0, 6371000.0, Support.MAX_RADIUS]:
		await _physical_floor(radius)
	for message in failures: push_error(message)
	print("SURFACE_SUPPORT ", JSON.stringify({"passed": failures.is_empty(), "measurements": measurements, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _admission() -> void:
	for radius in [null, "6371000", NAN, INF, -INF, -1.0, 0.0, 63.99, Support.MAX_RADIUS + 0.25, 1.0e20]:
		_expect(not Support.radius_support(radius).ok, "Invalid or unsupported radius accepted: " + str(radius))
	for radius in [64.0, 512.0, 50000.0, 500000.0, 6371000.0, Support.MAX_RADIUS]:
		_expect(Support.radius_support(radius).ok, "Supported radius rejected: " + str(radius))
	_expect(not Support.radius_support(49999.99, true).ok, "Test body admitted as a campaign")
	var system := System.new(false, true)
	var catalog_before: String = JSON.stringify(system.bodies)
	_expect(Support.inspect(system.bodies["m1:sol"]).code == "catalog_only", "Star admitted as walkable")
	for id in System.REAL_LANDABLE:
		_expect(Support.inspect(system.bodies[id], true).ok, "Existing real-scale body rejected: " + id)
	_expect(JSON.stringify(system.bodies) == catalog_before, "Admission changed catalog data")
	var future: Dictionary = system.bodies["m1b:terra"].duplicate(true)
	future.surface_generation = "living_planet_v99"
	_expect(Support.inspect(future).code == "unsupported_surface_version", "Future generator silently replaced")
	future.surface_generation = "living_planet_v1"
	_expect(Support.inspect(future).ok, "Existing v1 terrain rejected")
	var catalog_system := System.from_catalog({"id": "arch05:catalog", "name": "Admission", "star_count": 1,
		"bodies": {future.id: future.duplicate(true)}})
	catalog_system.bodies[future.id].landable = true
	_expect(catalog_system.landable_ids() == [future.id], "Supported catalog body missing from landing choices")
	catalog_system.bodies[future.id].radius = Support.MAX_RADIUS + 0.25
	var unchanged: String = JSON.stringify(catalog_system.bodies)
	_expect(catalog_system.landable_ids().is_empty(), "Unsupported catalog body offered for landing")
	_expect(JSON.stringify(catalog_system.bodies) == unchanged, "Landing filter changed catalog record")
	var body: Dictionary = {"id": "arch05:body", "seed": 15838, "surface_mode": Cube.MODE,
		"surface_context": {"schema": 1, "mode": Cube.MODE, "generation": Context.GENERATION,
			"terrain_revision": 4, "radius": 6371000.0, "gravity": 9.81,
			"spawn": Cube.address("arch05:body", 0, 0.0, 0.0)}}
	_expect(Context.validate(body).is_empty(), "Existing campaign contract rejected")
	for radius in [Support.MAX_RADIUS + 0.25, 1.0e20]:
		body.surface_context.radius = radius
		var before: String = JSON.stringify(body)
		_expect(Context.unsupported(body), "Unsupported large save did not block fallback")
		_expect(not Context.validate(body).is_empty(), "Unsupported campaign can start")
		_expect(Context.create({"id": "arch05:body", "seed": 15838}, radius).is_empty(), "Unsupported radius generated terrain")
		_expect(JSON.stringify(body) == before, "Rejected save was changed or shrunk")
	# The actual bounded selector must retain a sufficiently fine focus on
	# all faces, including polar centers and cube edges/corners.
	for radius in [512.0, 50000.0, 6371000.0, Support.MAX_RADIUS]:
		var layout := Layout.new(radius)
		for face in range(6):
			for uv in [Vector2.ZERO, Vector2(1.0, 0.3), Vector2(1.0, 1.0)]:
				var place: Dictionary = Cube.address("layout", face, uv.x, uv.y)
				var leaves: Dictionary = layout.choose(Cube.vector(Cube.direction(place.face, place.u, place.v)))
				var owner: Dictionary = layout.find_at(place.face, place.u, place.v, leaves)
				_expect(leaves.size() <= Layout.MAX_LEAVES and not owner.is_empty(), "Bounded layout lost coverage")
				if not owner.is_empty():
					_expect(Support.cell_width(owner.width, radius) <= Support.MAX_GROUND_CELL_METERS, "Leaf budget coarsened the walkable floor")

func _physical_floor(radius: float) -> void:
	var body: Dictionary = Profile.create("arch05:" + str(int(radius)), "moon" if radius < 50000.0 else "planet", 15838, radius)
	body.terrain_revision = 2 if radius < 50000.0 else 4
	if radius >= 50000.0: body.surface_generation = Context.GENERATION
	_expect(Support.inspect(body).ok, "Runtime fixture not admitted")
	var terrain := Terrain.new()
	root.add_child(terrain)
	terrain.configure(body)
	var adapter := Adapter.new(terrain)
	# Nonzero UVs close to the face boundary exposed collapsed float32 cells
	# at the previously allowed 100,000-km upper radius.
	var place: Dictionary = Cube.address(body.id, 0, 0.999997, 0.79)
	place.height = adapter.sample(place).height
	var absolute: Array = Cube.cartesian(place, radius)
	terrain.rebase(absolute)
	_expect(not adapter.collision_ready(place), "Unbuilt floor reported ready")
	_expect(adapter.query(place, "collision").code == "ground_not_ready", "Missing collision did not return a defined result")
	_expect(adapter.query({}, "sample").code == "invalid_address", "Malformed address accepted")
	var foreign: Dictionary = place.duplicate(true)
	foreign.body_id = "foreign"
	_expect(adapter.query(foreign).code == "foreign_body" and not adapter.collision_ready(foreign), "Foreign address read local terrain")
	_expect(adapter.query(place, "tunnel").code == "unsupported_capability", "Missing capability did not return a defined result")
	terrain.stream_at(adapter.up_at(place), true)
	await physics_frame
	await physics_frame
	_expect(adapter.collision_ready(place) and terrain.ground_ready(absolute), "Admitted body failed actual ground readiness: " + str(radius))
	var owner: Dictionary = terrain.layout.find_at(place.face, place.u, place.v, terrain.leaves)
	if owner.is_empty() or not terrain.active.has(owner.id):
		adapter.close()
		terrain.queue_free()
		await process_frame
		return
	var collider: StaticBody3D = terrain.active[owner.id]
	var shape: CollisionShape3D = collider.get_child(0)
	shape.disabled = true
	_expect(not adapter.collision_ready(place), "Disabled collider reported ready")
	shape.disabled = false
	terrain.active.erase(owner.id)
	_expect(not terrain.ground_ready(absolute), "Rendered tile without active owner reported ready")
	terrain.active[owner.id] = collider
	owner.node.remove_child(collider)
	_expect(not adapter.collision_ready(place), "Detached collider reported ready")
	owner.node.add_child(collider)
	for invalid in [[], [0.0, 0.0, 0.0], [NAN, 0.0, 0.0], ["x", 0.0, 0.0]]:
		_expect(not terrain.ground_ready(invalid), "Invalid absolute position accepted")
	await physics_frame
	var rays: int = 0
	# Probe every column center of the real owner mesh, not just a synthetic
	# formula. Missing/degenerate columns must not pass via a coarse neighbor.
	for y in range(Patch.CELLS):
		for x in range(Patch.CELLS):
			var address: Dictionary = Cube.address(body.id, owner.face,
				float(owner.uv.x) + (x + 0.5) * owner.width / Patch.CELLS,
				float(owner.uv.y) + (y + 0.5) * owner.width / Patch.CELLS)
			address.height = adapter.sample(address).height
			var point: Vector3 = adapter.to_local(address)
			var up: Vector3 = adapter.up_at(address)
			var ray := PhysicsRayQueryParameters3D.create(point + up * 6.0, point - up * 6.0, 1)
			var hit: Dictionary = terrain.get_world_3d().direct_space_state.intersect_ray(ray)
			_expect(not hit.is_empty() and hit.get("collider") == collider, "Missing owner column at radius %s, cell %d/%d" % [radius, x, y])
			rays += int(not hit.is_empty() and hit.get("collider") == collider)
	var original: Array = adapter.query(place, "origin").value
	original[0] += 100.0
	_expect(terrain.origin[0] == absolute[0], "Origin query exposed mutable state")
	var node := Node3D.new()
	root.add_child(node)
	adapter.bind("probe", node, place)
	terrain.rebase([absolute[0] + 64.0, absolute[1] - 23.0, absolute[2] + 11.0])
	var restored: Dictionary = adapter.location(node)
	var error: float = Cube.local_position(Cube.cartesian(restored, radius), absolute).length()
	_expect(error < 0.0001 and adapter.collision_ready(restored), "Rebase lost address or collision")
	var sampled: Dictionary = adapter.query(restored).value
	_expect(sampled.has("height") and sampled.has("water") and sampled.has("normal"), "Surface sample missing documented fields")
	_expect((adapter.query(restored, "frame").value as Basis).y.dot(adapter.query(restored, "up").value) > 0.99999, "Frame retained world-Y")
	measurements.append({"radius_m": radius, "level": owner.level, "cell_m": Support.cell_width(owner.width, radius),
		"tiles": terrain.leaves.size(), "colliders": terrain.active.size(), "owner_rays": rays, "rebase_error_m": error})
	print("SURFACE_SUPPORT_BODY ", JSON.stringify(measurements[-1]))
	adapter.unbind("probe")
	node.queue_free()
	adapter.close()
	terrain.queue_free()
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)
