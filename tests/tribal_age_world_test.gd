extends SceneTree
const Navigation = preload("res://world/tribe/village_navigation.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://tribal_age_world.json"
	state.start_world_with_seed(15838)
	await process_frame
	change_scene_to_file("res://main/main.tscn")
	await scene_changed
	var home: Node = current_scene.get_node("Nest/HomeGroup")
	var tribe: Node = current_scene.get_node("Nest/Tribe")
	for frame in range(1800):
		await physics_frame
		await process_frame
		if home.can_use_panel() and home.player.is_on_floor() and home.has_ground(home.player.global_position):
			break
	_expect(home.can_use_panel(), "Generated world did not initialize the nest controller.")
	if not home.can_use_panel():
		_finish()
		return
	var player: CharacterBody3D = home.player
	player.set_physics_process(false)
	player.set_process(false)
	for frame in range(500):
		await physics_frame
		await process_frame
		if current_scene.get_node("WorldManager").get_pending_chunk_count() == 0:
			break
	var origin: Vector3 = player.global_position
	var generator: Node = root.get_node("WorldGenerator")
	var navigation := Navigation.new()
	var result: Dictionary = {"ok": false}
	var sites_found: int = 0
	print("Generated starting point ", origin)
	# Search near the real starting player using physical loaded terrain. Test
	# readiness is a floor contact, independent of runner speed/render frames.
	for x in range(-16, 17, 2):
		for z in range(-16, 17, 2):
			var point := origin + Vector3(x, 0, z)
			point.y = generator.get_terrain_height(point.x, point.z) + 0.3
			if not home.has_ground(point):
				continue
			var ground: Vector3 = home._floor_hit(point)["position"]
			navigation.rebuild(home, ground)
			if navigation.sites().is_empty():
				continue
			sites_found += 1
			player.global_position = point
			result = home.establish_home()
			if result["ok"]:
				break
		if result["ok"]:
			break
	_expect(result["ok"], "No playable village footprint in generated starting terrain: " + str(result) + " sites=" + str(sites_found))
	if not result["ok"]:
		current_scene.queue_free()
		await process_frame
		_finish()
		return
	for frame in range(45):
		await physics_frame
		await process_frame
	tribe.panel.open_confirmation()
	_expect(not tribe.panel.confirm.disabled, "Generated home cannot enter tribe: " + tribe.panel._detail.text)
	tribe.panel._confirm()
	for frame in range(30):
		await physics_frame
		await process_frame
	_expect(tribe.is_active() and tribe.actors.size() == 3 and home.actors.is_empty(), "Actual main scene did not perform the handoff.")
	if tribe.is_active():
		tribe.select_all()
		_expect(tribe.issue_order("wood"), "Generated village cannot issue gathering command.")
		for frame in range(1800):
			await physics_frame
			await process_frame
			if int(tribe.village()["stock"]["wood"]) >= 3:
				break
		_expect(int(tribe.village()["stock"]["wood"]) >= 3, "Workers cannot deliver wood over real terrain: " + str(tribe.village()["members"]) + " " + tribe.status)
		for actor: CharacterBody3D in tribe.actors.values():
			_expect(actor.visible and actor.is_on_floor(), "Resident lost real terrain floor or visibility.")
		var args: PackedStringArray = OS.get_cmdline_user_args()
		if "--capture" in args:
			var directory: String = args[args.find("--capture") + 1]
			DirAccess.make_dir_recursive_absolute(directory)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("06_generated_village.png"))
		var ids: Array = tribe.actors.keys()
		_expect(saves.save_now() and saves.load_now(), "Generated tribal world cannot save/load.")
		for frame in range(45):
			await physics_frame
			await process_frame
		_expect(tribe.is_active() and tribe.actors.keys() == ids and not player.is_physics_processing(), "Main reload did not restore the same commanded group.")
	paused = false
	current_scene.queue_free()
	for frame in range(5):
		await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_age_world", "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
