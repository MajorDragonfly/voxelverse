extends SceneTree
## Verify that the normal fauna streamer instantiates the new brain on actual
## generated terrain, retaining population bounds and the existing scene API.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		root.size = Vector2i(960, 600)
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://wildlife_ai_world_test.json"
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	change_scene_to_file("res://core/diagnostics/legacy_world.tscn")
	await scene_changed
	var player: CharacterBody3D = current_scene.get_node("Player")
	player.set_process(false)
	player.set_physics_process(false)
	player.current_health = 100000.0
	var fauna: Array[Node] = []
	for frame in range(1200):
		await physics_frame
		await process_frame
		fauna = get_nodes_in_group(&"wildlife")
		if fauna.size() >= 8 and current_scene.get_node("WorldManager").world_initialized:
			break
	_expect(fauna.size() >= 8, "Normal main streamer did not populate wildlife.")
	var starting: Dictionary = {}
	for creature in fauna:
		_expect(creature.has_method("get_ai_debug_state"), "A real streamed creature bypassed the new AI.")
		starting[creature.get_instance_id()] = creature.global_position
	for frame in range(120 if "--capture" in args else 300):
		await physics_frame
		await process_frame
	var moved: int = 0
	var grounded: int = 0
	var states: Dictionary = {}
	fauna = get_nodes_in_group(&"wildlife")
	for creature in fauna:
		if starting.has(creature.get_instance_id()) and creature.global_position.distance_to(starting[creature.get_instance_id()]) > 0.6:
			moved += 1
		if creature.is_on_floor():
			grounded += 1
		var intent: String = creature.get_ai_debug_state()["state"]
		states[intent] = int(states.get(intent, 0)) + 1
		_expect(creature.get_campaign_identity().has("object_id") and creature.get_inspection_data().has("species_seed"), "AI discarded identity or inspection APIs.")
	_expect(moved >= 2, "Actual terrain left all but one animal stuck.")
	_expect(grounded >= 5, "Actual terrain did not support most animals.")
	_expect(fauna.size() <= int(current_scene.get_node("FaunaStreamerV7").maximum_population), "AI bypassed the existing population budget.")
	if "--capture" in args:
		var directory: String = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(directory)
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.global_position = player.global_position + Vector3(12, 12, 19)
		camera.look_at(player.global_position + Vector3.UP)
		camera.make_current()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("05_world.png"))
	_expect(saves.save_now() and saves.load_now(), "AI prevented ordinary main save/load.")
	for frame in range(12):
		await process_frame
	current_scene.queue_free()
	for frame in range(5):
		await process_frame
	print(JSON.stringify({"test": "wildlife_ai_world", "passed": failures.is_empty(), "population": fauna.size(), "moved": moved, "grounded": grounded, "states": states, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
