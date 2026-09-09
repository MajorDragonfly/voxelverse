extends SceneTree
const Navigation = preload("res://world/tribe/village_navigation.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://tribal_age_world.json"
	if "--restart-check" in OS.get_cmdline_user_args():
		await _restart_check(saves, state)
		return
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
	var x_offsets: Array = [0]
	x_offsets.append_array(range(-16, 17, 2))
	var z_offsets: Array = [-4]
	z_offsets.append_array(range(-16, 17, 2))
	for x: int in x_offsets:
		for z: int in z_offsets:
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
	print("Village site search completed: ", result)
	_expect(result["ok"], "No playable village footprint in generated starting terrain: " + str(result) + " sites=" + str(sites_found))
	if not result["ok"]:
		current_scene.queue_free()
		await process_frame
		_finish()
		return
	for frame in range(45):
		await physics_frame
		await process_frame
	print("Opening tribal confirmation")
	tribe.panel.open_confirmation()
	_expect(not tribe.panel.confirm.disabled, "Generated home cannot enter tribe: " + tribe.panel._detail.text)
	tribe.panel._confirm()
	for frame in range(30):
		await physics_frame
		await process_frame
	_expect(tribe.is_active() and tribe.actors.size() == 3 and home.actors.is_empty(), "Actual main scene did not perform the handoff.")
	if tribe.is_active():
		print("Tribal group active; gathering on real terrain")
		tribe.select_all()
		_expect(tribe.issue_order("wood"), "Generated village cannot issue gathering command.")
		var carriers: Dictionary = {}
		for frame in range(1800):
			await physics_frame
			await process_frame
			for member: Dictionary in tribe.village()["members"]:
				if member["cargo"] == "wood":
					carriers[member["id"]] = true
			if int(tribe.village()["stock"]["wood"]) >= 6 and carriers.size() == 3:
				break
		_expect(carriers.size() == 3, "Not every resident could gather on real terrain.")
		_expect(int(tribe.village()["stock"]["wood"]) >= 6, "Workers cannot deliver wood over real terrain: " + str(tribe.village()["members"]) + " " + tribe.status)
		for actor: CharacterBody3D in tribe.actors.values():
			_expect(actor.visible and actor.is_on_floor(), "Resident lost real terrain floor or visibility.")
		await _extension(tribe)
		var args: PackedStringArray = OS.get_cmdline_user_args()
		if "--economy" in args:
			await _economy_world(tribe)
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

func _restart_check(saves: Node, state: Node) -> void:
	_expect(saves.load_now(), "Fresh process could not load the saved village.")
	if state.current_phase != 1:
		_expect(false, "Fresh process lost the tribal epoch.")
		_finish()
		return
	var expected: Dictionary = state.get_current_body()["tribe"].duplicate(true)
	change_scene_to_file("res://main/main.tscn")
	await scene_changed
	var tribe: Node = current_scene.get_node("Nest/Tribe")
	# Force the home controller's slower refresh to occur after tribal activation.
	tribe.home.player = current_scene.get_node("Player")
	tribe.home._timer = 10.0
	for frame in range(1800):
		await physics_frame
		await process_frame
		if tribe.is_active():
			break
	_expect(tribe.is_active(), "Fresh main scene did not restore group control.")
	if tribe.is_active():
		paused = true
		_expect(current_scene.get_node("Nest").global_position.distance_to(Home.vector(expected["anchor"])) < 0.1, "Fresh process left the nest at the default world origin.")
		_expect(tribe.actors.size() == 3 and tribe.home.actors.is_empty(), "Fresh process duplicated the original residents.")
		for member: Dictionary in expected["members"]:
			_expect(tribe.actors.has(member["id"]), "Fresh process changed a resident identity.")
		_expect(int(tribe.village()["deposits"]["wood"]["remaining"]) <= int(expected["deposits"]["wood"]["remaining"]), "Fresh process regenerated gathered resources.")
		if "--economy" in OS.get_cmdline_user_args():
			_expect(tribe.village()["economy"]["stations"] == expected["economy"]["stations"] and int(tribe.village()["stock"]["water"]) >= int(expected["stock"]["water"]), "Fresh process lost the well or delivered water.")
		_expect(not tribe.player.is_physics_processing() and tribe.camera.current, "Fresh process restored creature input instead of group control.")
	paused = false
	current_scene.queue_free()
	for frame in range(5):
		await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _extension(_tribe: Node) -> void:
	pass

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_age_world", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _economy_world(tribe: Node) -> void:
	print("M6: constructing a well on generated terrain")
	tribe.select_all()
	_expect(tribe.issue_order("stone"), "Cannot gather real stone for the well.")
	for frame in range(1800):
		await physics_frame
		await process_frame
		if int(tribe.village()["stock"]["stone"]) >= 4:
			break
	_expect(tribe.issue_order("tool"), "Cannot pay for tool from actual deliveries.")
	for frame in range(1200):
		await physics_frame
		await process_frame
		if int(tribe.village()["tools"]) == 1:
			break
	tribe.navigation.rebuild(tribe.home, tribe.anchor())
	var candidate := Vector3.INF
	for identity: int in tribe.navigation.graph.get_point_ids():
		var point: Vector3 = tribe.navigation.graph.get_point_position(identity)
		if tribe.navigation.free_workplace(point, tribe.village(), "well") and (not candidate.is_finite() or point.distance_to(tribe.anchor()) < candidate.distance_to(tribe.anchor())):
			candidate = point
	_expect(candidate.is_finite(), "No additional reachable workplace on generated terrain.")
	if not candidate.is_finite():
		return
	_expect(tribe.issue_order("well", candidate), "Generated well placement failed: " + tribe.status)
	for frame in range(1500):
		await physics_frame
		await process_frame
		if tribe.village()["economy"]["stations"].has("well"):
			break
	_expect(tribe.village()["economy"]["stations"].has("well"), "Workers did not build the well on generated terrain.")
	_expect(tribe.issue_order("water"), "Cannot gather actual well water.")
	for frame in range(1500):
		await physics_frame
		await process_frame
		if int(tribe.village()["stock"]["water"]) >= 2:
			break
	_expect(int(tribe.village()["stock"]["water"]) >= 2, "Water never reached the warehouse on generated terrain.")
	print("M6: generated workplace ", candidate, " water delivered ", tribe.village()["stock"]["water"])
