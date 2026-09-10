extends SceneTree
## Full main world with live drainage, terrain streaming and water rendering.

const Shore = preload("res://creatures/ai/shore_water_search.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	var generator: Node = root.get_node("WorldGenerator")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://drinking_world_test.json"
	state.start_world_with_seed(15838)
	await process_frame
	var origin: Vector3 = _inland_bank(generator)
	_expect(origin.is_finite(), "Generator supplied no inland bank fixture.")
	if not origin.is_finite():
		_finish({})
		return
	change_scene_to_file("res://core/diagnostics/legacy_world.tscn")
	await scene_changed
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		root.size = Vector2i(960, 600)
	var player: CharacterBody3D = current_scene.get_node("Player")
	player.position = origin + Vector3.UP * 1.0
	player.is_dead = true
	current_scene.get_node("FaunaStreamerV7").set_process(false)
	var manager: Node = current_scene.get_node("WorldManager")
	manager.choose_scenic_spawn_for_default_start = false
	for frame in range(1000):
		await _frames(1)
		if manager.world_initialized and manager.loaded_chunks.size() >= 9:
			break
	player.set_physics_process(false)
	var animal: CharacterBody3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	animal.configure(771, 880, Vector2i(floori(origin.x / 256.0), floori(origin.z / 256.0)), "grazer")
	current_scene.add_child(animal)
	animal.set_physics_process(false)
	var source: Dictionary = {}
	# Pick a physical starting position on the generated bank. Search uses the
	# production sampler and the live generator; no water provider is substituted.
	for radius in [0.0, 2.5, 5.0, 8.0]:
		for index in range(16):
			var angle: float = float(index) * TAU / 16.0
			var position: Vector3 = origin + Vector3(cos(angle), 0, sin(angle)) * radius
			position.y = generator.get_visual_terrain_height(position.x, position.z) + 0.05
			animal.position = position
			var floor: Dictionary = Shore.dry_floor(animal, generator, position)
			if floor.is_empty():
				continue
			animal.position.y = floor["position"].y + 0.05
			for start in range(0, Shore.SAMPLES, Shore.BATCH):
				var candidate: Dictionary = Shore.find_batch(animal, generator, animal.position, start, {})
				if not candidate.is_empty() and not Shore.can_drink(animal, generator, candidate) and animal.position.distance_to(candidate["bank"]) > 1.0:
					source = candidate
					break
			if not source.is_empty():
				break
		if not source.is_empty():
			break
	_expect(not source.is_empty(), "No loaded, reachable inland-shore candidate near " + str(origin))
	var report: Dictionary = {"origin": str(origin), "water_level": generator.get_water_level(origin.x, origin.z)}
	if not source.is_empty():
		var starting: Vector3 = animal.position
		animal.hydration = 60.0
		animal._drinking["hydration"] = 60.0
		animal._drinking["seeking"] = true
		animal.satiety = 100.0
		animal._needs["satiety"] = 100.0
		animal._needs["seeking"] = false
		animal._ambient_heading = Vector3.ZERO
		animal._decision_timer = 100.0
		animal.set_physics_process(true)
		for frame in range(1200):
			await _frames(1)
			if animal.hydration > 60.0:
				break
		report["hydration"] = animal.hydration
		report["moved"] = animal.position.distance_to(starting)
		report["state"] = animal.ai_state
		report["kind"] = str(animal._water_source.get("kind", ""))
		_expect(animal.hydration > 60.0 and animal.position.distance_to(starting) > 0.5 and animal.is_on_floor(), "Real terrain approach/drinking failed: " + str(animal.get_ai_debug_state()))
		_expect(animal.position.y > generator.get_water_level(animal.position.x, animal.position.z) + 0.15, "Animal entered the water to drink.")
		if "--capture" in args:
			var directory: String = args[args.find("--capture") + 1]
			DirAccess.make_dir_recursive_absolute(directory)
			var camera := Camera3D.new()
			current_scene.add_child(camera)
			camera.global_position = animal.position + Vector3(6, 4, 7)
			camera.look_at(animal.position + Vector3.UP * 0.8)
			camera.make_current()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("03_world_drinking.png"))
		animal.set_physics_process(false)
		var hydration: float = animal.hydration
		_expect(saves.save_now() and saves.load_now() and is_equal_approx(animal.hydration, hydration), "Normal main save/load reset thirst.")
		_expect(animal._water_source.is_empty(), "Main load kept a stale unverified water target.")
	current_scene.queue_free()
	await _frames(5)
	_finish(report)

func _inland_bank(generator: Node) -> Vector3:
	for z in range(-2, 2):
		for x in range(-2, 2):
			var route: Dictionary = generator.get_drainage_region(Vector2i(x, z))
			for lake in route.get("lakes", []):
				if float(lake["level"]) < generator.get_sea_level() + 2.0:
					continue
				for i in range(16):
					var angle: float = float(i) * TAU / 16.0
					var direction: Vector2 = route["direction"] * cos(angle) + route["lateral"] * sin(angle) / 1.2
					var point: Vector2 = lake["center"] + direction * (float(lake["radius"]) + 1.4)
					var level: float = generator.get_water_level(point.x, point.y)
					var height: float = generator.get_terrain_height(point.x, point.y)
					if height > level + 0.25 and height < level + 1.0:
						return Vector3(point.x, height, point.y)
	return Vector3(INF, INF, INF)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: " + message)

func _finish(report: Dictionary) -> void:
	report.merge({"test": "wildlife_drinking_world", "passed": failures.is_empty(), "failures": failures})
	print(JSON.stringify(report))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
