extends "res://core/diagnostics/spherical_campaign_probe.gd"
## Public campaign entry, canonical generated flora, real capsule motion.
const Checks = preload("res://tests/int30_scenery_collision_test.gd")
const Stats = preload("res://tools/performance_stats.gd")
var evidence: Dictionary = {}
var capture: bool = false
var actor: CharacterBody3D
var observer: Camera3D
var label: Label
var samples: Array = []
var publication_waits: Array[Dictionary] = []

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("INT30 Umgebungskollision", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	var start: Dictionary = scene.player.location().duplicate(true)
	var flora: Node = scene.flora
	print("INT30_PHASE publication-start")
	await _wait_patches(flora)
	print("INT30_PHASE targets-start")
	var targets: Dictionary = _targets(scene)
	print("INT30_PHASE targets-ready ", targets.keys())
	_expect(targets.size() == 4, "Canonical seed did not publish all four solid families")
	evidence = {"seed": 15838, "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"cpu": OS.get_processor_name(), "adapter": RenderingServer.get_video_adapter_name(), "targets": [], "snapshots": [], "publication_waits": publication_waits}
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
	_move_observer(scene, scene.adapter.offset(start, scene.adapter.frame_at(start).x * 360, 1.1))
	flora._refresh()
	var retire_deadline: int = Time.get_ticks_msec() + 2000
	while references.any(func(r: WeakRef): return r.get_ref() != null) and Time.get_ticks_msec() < retire_deadline:
		await tree.process_frame
	_expect(references.all(func(r: WeakRef): return r.get_ref() == null), "Streaming retained a retired compound body")
	await _wait_patches(flora)
	_snapshot(flora, "far")
	_move_observer(scene, start)
	flora._refresh()
	await _wait_patches(flora)
	var returned: Dictionary = _targets(scene)
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
	await _wait_patches(flora)
	for i in range(180):
		await tree.physics_frame
		samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
	evidence.physics_monitor_ms = Stats.distribution(samples)
	evidence.physics_note = Stats.metric_notes().physics_monitor_ms + " Linux container measurement, not target-PC FPS."
	evidence.passed = failures.is_empty()
	var file := FileAccess.open("user://int30-collision-world.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	returned.clear()
	flow.return_to_title()
	await tree.scene_changed
	await _finish()

func _move_observer(scene: Node3D, address: Dictionary) -> void:
	# Follow the normal asynchronous streaming path. player.place() is the
	# arrival/load operation and would synchronously rebuild full terrain for
	# every 4 m diagnostic reposition, obscuring scenery/physics costs.
	scene.adapter.place(scene.player, address)
	if scene.player.position.length() > 64:
		scene.terrain.rebase(Cube.cartesian(address, scene.terrain.surface.body.radius))
	scene.terrain.stream_at(scene.adapter.up_at(address))

func _wait_patches(flora: Node) -> void:
	var began: int = Time.get_ticks_msec()
	# This is a finite fixture preparation guard, not a target-PC latency gate.
	# The cold shared asset/publish budget measured only 15/25 cells at 45 s on
	# the busy container. Preserve that observation and record actual waits.
	# Functional assertions and the one-unit/25-body/24-shape limits stay exact.
	while Time.get_ticks_msec() - began < 90000:
		await tree.process_frame
		if flora.patches.size() == flora.wanted.size() and flora._publication.is_empty() and flora._task < 0:
			publication_waits.append({"milliseconds": Time.get_ticks_msec() - began, "diagnostics": flora.streaming_diagnostics()})
			return
	publication_waits.append({"milliseconds": Time.get_ticks_msec() - began, "diagnostics": flora.streaming_diagnostics(), "timed_out": true})
	_expect(false, "Normal flora publication exceeded 90 s: " + str(flora.streaming_diagnostics()))

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
		await tree.physics_frame
		var motion: KinematicCollision3D = actor.move_and_collide(-frame.x * (6.0 / count))
		if motion != null and motion.get_collider() == target.patch: contacts += 1
		if record:
			# Only requested evidence frames are rendered. Software GL must not
			# spend the campaign preparation guard drawing hundreds of loading
			# frames; simulation and normal publication continue unchanged.
			await tree.process_frame
			RenderingServer.force_draw(false)
			var image: Image = tree.root.get_texture().get_image()
			_expect(image.save_png("user://int30-collision-%s-%03d.png" % [asset, step]) == OK, "Capture write failed")
	_expect(contacts > 0, "Canonical generated motion passed through " + asset + "/" + stage)
	var address: Dictionary = Cube.from_cartesian(scene.terrain.surface.body.id,
		Cube.global_position(target.patch.position + transform.origin, scene.terrain.origin), scene.terrain.surface.body.radius)
	var slope: float = rad_to_deg(acos(clampf(scene.adapter.sample(address).normal.dot(scene.adapter.up_at(address)), -1, 1)))
	evidence.targets.append({"asset": asset, "variant": target.variant, "cell": target.cell, "stage": stage,
		"scale": transform.basis.get_scale().y, "slope_degrees": slope, "contacts": contacts, "ray": hit.get("collider") == target.patch})
	print("INT30_SWEEP ", asset, " ", stage, " finished; contacts=", contacts)

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

func _finish() -> void:
	tree.paused = false
	for failure in failures: push_error(failure)
	print("INT30_SCENERY_WORLD ", JSON.stringify({"passed": failures.is_empty(), "failures": failures.size(), "evidence": evidence}))
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
