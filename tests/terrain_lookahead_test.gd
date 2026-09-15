extends SceneTree
## Real campaign player, worker jobs, uploads and radial collision ownership.
const Cube = preload("res://world/space/cube_sphere.gd")
const Shutdown = preload("res://core/runtime_shutdown.gd")
var failures: Array[String] = []
var terrain: Node3D
var player: CharacterBody3D
var metrics: Dictionary = {}
var residency_checks: int = 0
var residency_states: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	var flow: Node = root.get_node("SessionFlow")
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	flow.new_game("ARCH-17 terrain acceptance", 15838)
	var deadline: int = Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.get("world_initialized") == true and not flow.loading: break
	if current_scene == null or current_scene.get("world_initialized") != true:
		_expect(false, "Campaign failed to become playable.")
		await _finish(); return
	terrain = current_scene.terrain
	player = current_scene.player
	# Pause actors while driving only the real terrain lifecycle explicitly.
	paused = true
	var address: Dictionary = Cube.address(terrain.surface.body.id, 0, 0.999997, 0.79)
	address.height = terrain.surface.sample(address).height + 0.1
	player.place(address)
	var up: Vector3 = player.up_direction
	var tangent: Vector3 = Cube.frame(up).x
	var start: Array = Cube.cartesian(player.location(), terrain.surface.body.radius)
	_expect(terrain.ground_ready(start), "Forced seam placement lacks the real floor.")
	_check_residency()
	var speed: float = player.move_speed
	player.velocity = tangent * speed
	var movement: Vector3 = player._prepare_surface_movement(-tangent * speed, 1.0 / 60.0)
	_expect(movement.dot(tangent) < 0.0 and not player.waiting_for_terrain, "Prepared backward movement was blocked.")
	_expect((terrain.lookahead_direction - up).dot(tangent) < 0.0, "Reversal used previous velocity instead of requested input.")
	var owner: Dictionary = terrain.layout.find_at(address.face, address.u, address.v, terrain.leaves)
	var shape: CollisionShape3D = terrain.active[owner.id].get_child(0)
	shape.disabled = true
	movement = player._prepare_surface_movement(-tangent * speed, 1.0 / 60.0)
	_expect(movement == Vector3.ZERO and player.waiting_for_terrain, "Missing physical floor allowed movement or hid the wait.")
	_expect((terrain.lookahead_direction - up).dot(tangent) < 0.0, "Waiting erased the requested direction.")
	shape.disabled = false
	_expect(player._prepare_surface_movement(-tangent * speed, 1.0 / 60.0).length() > 0.0 and not player.waiting_for_terrain, "Restored floor did not release the same movement.")
	_expect(player.move_speed == speed, "Streaming changed campaign speed.")
	terrain.set_motion_hint(up, tangent * 10000.0)
	_expect(terrain.lookahead_direction.distance_to(up) * terrain.surface.body.radius <= 33.0, "Lookahead exceeds its bounded 32 m horizon (1 m float tolerance).")
	terrain.set_motion_hint(up, Vector3.ZERO)
	_expect(terrain.lookahead_direction.is_equal_approx(up), "Stationary input kept a forward lead.")
	# A → B → A before polling must invalidate the first A generation too.
	terrain.set_motion_hint(up, tangent * 24.0)
	terrain.stream_at(up)
	var old_job: RefCounted = terrain._job
	var old_generation: int = terrain._job_generation
	var published: int = terrain.updates
	terrain.set_motion_hint(up, -tangent * 24.0)
	terrain.stream_at(up)
	terrain.set_motion_hint(up, tangent * 24.0)
	terrain.stream_at(up)
	_expect(terrain._job == old_job and terrain._generation > old_generation, "Turns replaced/joined the worker synchronously or reused the old generation.")
	for index in range(4): await process_frame
	_expect(terrain.updates == published and terrain._job == old_job, "Paused terrain published or advanced a job.")
	await _drain(start)
	_expect(terrain.discarded_jobs > 0 and old_job._tasks.is_empty() and old_job._selection_task == -1, "Obsolete worker survived or was published.")
	old_job = null
	# Start the opposite cover and abandon a fully prepared, inactive collider.
	terrain.set_motion_hint(up, -tangent * 24.0)
	terrain.stream_at(up)
	deadline = Time.get_ticks_msec() + 20000
	while terrain._job != null and not terrain._job.advance():
		if Time.get_ticks_msec() > deadline: _expect(false, "Staging preparation timed out."); await _finish(); return
		await process_frame
	terrain._collect_job()
	_check_residency()
	_expect(not terrain._pending.is_empty(), "Fixture did not require a changed terrain patch.")
	if terrain._pending.is_empty(): await _finish(); return
	var id: String = ""
	for candidate: String in terrain._prepared_near:
		if candidate in terrain._pending and not terrain._staging[candidate].has("node"):
			id = candidate
			break
	_expect(not id.is_empty(), "Fixture has no unpublished near collider to cancel.")
	if id.is_empty(): await _finish(); return
	terrain._pending.erase(id)
	terrain._pending.append(id)
	# A patch now spans several budgeted operations; each step must leave the
	# old floor intact and the new node invisible until the whole cover exists.
	for step in range(5):
		terrain._build_next()
		_check_residency()
		_expect(terrain.ground_ready(start), "Partial upload removed the old floor.")
		if terrain._staging[id].has("node"): break
	var unpublished: Node3D = terrain._staging[id].node
	var reference: WeakRef = weakref(unpublished)
	_expect(not unpublished.visible, "Incomplete terrain became visible.")
	for step in range(2):
		terrain._build_next()
		_check_residency()
		if terrain._staging[id].has("collider"): break
	var staged_body: StaticBody3D = terrain._staging[id].collider
	var body_reference: WeakRef = weakref(staged_body)
	_expect(staged_body.is_inside_tree() and staged_body.collision_layer == 0 and staged_body.collision_mask == 0, "Prepared physics body became collidable before handoff.")
	var point: Array = Cube.global_position(unpublished.position, terrain.origin)
	terrain.rebase([terrain.origin[0] + 80.0, terrain.origin[1] - 40.0, terrain.origin[2] + 15.0])
	_expect(Cube.local_position(Cube.global_position(unpublished.position, terrain.origin), point).length() < 0.001, "Origin shift moved a staged patch.")
	published = terrain.updates
	terrain.set_motion_hint(up, tangent * 24.0)
	terrain.stream_at(up)
	terrain._process(1.0 / 60.0)
	_check_residency()
	_expect(terrain.updates == published and terrain.discarded_publications > 0, "Obsolete partial publication replaced the valid floor.")
	unpublished = null
	staged_body = null
	await process_frame
	_expect(reference.get_ref() == null, "Discarded staged node remained allocated.")
	_expect(body_reference.get_ref() == null, "Discarded staged physics body remained allocated.")
	await _drain(start)
	_expect(terrain.cache_hits > 0, "Reversal fixture never reused a cached mesh.")
	for state in ["shared", "mesh_before_node", "retired", "cache", "empty"]:
		_expect(residency_states.has(state), "Residency fixture missed state: " + state)
	metrics = terrain.streaming_diagnostics()
	metrics.merge({"residency_checks": residency_checks, "residency_states": residency_states})
	metrics.merge({"tiles": terrain.leaves.size(), "collisions": terrain.active.size(), "resident_peak": terrain.peak_resident_meshes})
	# Actual scene teardown joins a queued selection/mesh worker.
	terrain.set_motion_hint(up, -tangent * 24.0)
	terrain.stream_at(up)
	var closing_job: RefCounted = terrain._job
	_expect(closing_job != null, "Teardown fixture did not leave an outstanding worker.")
	current_scene.free()
	current_scene = null
	if closing_job != null:
		_expect(closing_job._tasks.is_empty() and closing_job._selection_task == -1, "World teardown left a live worker.")
	closing_job = null
	await _finish()

