extends "res://core/diagnostics/spherical_campaign_probe.gd"
## Public campaign entry, canonical generated flora, real capsule motion.
const Checks = preload("res://tests/int30_scenery_collision_test.gd")
const Stats = preload("res://tools/performance_stats.gd")
const FloraAssets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const CHECKPOINT_INTERVAL_MS: int = 5000
const MAX_PHASE_RECORDS: int = 256
const MAX_CAPTURE_FRAMES: int = 120
const MAX_FLORA_TRACE_EVENTS: int = 16384
const MAX_FLORA_TRACE_CHECKPOINTS: int = 256
const FLORA_TRACE_RECENT: int = 24
const PROGRESS_PATH: String = "user://int30-collision-progress.json"
const FLORA_TRACE_PATH: String = "user://int30-collision-flora-trace.json"
var evidence: Dictionary = {}
var capture: bool = false
var actor: CharacterBody3D
var observer: Camera3D
var label: Label
var samples: Array = []
var publication_waits: Array[Dictionary] = []
var _diagnostic_started_usec: int = 0
var _phase_name: String = "prepare"
var _route_complete: bool = false
var _last_failure_checkpoint: int = -CHECKPOINT_INTERVAL_MS
var _flora_trace_enabled: bool = false
var _flora_trace_events: int = 0
var _flora_trace_dropped: int = 0
var _flora_trace_writes: int = 0
var _flora_trace_write_ms: float = 0.0
var _flora_trace_last_write_ms: int = -2000
var _flora_trace_recent: Array[Dictionary] = []
var _flora_trace_started: Dictionary = {}
var _flora_trace_max_ms: Dictionary = {}
var _flora_trace_counts: Dictionary = {}
var _flora_trace_first: Dictionary = {}
var _flora_trace_write_errors: int = 0

