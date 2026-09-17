extends "res://core/diagnostics/spherical_campaign_probe.gd"

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("Fernsicht", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	var scenery: Node = scene.scenery
	_expect(scenery.generation_complete and scenery._active.instances > 40, "Campaign entered before distant scenery was visible")
	_expect(scenery._active.node.get_child_count() <= 48, "Distant scenery creates unbounded draw batches")
	for visual in scenery._active.node.get_children():
		_expect(visual is MultiMeshInstance3D and visual.get_child_count() == 0, "Distant scenery creates actors or colliders")
	var initial: Dictionary = scenery.diagnostics()
	for frame in range(180):
		await tree.process_frame
		_expect(scenery.last_publish_units + scene.flora.last_publish_units <= 1, "Near and distant flora submit in the same frame")
	# Match masks to actual published patches, never to requested/prepared data.
	# Inspect the uploaded CPU image too: the headless dummy renderer cannot
	# read ImageTextures back from a GPU. Graphical runs check the real texture.
	var image: Image = scenery._active.ownership_image if DisplayServer.get_name() == "headless" else scenery._active.ownership.get_image()
	for i in range(scenery._active.cell_ids.size()):
		_expect((image.get_pixel(i, 0).r > 0.5) == scene.flora.patches.has(scenery._active.cell_ids[i]), "Near/distant ownership leaves holes or duplicate trees")
	var anchor: Array = scenery._active.anchor
	var before: Array = Cube.global_position(scenery._active.node.position, scene.terrain.origin)
	scene.terrain.rebase([anchor[0] + 80.0, anchor[1] - 29.0, anchor[2] + 65.0])
	_expect(Cube.local_position(Cube.global_position(scenery._active.node.position, scene.terrain.origin), before).length() < 0.002, "Floating origin moved distant scenery")
	flow.toggle_pause()
	var paused_state: Dictionary = scenery.diagnostics()
	for frame in range(6): await tree.process_frame
	_expect(scenery.diagnostics() == paused_state, "Pause advanced distant scenery")
	flow.resume()
	await _capture(scene, "distance-start")
	# Rebuild during walking; old complete scenery remains until the new set exists.
	var start: Dictionary = scene.player.location()
	var target: Dictionary = scene.adapter.offset(start, scene.adapter.frame_at(start).x * 40.0, 1.1)
	scene.player.place(target)
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 20000:
		await tree.process_frame
		_expect(scenery._active.node.visible, "Recentering removed the complete old scenery")
		if scenery._active.anchor != anchor: break
	_expect(scenery._active.anchor != anchor, "Distant scenery did not follow the observer")
	print("SURFACE_DISTANCE_WORLD ", JSON.stringify({"initial": initial, "after_move": scenery.diagnostics()}))
	# Leave with a real CPU job still owned by the world, not just an idle cache.
	scene.player.place(scene.adapter.offset(scene.player.location(), scene.adapter.frame_at(scene.player.location()).x * 40.0, 1.1))
	scenery._process(0.0)
	_expect(scenery._task >= 0, "Teardown fixture did not start its scenery worker")
	flow.return_to_title()
	await tree.scene_changed
	_expect(not is_instance_valid(scenery), "Returning to the menu retained scenery workers/nodes")
	await _finish()

func _capture(scene: Node3D, label: String) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not "--capture" in args or DisplayServer.get_name() == "headless": return
	var output: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(output)
	scene.player.set_physics_process(false)
	var frame: Basis = scene.adapter.frame_at(scene.player.location())
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = scene.player.position + frame.y * 5.0 + frame.z * 12.0
	camera.far = 30000.0
	camera.look_at(scene.player.position - frame.z * 180.0 + frame.y * 5.0, frame.y)
	camera.make_current()
	for i in range(5): await tree.process_frame
	await RenderingServer.frame_post_draw
	_expect(tree.root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "Cannot save distant scenery capture")
	camera.queue_free()
	scene.player.camera.make_current()
	scene.player.set_physics_process(true)

func _finish() -> void:
	tree.paused = false
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SURFACE_DISTANCE_WORLD_PASSED: entry, budgets, ownership, rebase, pause, movement and active-worker teardown.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