func _drain(start: Array) -> void:
	var deadline: int = Time.get_ticks_msec() + 20000
	while terrain._job != null or not terrain._pending.is_empty() or not terrain._retired.is_empty() or not terrain._collision_pending.is_empty():
		terrain._process(1.0 / 60.0)
		_check_residency()
		_expect(terrain.last_build_count <= 2 and terrain.leaves.size() <= 768 and terrain.active.size() <= 24 and terrain.peak_resident_meshes <= 1536 and terrain._collision_pending.size() <= 24, "Streaming exceeded its existing object/upload budgets.")
		for tile: Dictionary in terrain._staging.values():
			if tile.has("collider") and terrain.active.get(tile.id) != tile.collider:
				_expect(tile.collider.collision_layer == 0 and tile.collider.collision_mask == 0, "Unpublished terrain entered active physics.")
		_expect(terrain.ground_ready(start), "Job handoff removed the walker's attached floor.")
		if Time.get_ticks_msec() > deadline: _expect(false, "Latest terrain intent did not finish."); return
		await process_frame
	_check_residency()

func _check_residency() -> void:
	# Independently inventory real mesh resources through every lifecycle step.
	# The production ledger must agree before/after cache transfer, partial
	# upload, sharing, handoff, retirement and generation cancellation.
	var staged: int = 0
	for tile: Dictionary in terrain._staging.values():
		if not tile.has("mesh"): continue
		if terrain.leaves.has(tile.id) and terrain.leaves[tile.id].get("node") == tile.get("node"):
			residency_states["shared"] = true
			continue
		staged += 1
		if not tile.has("node"): residency_states["mesh_before_node"] = true
	if not terrain._retired.is_empty(): residency_states["retired"] = true
	if not terrain._cache.is_empty(): residency_states["cache"] = true
	if terrain._staging.is_empty(): residency_states["empty"] = true
	var total: int = terrain.leaves.size() + terrain._retired.size() + staged + terrain._cache.size()
	_expect(terrain._staging_mesh_count == staged, "Staging mesh ledger differs from actual mesh owners.")
	_expect(total <= terrain.MAX_RESIDENT and terrain._cache.size() <= terrain.MAX_CACHED, "Actual terrain/cache residency exceeds its limits.")
	_expect(terrain.peak_resident_meshes >= total, "Residency peak omits live mesh owners.")
	residency_checks += 1

func _expect(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func _finish() -> void:
	paused = false
	for failure in failures: push_error(failure)
	print("TERRAIN_LOOKAHEAD ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "metrics": metrics}))
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)
