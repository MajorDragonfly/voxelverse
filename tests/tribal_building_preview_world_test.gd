extends "tribal_playtest_test.gd"
## The public sphere entry, with a real camera ray and radial building frame.
const Space = preload("res://world/surface/gameplay_space.gd")

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(Playtest.start(flow), "Cannot start sphere preview test.")
	await _until(func() -> bool:
		var t: Node = current_scene.get_node_or_null("Nest/Tribe")
		return t != null and t.panel.confirmation_open, 90000)
	var tribe: Node = current_scene.get_node_or_null("Nest/Tribe")
	if tribe == null or not tribe.panel.confirmation_open:
		_expect(false, "Sphere tribal setup did not complete.")
		await _finish()
		return
	saves.autosave_enabled = false
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 20000)
	_expect(tribe.is_active(), "Sphere tribe did not activate.")
	if not tribe.is_active():
		await _finish()
		return
	tribe.set_process(false)
	tribe.set_physics_process(false)
	var data: Dictionary = tribe.village()
	data.tools = 1
	for resource: String in ["wood", "stone"]:
		data.deposits[resource].remaining = 0
		data.stock[resource] = 16
	_expect(saves.save_now(), "Sphere preview fixture does not conserve resources: " + saves.last_error)
	var before: Dictionary = data.duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(saves.save_path)
	tribe.select_all()
	_expect(tribe.issue_order("hut"), "Sphere hut placement did not start.")
	var point: Vector3 = Vector3.INF
	for saved_site: Variant in data.sites:
		var candidate: Vector3 = Space.resolve(tribe, saved_site)
		var hit: Dictionary = tribe.ground_hit(tribe.camera.unproject_position(candidate))
		if not hit.is_empty() and tribe.placement_check("hut", hit.position).ok:
			point = hit.position
			break
	_expect(point.is_finite(), "No reachable sphere site found through the camera ray.")
	if point.is_finite():
		var motion := InputEventMouseMotion.new()
		motion.position = tribe.camera.unproject_position(point)
		root.push_input(motion, true)
		for frame in range(12):
			await physics_frame
			await process_frame
		var ghost: Node3D = tribe.building_preview
		_expect(ghost.visible and ghost.result.get("ok", false), "Sphere pointer has no valid preview: " + str(ghost.result))
		_expect(ghost.global_basis.y.dot(Space.up(tribe, ghost.global_position)) > 0.9999, "Ghost does not follow the planetary surface normal.")
		_expect(ghost.global_position.distance_to(tribe.navigation.snap(point)) < 0.02, "Sphere ghost differs from actual placement snapping.")
		_expect(data == before and FileAccess.get_file_as_string(saves.save_path) == bytes, "Sphere preview mutated the campaign.")
		var args: PackedStringArray = OS.get_cmdline_user_args()
		if "--capture" in args:
			var directory: String = args[args.find("--capture") + 1]
			DirAccess.make_dir_recursive_absolute(directory)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("placement-sphere-free.png"))
	if failures.is_empty(): print("TRIBAL_PREVIEW_WORLD_PASSED")
	await _finish()
