extends SceneTree
## Exercise the actual terrain/nest/main scene, not only a flat test fixture.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://home_world_test.json"
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	change_scene_to_file("res://main/main.tscn")
	await scene_changed
	var home: Node = current_scene.get_node("Nest/HomeGroup")
	for frame in range(1800):
		await physics_frame
		await process_frame
		if home.can_use_panel() and home.player.is_on_floor() and home.has_ground(home.player.global_position) and current_scene.get_node("WorldManager").get_pending_chunk_count() == 0:
			break
	_expect(home.can_use_panel(), "Actual main scene did not enable nest group.")
	if not home.can_use_panel():
		_finish()
		return
	var player: CharacterBody3D = home.player
	player.set_physics_process(false)
	player.set_process(false)
	var origin: Vector3 = player.global_position
	var generator: Node = root.get_node("WorldGenerator")
	var result: Dictionary = {"ok": false}
	for x in range(-16, 17, 2):
		for z in range(-16, 17, 2):
			var point := origin + Vector3(x, 0, z)
			point.y = generator.get_terrain_height(point.x, point.z) + 0.3
			player.global_position = point
			result = home.establish_home()
			if result["ok"]:
				break
		if result["ok"]:
			break
	_expect(result["ok"], "No reachable nest site on generated starting terrain: " + str(result))
	if result["ok"]:
		_expect(home.actors.size() == 2, "Actual main did not instantiate two residents.")
		_expect(home.panel.open_panel(), "Could not open nest panel in main.")
		var args: PackedStringArray = OS.get_cmdline_user_args()
		if "--capture" in args:
			var directory: String = args[args.find("--capture") + 1]
			DirAccess.make_dir_recursive_absolute(directory)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("05_main_panel.png"))
		home.panel.close_panel()
		for frame in range(45):
			await physics_frame
			await process_frame
		for actor in home.actors.values():
			_expect(actor.visible and actor.is_on_floor(), "Resident failed to stand on actual terrain.")
		if "--capture" in args:
			var camera := Camera3D.new()
			current_scene.add_child(camera)
			camera.global_position = home.home_position() + Vector3(8, 7, 12)
			camera.look_at(home.home_position() + Vector3.UP)
			camera.make_current()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(args[args.find("--capture") + 1].path_join("06_main_residents.png"))
		var group: Dictionary = home.group_state().duplicate(true)
		_expect(saves.save_now() and saves.load_now(), "Actual main could not save/load nest.")
		for frame in range(30):
			await physics_frame
			await process_frame
		_expect(home.actors.size() == 2 and home.group_state()["id"] == group["id"], "Main reload replaced group identity.")
	current_scene.queue_free()
	for frame in range(5):
		await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	print(JSON.stringify({"test": "home_group_world", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
