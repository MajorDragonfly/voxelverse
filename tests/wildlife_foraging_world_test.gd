extends SceneTree
## Real main scene, actual terrain collision and normal interactive-food stream.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://foraging_world_test.json"
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	change_scene_to_file("res://core/diagnostics/legacy_world.tscn")
	await scene_changed
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		root.size = Vector2i(960, 600)
	var player: CharacterBody3D = current_scene.get_node("Player")
	player.current_health = 100000.0
	var plants: Array[Node] = []
	for frame in range(1200):
		await _frames(1)
		plants = get_nodes_in_group(&"wildlife_plant_food")
		# Keep natural consumers from exhausting this coastal fixture before
		# the controlled approach starts. Ambient AI has its own world test.
		for creature in get_nodes_in_group(&"wildlife"):
			creature.set_physics_process(false)
		if plants.size() >= 2 and current_scene.get_node("WorldManager").world_initialized and get_nodes_in_group(&"wildlife").size() >= 3:
			break
	_expect(plants.size() >= 2, "Normal coastal main scene did not stream interactive plants: " + str(plants.size()))
	var streamer: Node3D = current_scene.get_node("Nest/PlantFoodStreamer")
	_expect(streamer._plants.size() <= streamer.MAXIMUM, "Food stream exceeded its population budget.")
	current_scene.get_node("FaunaStreamerV7").set_process(false)
	# Hold other creatures still and remove their threat group for a controlled
	# terrain feeding fixture; their normal behavior has its own integration test.
	for creature in get_nodes_in_group(&"wildlife"):
		creature.set_physics_process(false)
		creature.remove_from_group(&"wildlife")
	player.set_physics_process(false)
	player.is_dead = true
	var wildlife: PackedScene = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	var animal: CharacterBody3D = wildlife.instantiate()
	animal.configure(771, 440, Vector2i.ZERO, "grazer")
	current_scene.add_child(animal)
	animal.set_physics_process(false)
	var chosen: Node3D
	for plant in plants:
		if not plant.has_food_available():
			continue
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var offset := Vector3(cos(angle), 0, sin(angle)) * 4.2
			var candidate: Vector3 = plant.global_position + offset
			candidate.y = root.get_node("WorldGenerator").get_visual_terrain_height(candidate.x, candidate.z)
			animal.global_position = candidate + Vector3.UP * 0.05
			var ground: Dictionary = animal.Steering.ground(animal, animal.global_position)
			if not ground.is_empty() and ground["normal"].dot(Vector3.UP) > 0.9 and animal.Steering.clear_sight(animal, plant) and animal.Steering.safe_direction(animal, -offset.normalized(), animal.maximum_step_height):
				animal.global_position.y = ground["position"].y + 0.05
				chosen = plant
				break
		if chosen != null:
			break
	_expect(chosen != null, "No clear loaded terrain position beside an actual streamed plant.")
	var consumed: float = 0.0
	if chosen != null:
		var heading: Vector3 = chosen.global_position - animal.global_position
		animal._visual_root.rotation.y = atan2(-heading.x, -heading.z)
		animal.satiety = 60.0
		animal._needs["satiety"] = 60.0
		animal._needs["seeking"] = true
		animal._ambient_heading = Vector3.ZERO
		animal._decision_timer = 100.0
		animal.set_physics_process(true)
		var before: float = chosen.get_food_remaining()
		for frame in range(300):
			await _frames(1)
			if chosen.get_food_remaining() < before:
				break
		consumed = before - chosen.get_food_remaining()
		_expect(consumed > 0.0 and animal.satiety > 60.0 and animal.is_on_floor(), "Animal failed to physically approach/eat a normal terrain plant: " + str(animal.get_ai_debug_state()))
		if "--capture" in args:
			var directory: String = args[args.find("--capture") + 1]
			DirAccess.make_dir_recursive_absolute(directory)
			var camera := Camera3D.new()
			current_scene.add_child(camera)
			camera.global_position = chosen.global_position + Vector3(5, 4, 7)
			camera.look_at((chosen.global_position + animal.global_position) * 0.5 + Vector3.UP * 0.8)
			camera.make_current()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("04_world_feeding.png"))
		animal.set_physics_process(false)
		var stock: float = chosen.get_food_remaining()
		var point: Vector3 = chosen.global_position
		var hunger: float = animal.satiety
		_expect(saves.save_now() and saves.load_now(), "Terrain feeding prevented ordinary save/load.")
		await _frames(6)
		_expect(is_equal_approx(animal.satiety, hunger), "Loaded terrain animal lost satiety.")
		var restored: bool = false
		for frame in range(400):
			await _frames(1)
			for plant in get_nodes_in_group(&"wildlife_plant_food"):
				if plant.global_position.distance_to(point) < 0.1 and plant.get_food_remaining() == stock:
					restored = true
			if restored:
				break
		_expect(restored, "Food stream did not recreate the saved partial stock.")
	current_scene.queue_free()
	await _frames(5)
	print(JSON.stringify({"test": "wildlife_foraging_world", "passed": failures.is_empty(), "plants": plants.size(), "consumed": consumed, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: " + message)