func _run() -> void:
	_diagnostic_started_usec = Time.get_ticks_usec()
	capture = "--capture" in OS.get_cmdline_user_args()
	_flora_trace_enabled = "--publication-trace" in OS.get_cmdline_user_args()
	evidence = {"schema": 2, "complete": false, "passed": false, "status": "incomplete",
		"seed": 15838, "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"cpu": OS.get_processor_name(), "adapter": RenderingServer.get_video_adapter_name(), "targets": [], "snapshots": [],
		"publication_waits": publication_waits, "phase_records": [], "capture_frames": [], "dropped_phase_records": 0,
		"diagnostic_limits": {"phase_records": MAX_PHASE_RECORDS, "capture_frames": MAX_CAPTURE_FRAMES, "wait_checkpoint_ms": CHECKPOINT_INTERVAL_MS,
			"flora_trace_events": MAX_FLORA_TRACE_EVENTS, "flora_trace_checkpoints": MAX_FLORA_TRACE_CHECKPOINTS}}
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	_phase("create-slot")
	var path: String = saves.create_slot("INT30 Umgebungskollision", 15838, Cube.MODE)
	if _flora_trace_enabled: FloraAssets.publication_trace_sink = _flora_trace
	_phase("open-world")
	await _open(path)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	var start: Dictionary = scene.player.location().duplicate(true)
	var flora: Node = scene.flora
	print("INT30_PHASE publication-start")
	await _wait_patches(flora, "near")
	print("INT30_PHASE targets-start")
	_phase("targets-near-start")
	var targets: Dictionary = _targets(scene)
	print("INT30_PHASE targets-ready ", targets.keys())
	_phase("targets-near-ready", {"families": targets.keys()})
	_expect(targets.size() == 4, "Canonical seed did not publish all four solid families")
	_snapshot(flora, "near")
	scene.player.set_physics_process(false)
	_setup_motion(scene)
	for asset: String in targets:
		var target: Dictionary = targets[asset]
		var original: Array = Cube.global_position(target.patch.position + target.transform.origin, scene.terrain.origin)
		_move_observer(scene, scene.adapter.offset(Cube.from_cartesian(scene.terrain.surface.body.id, original, scene.terrain.surface.body.radius),
			target.transform.basis.orthonormalized().x * 4, 1.1))
		flora._refresh()
		await tree.physics_frame
		await tree.process_frame
		await _sweep(scene, asset, target, "near", capture)
		# The root and all shape owners must move together; no collider rebuild.
		var ids: PackedInt32Array = target.patch.get_shape_owners()
		for shift in [Vector3(71, -33, 47), Vector3(-29, 61, -83)]:
			var here: Array = Cube.cartesian(scene.player.location(), scene.terrain.surface.body.radius)
			scene.terrain.rebase([here[0] + shift.x, here[1] + shift.y, here[2] + shift.z])
			await tree.physics_frame
			await tree.process_frame
			var after: Array = Cube.global_position(target.patch.position + target.transform.origin, scene.terrain.origin)
			_expect(Cube.local_position(after, original).length() < 0.002, "Origin shift moved generated solid " + asset)
			_expect(target.patch.get_shape_owners() == ids, "Rebase rebuilt compound shapes")
			await _sweep(scene, asset, target, "rebase", false)
		_snapshot(flora, "after-rebase")
	# Leave the entire canonical neighbourhood, then return through normal flora
	# streaming. Far scenery remains visual-only; no production/actor mutation.
	var references: Array[WeakRef] = []
	for target: Dictionary in targets.values(): references.append(weakref(target.patch))
	targets.clear()
	actor.position = Vector3(0, -1000, 0)
	_phase("move-far")
	_move_observer(scene, scene.adapter.offset(start, scene.adapter.frame_at(start).x * 360, 1.1))
	flora._refresh()
	var retire_deadline: int = Time.get_ticks_msec() + 2000
	_phase("retirement-start")
	while references.any(func(r: WeakRef): return r.get_ref() != null) and Time.get_ticks_msec() < retire_deadline:
		await tree.process_frame
	_expect(references.all(func(r: WeakRef): return r.get_ref() == null), "Streaming retained a retired compound body")
	_phase("retirement-finished", {"remaining_bodies": references.filter(func(r: WeakRef): return r.get_ref() != null).size()})
	await _wait_patches(flora, "far")
	_snapshot(flora, "far")
	_phase("move-return")
	_move_observer(scene, start)
	flora._refresh()
	await _wait_patches(flora, "return")
	_phase("targets-return-start")
	var returned: Dictionary = _targets(scene)
	_phase("targets-return-ready", {"families": returned.keys()})
	_expect(returned.size() == 4, "Near/far/near lost generated solid families")
	for asset: String in returned:
		var target: Dictionary = returned[asset]
		var address: Dictionary = Cube.from_cartesian(scene.terrain.surface.body.id,
			Cube.global_position(target.patch.position + target.transform.origin, scene.terrain.origin), scene.terrain.surface.body.radius)
		_move_observer(scene, scene.adapter.offset(address, target.transform.basis.orthonormalized().x * 4, 1.1))
		flora._refresh()
		await tree.physics_frame
		await tree.process_frame
		await _sweep(scene, asset, target, "returned", false)
	_snapshot(flora, "returned")
	await _wait_patches(flora, "final")
	_phase("physics-monitor-start")
	for i in range(180):
		await tree.physics_frame
		samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
	evidence.physics_monitor_ms = Stats.distribution(samples)
	evidence.physics_note = Stats.metric_notes().physics_monitor_ms + " Linux container measurement, not target-PC FPS."
	_phase("physics-monitor-finished")
	returned.clear()
	_phase("return-title")
	flow.return_to_title()
	await tree.scene_changed
	_route_complete = true
	await _finish()

func _move_observer(scene: Node3D, address: Dictionary) -> void:
	# Follow the normal asynchronous streaming path. player.place() is the
	# arrival/load operation and would synchronously rebuild full terrain for
	# every 4 m diagnostic reposition, obscuring scenery/physics costs.
	scene.adapter.place(scene.player, address)
	if scene.player.position.length() > 64:
		scene.terrain.rebase(Cube.cartesian(address, scene.terrain.surface.body.radius))
	scene.terrain.stream_at(scene.adapter.up_at(address))

func _wait_patches(flora: Node, stage: String) -> void:
	var began: int = Time.get_ticks_msec()
	var started: Dictionary = _stamp()
	var next_checkpoint: int = began + CHECKPOINT_INTERVAL_MS
	_phase("publication-" + stage + "-start")
	# This is a finite fixture preparation guard, not a target-PC latency gate.
	# The cold shared asset/publish budget measured only 15/25 cells at 45 s on
	# the busy container. Preserve that observation and record actual waits.
	# Functional assertions and the one-unit/25-body/24-shape limits stay exact.
	while Time.get_ticks_msec() - began < 90000:
		await tree.process_frame
		if flora.patches.size() == flora.wanted.size() and flora._publication.is_empty() and flora._task < 0:
			publication_waits.append({"stage": stage, "milliseconds": Time.get_ticks_msec() - began, "start": started, "end": _stamp(), "diagnostics": flora.streaming_diagnostics()})
			_phase("publication-" + stage + "-finished")
			return
		if Time.get_ticks_msec() >= next_checkpoint:
			_checkpoint("publication-progress", {"stage": stage, "wait_ms": Time.get_ticks_msec() - began})
			next_checkpoint = Time.get_ticks_msec() + CHECKPOINT_INTERVAL_MS
	publication_waits.append({"stage": stage, "milliseconds": Time.get_ticks_msec() - began, "start": started, "end": _stamp(), "diagnostics": flora.streaming_diagnostics(), "timed_out": true})
	_expect(false, "Normal flora publication exceeded 90 s: " + str(flora.streaming_diagnostics()))
	_phase("publication-" + stage + "-timed-out")

