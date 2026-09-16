extends "tribal_playtest_test.gd"
## Real public sphere entry: stored goods follow terrain and a live pointer.
const Space = preload("res://world/surface/gameplay_space.gd")

func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(Playtest.start(flow), "Cannot start sphere stockpile test.")
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
	_expect(saves.save_now(), "Sphere stockpile fixture does not conserve resources: " + saves.last_error)
	tribe.select_all()
	_expect(tribe.issue_order("wait"), "Cannot refresh actual sphere inventory.")
	var piles: Node3D = tribe._visuals.stockpiles
	failures.append_array(await preload("res://core/diagnostics/stockpile_checks.gd").verify(tribe))
	for kind: String in piles.lots:
		var lot: Node3D = piles.lots[kind].root
		_expect(lot.global_basis.y.dot(Space.up(tribe, lot.global_position)) > 0.9999, "Stockpile ignores surface normal: " + kind)
		var hit: Dictionary = Space.floor_hit(piles, lot.global_position, 2.0, 4.0)
		_expect(not hit.is_empty() and lot.global_position.distance_to(hit.position) < 0.03, "Floating or buried stockpile: " + kind)
	var before: Dictionary = data.duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(saves.save_path)
	var motion := InputEventMouseMotion.new()
	motion.position = tribe.camera.unproject_position(piles.lots.wood.root.global_position)
	root.push_input(motion, true)
	for frame in range(20):
		await physics_frame
		await process_frame
	_expect(piles.hovered_resource == "wood" and piles._caption.visible, "Sphere storage hover failed.")
	_expect(data == before and FileAccess.get_file_as_string(saves.save_path) == bytes, "Stockpile inspection changed the campaign.")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		var directory: String = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("stockpile-sphere.png"))
	if failures.is_empty(): print("TRIBAL_STOCKPILE_WORLD_PASSED")
	await _finish()
