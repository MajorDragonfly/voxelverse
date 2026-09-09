extends SceneTree

const World = preload("res://world/planet_lab/living_planet.gd")
const Save = preload("res://world/surface/living_planet_store.gd")
const Surface = preload("res://world/surface/living_planet_surface.gd")
const Job = preload("res://world/surface/surface_population_job.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []
var metrics: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	var protected: Dictionary = {}
	for path in ["user://voxelverse_save.json", "user://planet_lab_m1.json", "user://surface_adapter_m1d.json"]:
		protected[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var world := World.new()
	root.add_child(world)
	if "--living-restart" in OS.get_cmdline_user_args():
		world.set_paused(true)
		var stored: Dictionary = Save.read().data
		_expect(not stored.is_empty() and stored.body_id == world.body_id, "Restart lost body")
		_expect(_distance(stored.bodies[world.body_id].player.location, world.walker.location(), world) < 0.001, "Restart lost player location")
		_expect(JSON.stringify(stored.bodies[world.body_id].fauna) == JSON.stringify(world.ecosystem.animal_records), "Restart changed individual anatomy or saved animal state")
		# Load real runtime visuals in the fresh process, not just JSON records.
		world.set_paused(false)
		for frame in range(900):
			await physics_frame
			if not world.ecosystem.animals.is_empty():
				break
		world.set_paused(true)
		var expected_file := FileAccess.open("user://living_test_native.bin", FileAccess.READ)
		var expected: Dictionary = expected_file.get_var(false)
		expected_file.close()
		_expect(not world.ecosystem.animals.is_empty(), "Restart did not instantiate saved fauna")
		for id: String in world.ecosystem.animals:
			_expect(expected.has(id) and world.ecosystem.animals[id].design == expected[id], "Restart changed native anatomy, color or attachment types")
		await _finish(world)
		return
	_expect(world.terrain.surface is Surface and world.terrain.surface.body.radius == 6371000.0, "Living surface not used on Earth-sized terrain")
	var height_min: float = INF
	var height_max: float = -INF
	var biomes: Dictionary = {}
	var ocean: Dictionary = {}
	for face in range(6):
		for x in range(-4, 5):
			for y in range(-4, 5):
				var point: Dictionary = Cube.address(world.body_id, face, x * 0.2, y * 0.2)
				var sample: Dictionary = world.adapter.sample(point)
				height_min = minf(height_min, sample.height)
				height_max = maxf(height_max, sample.height)
				biomes[sample.biome] = true
				if sample.height < -5.0:
					ocean = point.duplicate(true)
	_expect(height_min < -5.0 and height_max > 70.0 and biomes.size() >= 5, "Spherical landscape lacks seas/mountains/biome diversity")
	var near: Dictionary = Job.nearby(world.terrain.surface.body, world.walker.location())
	var first_cell: Dictionary = near.values()[0]
	var a := Job.new()
	a.body = world.terrain.surface.body
	a.cell = first_cell
	a.run()
	var b := Job.new()
	b.body = a.body
	b.cell = a.cell
	b.run()
	_expect(var_to_bytes(a.result) == var_to_bytes(b.result), "Flora differs when preparing the same body/cell twice")
	# Permit worker preparation and cold art loads, but enforce a bounded wait.
	for frame in range(1200):
		await physics_frame
		if world.ecosystem.patches.size() >= 24 and world.ecosystem.animals.size() >= 1:
			break
	_expect(world.ecosystem.patches.size() >= 20 and world.ecosystem.instance_count() > 80, "World did not populate its streamed landscape")
	_expect(world.ecosystem.animals.size() >= 1, "No generated fauna reached prepared dry habitat")
	var moving_animals: int = 0
	for animal in world.ecosystem.animals.values():
		moving_animals += int(animal.traveled > 0.5)
	_expect(moving_animals > 0, "Streamed animals have no actual movement")
	var collision_shapes: int = 0
	var families: Dictionary = {}
	for patch: Dictionary in world.ecosystem.patches.values():
		collision_shapes += patch.node.shape_count
		for visual in patch.node.get_children():
			families[visual.get_meta("asset")] = true
	_expect(collision_shapes > 10 and families.size() >= 5, "Existing authored trees/plants/rocks lack variety or real collision shapes")
	metrics.merge({"min_height_m": height_min, "max_height_m": height_max, "biomes": biomes.keys(),
		"initial_patches": world.ecosystem.patches.size(), "initial_instances": world.ecosystem.instance_count(),
		"animal_count": world.ecosystem.animals.size(), "moving_animals": moving_animals,
		"collision_shapes": collision_shapes, "asset_families": families.keys(), "initial_load_ms": world.initial_load_ms})
	if "--living-render" in OS.get_cmdline_user_args():
		world.set_paused(true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://living_planet.png")
		print("LIVING_SCREENSHOT ", ProjectSettings.globalize_path("user://living_planet.png"))
		await _finish(world)
		return
	# Query actual compound bodies in radial space; grass is deliberately absent
	# from these colliders. This catches transform errors that shape counts miss.
	var obstacle_hits: int = 0
	for patch: Dictionary in world.ecosystem.patches.values():
		if patch.node.collision_layer != 2:
			continue
		for instance: Dictionary in patch.node.instances:
			var transform: Transform3D = instance.transform
			var center: Vector3 = patch.node.to_global(transform.origin)
			var ray := PhysicsRayQueryParameters3D.create(center + transform.basis.x * 4.0, center - transform.basis.x * 4.0, 2)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider == patch.node:
				obstacle_hits += 1
	_expect(obstacle_hits > 10, "Radial compound tree/rock collision failed actual physics queries")
	metrics.radial_obstacle_hits = obstacle_hits
	var origin: Dictionary = world.walker.location()
	var target: Dictionary = world.adapter.offset(origin, world.walker.basis.x * 210.0, 1.1)
	# Travel to another prepared region, then walk physically there. World-Y
	# and absolute positions remain unsuitable on this intentionally tilted face.
	world.set_paused(true)
	world._capture()
	var before: Dictionary = world.snapshot()
	world.walker.place(target)
	world.stream_objects()
	world.set_paused(false)
	world.walker.orbit_axis = world.walker.up_direction.cross(world.walker.forward).normalized()
	world.walker.automatic = true
	world.walker.traveled = 0.0
	world.walker.speed = 8.0
	var contacts: int = 0
	for frame in range(180):
		await physics_frame
		contacts += int(world.walker.is_on_floor() or world.walker.swimming)
		_expect(world.ecosystem.patches.size() <= 25 and world.ecosystem.animals.size() <= 4, "Living-world active budget exceeded")
		_expect(world.adapter.collision_ready(world.walker.location()), "Player lost prepared terrain under the living surface")
	world.walker.automatic = false
	world.set_paused(true)
	_expect(world.walker.traveled > 12.0 and contacts >= 160, "Living surface failed physical walking and floor contact")
	_expect(world.ecosystem.unloaded >= 20, "Travel did not evict distant flora patches")
	metrics.patch_loads = world.ecosystem.loaded
	metrics.patch_unloads = world.ecosystem.unloaded
	metrics.walk_m = world.walker.traveled
	metrics.contacts = contacts
	metrics.max_flora_worker_ms = world.ecosystem.max_worker_ms
	metrics.max_flora_publish_ms = world.ecosystem.max_publish_ms
	metrics.max_ecosystem_frame_work_ms = world.ecosystem.max_frame_work_ms
	metrics.max_animal_build_ms = world.ecosystem.max_animal_build_ms
	world.return_to_marker()
	world.set_paused(true)
	_expect(_distance(before.bodies[world.body_id].spawn, world.walker.location(), world) < 0.001, "Return-to-place failed")
	for id in before.bodies[world.body_id].fauna:
		_expect(world.ecosystem.animal_records.has(id) and world.ecosystem.animal_records[id].design == before.bodies[world.body_id].fauna[id].design, "Return regenerated an existing animal's body")
	# Finish one reloaded individual and retain the native runtime anatomy for
	# an independent binary comparison after JSON save and a new engine process.
	world.set_paused(false)
	for frame in range(900):
		await physics_frame
		if not world.ecosystem.animals.is_empty():
			break
	world.set_paused(true)
	var native_designs: Dictionary = {}
	for id: String in world.ecosystem.animal_records:
		native_designs[id] = JSON.to_native(world.ecosystem.animal_records[id].design, false)
	for id: String in world.ecosystem.animals:
		native_designs[id] = world.ecosystem.animals[id].design.duplicate(true)
	var expected_file := FileAccess.open("user://living_test_native.bin", FileAccess.WRITE)
	expected_file.store_var(native_designs, false)
	expected_file.close()
	_expect(world.save_lab(), "Living-world checkpoint did not save")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--living-restart"], output, true)
	_expect(code == 0 and not str(output).contains("ERROR:"), "Fresh-process return failed: " + str(output))
	metrics.restart_exit = code
	var invalid: Dictionary = world.snapshot()
	invalid.surface_generation = "living_planet_v2"
	_expect(not Save.valid(invalid), "Future landscape silently regenerated")
	# A different coast/ocean region uses the same sea radius for buoyancy,
	# surface rendering and the actual camera atmosphere.
	world._capture()
	ocean.height = 0.6
	world.records[world.body_id].player.location = ocean.duplicate(true)
	world.open_body(world.body_id, false)
	world.set_paused(false)
	for frame in range(60):
		await physics_frame
	world.set_paused(true)
	_expect(world.walker.swimming and absf(world.walker.location().height - 0.6) < 0.1, "Sea surface and real radial buoyancy disagree")
	var camera_point: Dictionary = ocean.duplicate(true)
	camera_point.height = -2.0
	world.walker.camera.global_position = world.adapter.to_local(camera_point)
	world.underwater.update_view()
	_expect(world.underwater.submerged and absf(world.underwater.depth - 2.0) < 0.01, "Camera immersion lost radial ocean depth")
	camera_point.height = 2.0
	world.walker.camera.global_position = world.adapter.to_local(camera_point)
	world.underwater.update_view()
	_expect(not world.underwater.submerged, "Camera above the ocean remained underwater")
	metrics.swimming_height_m = world.walker.location().height
	metrics.camera_water_crossing = true
	for path in protected:
		var after: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		_expect(after == protected[path], "Living surface changed an older campaign or lab save")
	await _finish(world)


func _distance(a: Dictionary, b: Dictionary, world: Node) -> float:
	return Cube.local_position(Cube.cartesian(a, world.terrain.surface.body.radius), Cube.cartesian(b, world.terrain.surface.body.radius)).length()


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)


func _finish(world: Node) -> void:
	world.queue_free()
	await process_frame
	await process_frame
	for message in failures:
		push_error(message)
	print("LIVING_PLANET_METRICS ", JSON.stringify(metrics))
	print("LIVING_PLANET_PASSED ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