func _targets(scene: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for patch_data: Dictionary in scene.flora.patches.values():
		var patch: Node3D = patch_data.node
		for visual: MultiMeshInstance3D in patch.get_children():
			var asset: String = visual.get_meta("asset")
			if not Checks.PROBES.has(asset): continue
			for index in range(visual.multimesh.instance_count):
				var transform: Transform3D = _submitted_transform(visual, index)
				var distance: float = (patch.position + transform.origin).distance_to(scene.adapter.to_local(state.get_current_body_record().surface_context.spawn))
				if result.has(asset) and distance >= result[asset].distance: continue
				result[asset] = {"patch": patch, "cell": patch_data.cell.id, "transform": transform,
					"variant": int(visual.get_meta("variant")), "distance": distance}
	return result

func _submitted_transform(visual: MultiMeshInstance3D, index: int) -> Transform3D:
	# The dummy renderer returns identity from get_instance_transform() after a
	# bulk upload. Read the exact CPU payload in both renderers, as the existing
	# surface publication contract does; never invent headless placements.
	var values: PackedFloat32Array = visual.multimesh.buffer
	var offset: int = index * 16
	var frame := Basis(Vector3(values[offset], values[offset + 4], values[offset + 8]),
		Vector3(values[offset + 1], values[offset + 5], values[offset + 9]),
		Vector3(values[offset + 2], values[offset + 6], values[offset + 10]))
	var result := Transform3D(frame, Vector3(values[offset + 3], values[offset + 7], values[offset + 11]))
	if capture: _expect(result.is_equal_approx(visual.multimesh.get_instance_transform(index)), "GPU instance differs from submitted CPU transform")
	return result

func _setup_motion(scene: Node3D) -> void:
	actor = CharacterBody3D.new()
	actor.collision_layer = 8
	actor.collision_mask = 2
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.12
	capsule.height = 0.35
	collider.shape = capsule
	actor.add_child(collider)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = capsule.radius
	capsule_mesh.height = capsule.height
	mesh.mesh = capsule_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffc05c")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Diagnostic overlay only: foliage/actors must not hide the measured stop.
	# Physics still uses the exact capsule dimensions above.
	material.no_depth_test = true
	mesh.material_override = material
	actor.add_child(mesh)
	scene.add_child(actor)
	observer = Camera3D.new()
	observer.fov = 55
	observer.far = 24.0
	scene.add_child(observer)
	if capture:
		observer.make_current()
		var layer := CanvasLayer.new()
		layer.layer = 200
		scene.add_child(layer)
		label = Label.new()
		label.position = Vector2(16, 16)
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		layer.add_child(label)

func _sweep(scene: Node3D, asset: String, target: Dictionary, stage: String, record: bool) -> void:
	print("INT30_SWEEP ", asset, " ", stage, " start")
	_phase("sweep-" + asset + "-" + stage + "-start")
	var transform: Transform3D = target.transform
	var frame: Basis = transform.basis.orthonormalized()
	var point: Vector3 = Checks.PROBES[asset][target.variant][-1]
	var centre: Vector3 = target.patch.position + transform * point
	var query := PhysicsRayQueryParameters3D.create(centre + frame.x * 3, centre - frame.x * 3, 2)
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(hit.get("collider") == target.patch, "Canonical generated ray missed " + asset + "/" + stage)
	actor.global_transform = Transform3D(frame, centre + frame.x * 3)
	var contacts: int = 0
	observer.position = centre + frame.z * 7 + frame.y * 1.3 + frame.x * 2
	observer.look_at(centre, frame.y)
	var count: int = 30 if record else 1
	if record:
		label.text = "%s | scale %.2f | %s\nOrange physics capsule; overlay visible through foliage" % [asset, transform.basis.get_scale().y, stage]
	for step in range(count):
		var frame_started: Dictionary = _stamp()
		var began: int = Time.get_ticks_usec()
		await tree.physics_frame
		var physics_wait_ms: float = (Time.get_ticks_usec() - began) / 1000.0
		var motion: KinematicCollision3D = actor.move_and_collide(-frame.x * (6.0 / count))
		if motion != null and motion.get_collider() == target.patch: contacts += 1
		if record:
			# Only requested evidence frames are rendered. Software GL must not
			# spend the campaign preparation guard drawing hundreds of loading
			# frames; simulation and normal publication continue unchanged.
			began = Time.get_ticks_usec()
			await tree.process_frame
			var process_wait_ms: float = (Time.get_ticks_usec() - began) / 1000.0
			_capture_trace(asset, stage, step, "force-draw-start")
			began = Time.get_ticks_usec()
			RenderingServer.force_draw(false)
			var force_draw_ms: float = (Time.get_ticks_usec() - began) / 1000.0
			_capture_trace(asset, stage, step, "readback-start")
			began = Time.get_ticks_usec()
			var image: Image = tree.root.get_texture().get_image()
			var readback_ms: float = (Time.get_ticks_usec() - began) / 1000.0
			_capture_trace(asset, stage, step, "png-start")
			began = Time.get_ticks_usec()
			var saved: Error = image.save_png("user://int30-collision-%s-%03d.png" % [asset, step])
			var png_ms: float = (Time.get_ticks_usec() - began) / 1000.0
			_expect(saved == OK, "Capture write failed")
			var timing: Dictionary = {"asset": asset, "stage": stage, "step": step, "start": frame_started, "end": _stamp(),
				"physics_wait_ms": physics_wait_ms, "process_wait_ms": process_wait_ms, "force_draw_ms": force_draw_ms,
				"readback_ms": readback_ms, "png_ms": png_ms, "png_error": saved}
			if evidence.capture_frames.size() < MAX_CAPTURE_FRAMES: evidence.capture_frames.append(timing)
			print("INT30_CAPTURE_FRAME ", JSON.stringify(timing))
			if step in [0, 15, 29]: _checkpoint("capture-progress", {"asset": asset, "stage": stage, "step": step})
	_expect(contacts > 0, "Canonical generated motion passed through " + asset + "/" + stage)
	var address: Dictionary = Cube.from_cartesian(scene.terrain.surface.body.id,
		Cube.global_position(target.patch.position + transform.origin, scene.terrain.origin), scene.terrain.surface.body.radius)
	var slope: float = rad_to_deg(acos(clampf(scene.adapter.sample(address).normal.dot(scene.adapter.up_at(address)), -1, 1)))
	evidence.targets.append({"asset": asset, "variant": target.variant, "cell": target.cell, "stage": stage,
		"scale": transform.basis.get_scale().y, "slope_degrees": slope, "contacts": contacts, "ray": hit.get("collider") == target.patch})
	print("INT30_SWEEP ", asset, " ", stage, " finished; contacts=", contacts)
	_phase("sweep-" + asset + "-" + stage + "-finished")

func _snapshot(flora: Node, stage: String) -> void:
	var shapes: int = 0
	var meshes: int = 0
	for data: Dictionary in flora.patches.values():
		shapes += data.node.shape_count
		meshes += data.node.get_child_count()
		_expect(data.node.shape_count == data.node.get_shape_owners().size(), "Compound shape/owner count diverged")
		_expect(data.node.shape_count <= 24 and data.node.get_child_count() <= 7, "Per-cell collision/mesh budget exceeded")
	_expect(flora.patches.size() <= 25 and flora.max_publish_units <= 1, "Unbounded publication or compound roots")
	evidence.snapshots.append({"stage": stage, "bodies": flora.patches.size(), "shapes": shapes, "meshes": meshes,
		"diagnostics": flora.streaming_diagnostics()})
	_checkpoint("snapshot", {"stage": stage})

func _stamp() -> Dictionary:
	return {"wall_ms": Time.get_ticks_usec() / 1000.0, "elapsed_ms": (Time.get_ticks_usec() - _diagnostic_started_usec) / 1000.0,
		"process_frames": Engine.get_process_frames(), "physics_frames": Engine.get_physics_frames()}

func _phase(name: String, details: Dictionary = {}) -> void:
	_phase_name = name
	_checkpoint("phase", details)

func _checkpoint(event: String, details: Dictionary = {}) -> void:
	if evidence.is_empty(): return
	if _flora_trace_enabled: evidence.publication_trace = _flora_trace_summary()
	var entry: Dictionary = {"phase": _phase_name, "event": event, "time": _stamp(), "context": _cached_context(), "details": details}
	if evidence.phase_records.size() < MAX_PHASE_RECORDS: evidence.phase_records.append(entry)
	else: evidence.dropped_phase_records += 1
	evidence.last_checkpoint = entry
	evidence.phase = _phase_name
	evidence.failures = failures.duplicate()
	# Even a failure-free partial route is never successful evidence. This copy
	# remains valid if the outer process guard kills a draw or a later await.
	var progress: Dictionary = evidence.duplicate(true)
	progress.complete = false
	progress.passed = false
	progress.status = "incomplete" if failures.is_empty() else "failed_incomplete"
	var began: int = Time.get_ticks_usec()
	var error: Error = Atomic.write(PROGRESS_PATH, progress, false)
	evidence.last_checkpoint_write_ms = (Time.get_ticks_usec() - began) / 1000.0
	if error != OK:
		var message: String = "Collision progress checkpoint write failed: " + error_string(error)
		failures.append(message)
		push_error(message)
	print("INT30_CHECKPOINT ", JSON.stringify(entry))

func _flora_trace(operation: String, edge: String, cell_id: String, asset_id: String,
		batch_index: int, variant: int, path: String) -> void:
	var now: int = Time.get_ticks_usec()
	var key: String = "%s|%s|%d|%s|%s" % [cell_id, asset_id, batch_index, path, operation]
	var elapsed_ms: float = -1.0
	if edge == "start": _flora_trace_started[key] = now
	elif _flora_trace_started.has(key):
		elapsed_ms = (now - int(_flora_trace_started[key])) / 1000.0
		_flora_trace_started.erase(key)
		_flora_trace_counts[operation] = int(_flora_trace_counts.get(operation, 0)) + 1
		_flora_trace_max_ms[operation] = maxf(float(_flora_trace_max_ms.get(operation, 0.0)), elapsed_ms)
	if _flora_trace_events >= MAX_FLORA_TRACE_EVENTS:
		_flora_trace_dropped += 1
		if edge == "start": _flora_trace_started[key] = Time.get_ticks_usec()
		return
	_flora_trace_events += 1
	var event: Dictionary = {"sequence": _flora_trace_events, "phase": _phase_name, "operation": operation,
		"edge": edge, "cell": cell_id, "asset": asset_id, "batch": batch_index, "variant": variant,
		"path": path, "wall_us": now, "process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames()}
	if elapsed_ms >= 0.0: event.duration_ms = elapsed_ms
	_flora_trace_recent.append(event)
	if _flora_trace_recent.size() > FLORA_TRACE_RECENT: _flora_trace_recent.pop_front()
	# The log gives exact entry/exit pairs even when the process guard interrupts
	# a blocking renderer call. Keep the additional durable checkpoints bounded.
	print("INT30_FLORA_TRACE ", JSON.stringify(event))
	var first_key: String = _phase_name + "|" + operation
	var first: bool = not _flora_trace_first.has(first_key)
	if first: _flora_trace_first[first_key] = true
	var now_ms: int = now / 1000
	if _flora_trace_writes >= MAX_FLORA_TRACE_CHECKPOINTS or (not first and now_ms - _flora_trace_last_write_ms < 2000):
		if edge == "start": _flora_trace_started[key] = Time.get_ticks_usec()
		return
	var checkpoint: Dictionary = _flora_trace_summary()
	checkpoint.recent = _flora_trace_recent.duplicate(true)
	checkpoint.active = _flora_trace_started.keys()
	checkpoint.complete = false
	var began: int = Time.get_ticks_usec()
	var error: Error = Atomic.write(FLORA_TRACE_PATH, checkpoint, false)
	_flora_trace_write_ms += (Time.get_ticks_usec() - began) / 1000.0
	_flora_trace_writes += 1
	_flora_trace_last_write_ms = Time.get_ticks_msec()
	if error != OK:
		_flora_trace_write_errors += 1
		push_error("Flora publication trace checkpoint write failed: " + error_string(error))
	# Exclude logging and atomic checkpoint cost from the measured native call.
	if edge == "start": _flora_trace_started[key] = Time.get_ticks_usec()

func _flora_trace_summary() -> Dictionary:
	return {"schema": 1, "events": _flora_trace_events, "dropped": _flora_trace_dropped,
		"checkpoints": _flora_trace_writes, "checkpoint_write_ms": _flora_trace_write_ms,
		"write_errors": _flora_trace_write_errors, "max_ms": _flora_trace_max_ms.duplicate(),
		"completed_operations": _flora_trace_counts.duplicate(),
		"limits": {"events": MAX_FLORA_TRACE_EVENTS, "checkpoints": MAX_FLORA_TRACE_CHECKPOINTS,
			"recent": FLORA_TRACE_RECENT}}

func _cached_context() -> Dictionary:
	var scene: Node = tree.current_scene
	if not is_instance_valid(scene) or scene.scene_file_path != Surface.SCENE: return {}
	var context: Dictionary = {}
	if is_instance_valid(scene.player): context.player_address = scene.player.location().duplicate(true)
	if is_instance_valid(scene.flora):
		context.flora = scene.flora.streaming_diagnostics()
		context.wanted_cell_ids = scene.flora.wanted.keys()
		context.published_cell_ids = scene.flora.patches.keys()
		context.flora.max_worker_ms = scene.flora.max_worker_ms
		context.flora.max_publish_ms = scene.flora.max_publish_ms
		context.flora.max_frame_work_ms = scene.flora.max_frame_work_ms
	if is_instance_valid(scene.scenery): context.scenery = scene.scenery.diagnostics()
	if is_instance_valid(scene.population):
		var population: Node = scene.population
		var store: RefCounted = population.storage.store
		var generated: int = 0
		# Inspect only resident payloads and existing counters. region()/record()
		# would load pages, mark them dirty and reorder the shared LRU.
		for key: String in store.cache:
			if key.begins_with("r:") and store.cache[key].get("generated", false): generated += 1
		context.population = {"generation_cursor": population._generation_cursor, "spawn_after_generation": population._spawn_after_generation,
			"last_spawn_attempts": population.last_spawn_attempts, "max_frame_work_ms": population.max_frame_work_ms,
			"max_tick_stage_ms": population.max_tick_stage_ms.duplicate(), "max_spawn_stage_ms": population.max_spawn_stage_ms.duplicate(),
			"resident_generated_regions": generated, "animals": population.animals.size(), "plants": population.plants.size(), "nests": population.nests.size(),
			"store": {"reads": store.reads, "writes": store.writes, "max_io_ms": store.max_io_usec / 1000.0,
				"cache": store.cache.size(), "pages": store.pages.size(), "dirty": store.dirty.size(), "pinned": store.pinned.size(), "peak_cache": store.peak_cache}}
	return context

func _capture_trace(asset: String, stage: String, step: int, operation: String) -> void:
	print("INT30_CAPTURE_OPERATION ", JSON.stringify({"asset": asset, "stage": stage, "step": step, "operation": operation, "time": _stamp()}))

func _expect(condition: bool, message: String) -> void:
	if condition: return
	super._expect(condition, message)
	push_error(message)
	print("INT30_ASSERTION_FAILED ", JSON.stringify({"phase": _phase_name, "time": _stamp(), "message": message}))
	if Time.get_ticks_msec() - _last_failure_checkpoint >= CHECKPOINT_INTERVAL_MS:
		_last_failure_checkpoint = Time.get_ticks_msec()
		_checkpoint("assertion-failed", {"message": message})

func _finish() -> void:
	if _flora_trace_enabled: FloraAssets.publication_trace_sink = Callable()
	tree.paused = false
	_phase("shutdown-start")
	# The shared shutdown releases audio before requesting exit. Its coroutine
	# returns in the same callback; commit final bytes synchronously afterward.
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if _route_complete and failures.is_empty() else 1)
	_phase("finished")
	evidence.complete = _route_complete
	evidence.passed = _route_complete and failures.is_empty()
	evidence.status = ("passed" if evidence.passed else "failed") if _route_complete else "failed_incomplete"
	evidence.failures = failures.duplicate()
	_expect(Atomic.write("user://int30-collision-world.json", evidence, false) == OK, "Collision final evidence write failed")
	evidence.passed = _route_complete and failures.is_empty()
	evidence.status = ("passed" if evidence.passed else "failed") if _route_complete else "failed_incomplete"
	print("INT30_SCENERY_WORLD ", JSON.stringify({"passed": evidence.passed, "failures": failures.size(), "evidence": evidence}))
	# Retain a nonzero engine result even for an assertion-free incomplete route
	# or a diagnostic write failure after the shared shutdown requested exit.
	tree.quit(0 if evidence.passed else 1)
