extends RefCounted
## Same cold CPU route on base and candidate; no GPU/FPS claim.
const Terrain = preload("res://world/surface/surface_terrain.gd")
const System = preload("res://world/space/celestial_system.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []
var peak_queue: int = 0
var steps: Array[float] = []
var drains: Array[Dictionary] = []

func run(tree: SceneTree) -> void:
	tree.root.get_node("SaveGameService").autosave_enabled = false
	var terrain := Terrain.new()
	tree.root.add_child(terrain)
	terrain.set_process(false)
	var descriptor: Dictionary = System.new(false, true).bodies["m1b:terra"].duplicate(true)
	descriptor.merge({"surface_generation": "living_planet_v2", "terrain_revision": 4}, true)
	terrain.configure(descriptor)
	var address: Dictionary = Cube.address(descriptor.id, 0, 0.999997, 0.79)
	address.height = terrain.surface.sample(address).height + 0.1
	var point: Array = Cube.cartesian(address, descriptor.radius)
	terrain.rebase(point)
	var up: Vector3 = Cube.vector(Cube.direction(address.face, address.u, address.v))
	var tangent: Vector3 = Cube.frame(up).x
	terrain.stream_at(up)
	await _drain(tree, terrain, point, "cold", false)
	_check(terrain.ground_ready(point), "Cold publication lacks attached floor")
	for sign_value in [1.0, -1.0, 1.0]:
		terrain.last_worker_seconds = 1.1 # Fix the 32 m route independently of measured worker speed.
		terrain.set_motion_hint(up, tangent * sign_value * 24.0)
		terrain.stream_at(up)
		await _drain(tree, terrain, point, "turn_%s" % sign_value, true)
	# Abandon a genuinely partial upload, then retire an outstanding worker.
	terrain.last_worker_seconds = 1.1
	terrain.set_motion_hint(up, -tangent * 24.0)
	terrain.stream_at(up)
	var deadline: int = Time.get_ticks_msec() + 30000
	while terrain._job != null and not terrain._job.advance():
		if Time.get_ticks_msec() > deadline: _check(false, "Partial preparation timeout"); break
		await tree.process_frame
	terrain._collect_job()
	_check(not terrain._pending.is_empty(), "Partial fixture reused all terrain")
	if not terrain._pending.is_empty(): terrain._build_next()
	terrain.last_worker_seconds = 1.1
	terrain.set_motion_hint(up, tangent * 24.0)
	terrain.stream_at(up)
	terrain._process(1.0 / 60.0)
	_check(terrain.ground_ready(point), "Discard removed the attached floor")
	await _drain(tree, terrain, point, "discard", true)
	steps.sort()
	var metrics: Dictionary = {"scope": "Headless CPU; cold revision-4 Earth terrain, fixed cube seam, turns and teardown; no GPU/FPS", "godot": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "passed": failures.is_empty(), "failures": failures,
		"steps": steps.size(), "step_p95_ms": steps[mini(steps.size() - 1, ceili(steps.size() * 0.95) - 1)], "step_max_ms": steps[-1],
		"max_upload_ms": terrain.max_build_usec / 1000.0, "max_prepare_ms": terrain.max_prepare_usec / 1000.0,
		"max_handoff_ms": maxf(terrain.max_publish_usec, terrain.max_initial_publish_usec) / 1000.0,
		"queue_peak": peak_queue, "resident_peak": terrain.peak_resident_meshes, "tiles": terrain.leaves.size(), "collisions": terrain.active.size(),
		"drains": drains, "diagnostics": terrain.streaming_diagnostics()}
	terrain.last_worker_seconds = 1.1
	terrain.set_motion_hint(up, -tangent * 24.0)
	terrain.stream_at(up)
	var job: RefCounted = terrain._job
	_check(job != null, "Teardown fixture has no worker")
	var started: int = Time.get_ticks_usec()
	terrain.free()
	metrics["teardown_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	if job != null: _check(job._tasks.is_empty() and job._selection_task == -1, "Teardown left work alive")
	job = null
	metrics.passed = failures.is_empty()
	print("TERRAIN_PUBLICATION_METRICS ", JSON.stringify(metrics))
	for failure in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)

func _drain(tree: SceneTree, terrain: Node3D, point: Array, label: String, retain_floor: bool) -> void:
	var started: int = Time.get_ticks_msec()
	var prior_updates: int = terrain.updates
	while terrain._job != null or not terrain._pending.is_empty() or not terrain._retired.is_empty():
		var tick: int = Time.get_ticks_usec()
		terrain._process(1.0 / 60.0)
		steps.append((Time.get_ticks_usec() - tick) / 1000.0)
		peak_queue = maxi(peak_queue, terrain._pending.size())
		_check(terrain.last_build_count <= 2 and terrain.leaves.size() <= 768 and terrain.active.size() <= 24 and terrain.peak_resident_meshes <= 1536, "Object/upload budget exceeded")
		if retain_floor: _check(terrain.ground_ready(point), "Handoff lost attached floor")
		if Time.get_ticks_msec() - started > 30000:
			_check(false, "Drain timeout: " + label)
			break
		await tree.process_frame
	drains.append({"stage": label, "elapsed_ms": Time.get_ticks_msec() - started, "publications": terrain.updates - prior_updates})

func _check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)
