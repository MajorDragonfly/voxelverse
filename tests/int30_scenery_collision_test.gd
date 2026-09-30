extends SceneTree
## Real physics sweeps against authored trunk centres, not collider-derived points.
const Obstacles = preload("res://world/visuals/scenery/environment_obstacles.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const PROBES: Dictionary = {
	"ancient_oak_v2": [[Vector3(0, 0.3, 0), Vector3(0.4, 4.6, 0.05)],
		[Vector3(0, 0.3, 0), Vector3(0.28, 2.55, 0.08)],
		[Vector3(0, 0.3, 0), Vector3(0.3, 3.8, 0.08)]],
	"tall_pine_v2": [[Vector3(0, 0.3, 0), Vector3(0.04, 6, 0.04)],
		[Vector3(0, 0.3, 0), Vector3(0, 6, 0.08)],
		[Vector3(0.04, 0.3, 0), Vector3(0.78, 4, 0.06)]],
	"dense_bush_v2": [[Vector3(0, 0.35, 0)], [Vector3(0, 0.35, 0)], [Vector3(0, 0.35, 0)]],
	"layered_rock_v2": [[Vector3(0, 0.6, 0)], [Vector3(0, 1, 0)], [Vector3(0, 0.6, 0)]]}
var failures: Array[String] = []
var rows: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var fixture := Node3D.new()
	root.add_child(fixture)
	var actor := CharacterBody3D.new()
	actor.collision_layer = 8
	actor.collision_mask = 2
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.08
	capsule.height = 0.18
	collider.shape = capsule
	actor.add_child(collider)
	fixture.add_child(actor)
	for asset: String in PROBES:
		for variant in range(3):
			var mesh: Mesh = Assets.get_mesh(asset, 0, variant)
			for point: Vector3 in PROBES[asset][variant]:
				if "oak" in asset or "pine" in asset:
					_expect(_has_visible_bark(mesh, point), "Fixture point is not inside authored bark: %s/%d %s" % [asset, variant, point])
			for size in [0.8, 1.0, 1.2]:
				for up in [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, Vector3(1, 1, 1).normalized()]:
					var frame: Basis = Cube.frame(up).rotated(up, 0.37)
					var transform := Transform3D(frame.scaled_local(Vector3.ONE * size), Vector3(0, 80, 0))
					var body := Obstacles.new()
					body.collision_layer = 2
					fixture.add_child(body)
					body.add_batch({"asset_id": asset, "species": {"geometry_variant": variant}, "transforms": [transform]})
					await physics_frame
					await process_frame
					for point: Vector3 in PROBES[asset][variant]:
						var centre: Vector3 = transform * point
						for axis: Vector3 in [frame.x, frame.z]:
							var ray := PhysicsRayQueryParameters3D.create(centre + axis * 3, centre - axis * 3, 2)
							var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
							var label: String = "%s/%d size %.1f up %s point %s axis %s" % [asset, variant, size, up, point, axis]
							_expect(hit.get("collider") == body, "Missing radial collision: " + label)
							actor.global_transform = Transform3D(frame, centre + axis * 3)
							var motion: KinematicCollision3D = actor.move_and_collide(-axis * 6)
							_expect(motion != null and motion.get_collider() == body, "Motion passed through bark/core: " + label)
					_expect(body.shape_count == 1 and body.get_shape_owners().size() == 1 and body.get_child_count() == 0,
						"One plant must remain one compound shape without voxel nodes")
					# Leaf crown/off-core clearance must stay traversable.
					if "oak" in asset or "pine" in asset:
						var clear: Vector3 = transform * Vector3(2, 1.5, 0)
						var query := PhysicsRayQueryParameters3D.create(clear + frame.z, clear - frame.z, 2)
						_expect(body.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Trunk hull blocks empty off-core space")
					rows.append({"asset": asset, "variant": variant, "scale": size, "up": str(up), "shapes": body.shape_count})
					body.free()
	await _independent_sizes(fixture)
	fixture.free()
	Assets.finish_pending_loads()
	for failure in failures: push_error(failure)
	print("INT30_SCENERY_COLLISION ", JSON.stringify({"passed": failures.is_empty(), "cases": rows.size(), "failures": failures.size()}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _independent_sizes(fixture: Node3D) -> void:
	# Simultaneous sizes must not mutate a shared hull or inherit another owner.
	var body := Obstacles.new()
	body.collision_layer = 2
	fixture.add_child(body)
	body.add_batch({"asset_id": "tall_pine_v2", "species": {"geometry_variant": 0},
		"transforms": [Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), Vector3(0, 80, 0)),
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.2), Vector3(10, 80, 0))]})
	await physics_frame
	await process_frame
	for index in range(2):
		var point := Vector3(index * 10 + 0.4, 80.8, 0)
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0, 3), point - Vector3(0, 0, 3), 2)
		var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
		_expect((hit.get("collider") == body) == (index == 1), "Concurrent small/large stem inherited another size")
	var owners: PackedInt32Array = body.get_shape_owners()
	_expect(body.shape_owner_get_shape(owners[0], 0) == body.shape_owner_get_shape(owners[1], 0),
		"Different sizes rebuilt the same authored native hull")
	body.free()

func _has_visible_bark(mesh: Mesh, point: Vector3) -> bool:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var slot: int = floori(uv[indices[i]].x * 32)
		if slot < 4 or slot > 6: continue
		if Geometry3D.segment_intersects_triangle(point + Vector3(3, 0, 0), point - Vector3(3, 0, 0),
			vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]) != null: return true
	return false

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
