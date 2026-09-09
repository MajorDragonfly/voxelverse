extends SceneTree

const Lab = preload("res://world/planet_lab/surface_adapter_lab.gd")
const Store = preload("res://world/surface/surface_lab_store.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []
var metrics: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var service: Node = root.get_node("SaveGameService")
	service.autosave_enabled = true
	if "--m1d-restart" in OS.get_cmdline_user_args():
		await _restart()
		return
	_expect(service.save_now(), "Could not create the protected campaign fixture")
	var protected_paths: Array[String] = [service.save_path, "user://planet_lab_m1.json", "user://creature_assembly_v7.json"]
	var protected: Dictionary = {}
	for path in protected_paths:
		protected[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var lab := Lab.new()
	root.add_child(lab)
	_expect(not service.autosave_enabled, "M1d did not suspend campaign autosave")
	_expect(not service.save_now(), "Manual campaign writes must also be inactive inside M1d")
	service.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_expect(lab.terrain.surface.body.radius == 6371000.0, "Fixture shrunk Earth")
	for frame in range(100):
		await physics_frame
	_expect(is_instance_valid(lab.tree) and is_instance_valid(lab.creature), "Both real specimen objects must load")
	if not is_instance_valid(lab.tree) or not is_instance_valid(lab.creature):
		await _finish(lab)
		return
	_expect(lab.creature.traveled > 2.0 and lab.creature.is_on_floor(), "Creature failed to move with radial floor contact")
	metrics.creature_walk_m = lab.creature.traveled
	var tree_origin: Dictionary = lab.adapter.location(lab.tree)
	var tree_frame: Basis = lab.tree.basis
	lab.creature.enabled = false
	# Actual CharacterBody motion against the tree, not merely a query or overlap.
	var direction: Vector3 = (lab.tree.position - lab.walker.position).slide(lab.walker.up_direction).normalized()
	lab.walker.orbit_axis = lab.walker.up_direction.cross(direction).normalized()
	lab.walker.automatic = true
	var tree_hits: int = 0
	for frame in range(180):
		await physics_frame
		for index in range(lab.walker.get_slide_collision_count()):
			tree_hits += int(lab.walker.get_slide_collision(index).get_collider() == lab.tree)
	metrics.player_tree_hits = tree_hits
	_expect(tree_hits > 20, "Player passed through the authored tree's collider")
	_expect(lab.walker.position.distance_to(lab.tree.position) > 0.9, "Player penetrated the trunk")
	lab.walker.automatic = false
	lab.walker.enabled = false
	# A living creature is an obstacle for the player too.
	var contact: Dictionary = lab.adapter.offset(tree_origin, lab.tree.basis.x * 5.0, 1.1)
	lab.adapter.place(lab.creature, contact)
	var behind: Dictionary = lab.adapter.offset(contact, lab.tree.basis.z * 4.0, 1.1)
	lab.adapter.place(lab.walker, behind)
	lab.walker.velocity = Vector3.ZERO
	lab.walker.forward = -lab.tree.basis.z
	lab.walker.orbit_axis = lab.walker.up_direction.cross(lab.walker.forward).normalized()
	lab.walker.automatic = true
	lab.walker.enabled = true
	var creature_hits: int = 0
	for frame in range(90):
		await physics_frame
		for index in range(lab.walker.get_slide_collision_count()):
			creature_hits += int(lab.walker.get_slide_collision(index).get_collider() == lab.creature)
	metrics.player_creature_hits = creature_hits
	_expect(creature_hits > 10, "Player did not collide with the creature")
	lab.walker.enabled = false
	# Put the NPC on a short approach and exercise its own physics against bark.
	var npc_start: Dictionary = lab.adapter.offset(tree_origin, lab.tree.basis.z * 4.0, 1.1)
	lab.adapter.place(lab.creature, npc_start)
	lab.creature.velocity = Vector3.ZERO
	lab.creature.commanded_direction = -lab.tree.basis.z
	lab.creature.enabled = true
	var npc_hits: int = 0
	for frame in range(150):
		await physics_frame
		for index in range(lab.creature.get_slide_collision_count()):
			npc_hits += int(lab.creature.get_slide_collision(index).get_collider() == lab.tree)
	metrics.creature_tree_hits = npc_hits
	metrics.creature_tree_final_distance_m = lab.creature.position.distance_to(lab.tree.position)
	_expect(npc_hits > 10, "Creature passed through the tree")
	lab.creature.enabled = false
	lab.creature.commanded_direction = Vector3.ZERO
	lab.walker.automatic = false
	lab.return_to_marker()
	lab.creature.enabled = false
	# Cross a real cube-face boundary at metre scale, including origin rebases
	# and object eviction. The held NPC must survive as the same saved individual.
	var start: Dictionary = lab.walker.location()
	var tangent: Vector3 = (Cube.vector(Cube.direction(start.face, start.u + 0.0001, start.v)) - lab.walker.up_direction).slide(lab.walker.up_direction).normalized()
	lab.walker.orbit_axis = lab.walker.up_direction.cross(tangent).normalized()
	lab.walker.automatic = true
	lab.walker.enabled = true
	lab.walker.speed = 18.0
	lab.walker.traveled = 0.0
	var faces: Dictionary = {}
	var contacts: int = 0
	var frames: int = 0
	var wait_frames: int = 0
	for frame in range(1800):
		await physics_frame
		frames += 1
		contacts += int(lab.walker.is_on_floor())
		wait_frames += int(lab.walker.waiting_for_terrain)
		var here: Dictionary = lab.walker.location()
		faces[here.face] = true
		_expect(lab.adapter.collision_ready(here), "Walking player lost its near collision tile")
		_expect(lab.terrain.tiles.size() <= 768 and lab.terrain.active.size() <= 24 and lab.terrain.last_build_count <= 2,
			"Terrain exceeded its bounded streaming budgets")
		_expect(here.height > lab.adapter.sample(here).height - 0.25, "Player fell beneath the spherical terrain")
		if lab.walker.traveled >= 180.0:
			break
	lab.walker.enabled = false
	lab.walker.automatic = false
	lab.stream_objects()
	metrics.merge({"walk_m": lab.walker.traveled, "physics_frames": frames, "floor_contacts": contacts,
		"waiting_frames": wait_frames, "faces": faces.size(), "rebases": lab.terrain.rebases,
		"unloads": lab.object_unloads, "peak_tiles": lab.terrain.peak_tiles,
		"peak_resident_meshes": lab.terrain.peak_resident_meshes, "publishes": lab.terrain.updates,
		"initial_load_ms": lab.initial_load_ms, "max_object_build_ms": lab.max_object_build_ms,
		"max_upload_ms": lab.terrain.max_build_usec / 1000.0, "max_worker_ms": lab.terrain.max_worker_usec / 1000.0,
		"max_rebase_error_m": lab.adapter.max_rebase_error_m})
	_expect(lab.walker.traveled >= 180.0 and faces.size() >= 2 and contacts > frames * 0.95, "Motion/contact/face-crossing acceptance failed")
	_expect(lab.terrain.rebases >= 3 and lab.object_unloads == 2 and lab.adapter.attached.size() == 1, "Objects did not unload after floating-origin travel")
	_expect(lab.adapter.max_rebase_error_m < 0.0001, "Rebase moved an object's body-fixed location")
	lab.return_to_marker()
	lab.walker.enabled = false
	lab.creature.enabled = false
	var tree_return_error: float = _distance(tree_origin, lab.adapter.location(lab.tree), 6371000.0)
	metrics.tree_return_error_m = tree_return_error
	_expect(tree_return_error < 0.001 and lab.tree.basis.y.dot(tree_frame.y) > 0.99999, "Unloaded tree returned at a different place/orientation")
	var first: Dictionary = lab.snapshot()
	_expect(lab.save_lab(), "M1d save failed")
	_expect(lab.open_body("m1b:1000"), "Body travel failed")
	lab.walker.enabled = false
	if is_instance_valid(lab.creature):
		lab.creature.enabled = false
	_expect(lab.adapter.attached.size() <= 3 and lab.terrain.surface.body.radius == 500000.0, "Travel retained old objects or changed real radius")
	lab.open_body("m1b:terra")
	lab.walker.enabled = false
	lab.creature.enabled = false
	var returned: Dictionary = lab.snapshot()
	_check_poses(first.bodies["m1b:terra"], returned.bodies["m1b:terra"], 6371000.0)
	_expect(lab.save_lab(), "Return checkpoint save failed")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--m1d-restart"], output, true)
	_expect(code == 0 and not str(output).contains("ERROR:"), "Fresh-process return failed: " + str(output))
	metrics.restart_exit = code
	_storage_checks(returned)
	for path in protected:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		_expect(bytes == protected[path], "M1d changed protected campaign/design/lab file: " + path)
	metrics.protected_files = protected_paths.size()
	if "--m1d-render" in OS.get_cmdline_user_args():
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://m1d_surface.png")
	await _finish(lab)


func _restart() -> void:
	var saved: Dictionary = Store.read().data
	_expect(not saved.is_empty(), "Restart did not find its checkpoint")
	var lab := Lab.new()
	root.add_child(lab)
	lab.walker.enabled = false
	if is_instance_valid(lab.creature):
		lab.creature.enabled = false
	_expect(lab.body_id == saved.body_id, "Restart lost the selected body")
	_check_poses(saved.bodies[lab.body_id], lab.snapshot().bodies[lab.body_id], lab.terrain.surface.body.radius)
	await _finish(lab)


func _check_poses(before: Dictionary, after: Dictionary, radius: float) -> void:
	for key in ["player", "tree", "creature"]:
		_expect(_distance(before[key].location, after[key].location, radius) < 0.001, "Return/restart lost " + key + " location")
		_expect(Cube.vector(before[key].forward).dot(Cube.vector(after[key].forward)) > 0.99999, "Return/restart lost " + key + " heading")
		_expect(absf(before[key].traveled - after[key].traveled) < 0.001, "Return/restart lost " + key + " movement state")
	for key in ["object_id", "design_id", "returning", "home", "goal"]:
		_expect(JSON.stringify(before.creature[key]) == JSON.stringify(after.creature[key]), "Return/restart lost NPC " + key)


func _storage_checks(good: Dictionary) -> void:
	var path: String = "user://m1d_contract.json"
	_expect(Store.write(good, path) == OK and Store.write(good, path) == OK, "Atomic M1d write failed")
	Atomic._write_text(path, "{broken")
	_expect(Store.read(path).get("recovered", false) and Store.write(good, path) == OK, "Backup recovery failed")
	var future: Dictionary = good.duplicate(true)
	future.schema = 2
	Atomic.write(path, future)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_expect(Store.read(path).error == ERR_UNAVAILABLE and Store.write(good, path) == ERR_UNAVAILABLE \
		and FileAccess.get_file_as_bytes(path) == bytes, "Future save overwritten")
	for key in ["body_id", "face", "height"]:
		var invalid: Dictionary = good.duplicate(true)
		invalid.bodies[invalid.body_id].creature.location[key] = {"body_id": "legacy", "face": 1.5, "height": INF}[key]
		_expect(not Store.valid(invalid), "Invalid location accepted: " + key)
	var wrong_world: Dictionary = good.duplicate(true)
	wrong_world.bodies[wrong_world.body_id].seed += 1
	_expect(not Store.valid(wrong_world), "Changed generator accepted as the same surface")
	var legacy: Dictionary = good.duplicate(true)
	legacy.surface_mode = "legacy_plane_v9"
	_expect(not Store.valid(legacy), "Legacy campaign silently converted")


func _distance(a: Dictionary, b: Dictionary, radius: float) -> float:
	return Cube.local_position(Cube.cartesian(a, radius), Cube.cartesian(b, radius)).length()


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)


func _finish(lab: Node) -> void:
	lab.queue_free()
	await process_frame
	await process_frame
	_expect(root.get_node("SaveGameService").autosave_enabled, "Campaign autosave did not restore on exit")
	for message in failures:
		push_error(message)
	print("SURFACE_ADAPTER_METRICS ", JSON.stringify(metrics))
	print("SURFACE_ADAPTER_PASSED ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
