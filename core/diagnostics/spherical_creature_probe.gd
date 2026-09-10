extends "res://core/diagnostics/spherical_campaign_probe.gd"
const Space = preload("res://world/surface/gameplay_space.gd")
const Home = preload("res://world/home_group/home_group_state.gd")

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("Kreaturen auf der Kugel", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _finish(); return
	var scene: Node3D = tree.current_scene
	await _until(func() -> bool: return scene.population.animals.size() >= 2, 25000)
	var player: CharacterBody3D = scene.player
	var scanner: Node = player.get_node("CreatureScanner")
	var progression: Node = tree.root.get_node("ProgressionService")
	var home_location: Dictionary = player.location()
	var home_heading: Vector3 = player.forward
	var aimed: Node3D = await _aim_at_wildlife(scene)
	player.toggle_inspection_mode()
	_expect(aimed != null, "Shared radial camera could not aim at actual wildlife.")
	if aimed != null:
		var points: int = progression.discovery_points
		for i in range(30): scanner._physics_process(0.1)
		_expect(scanner.known and progression.has_species_scan(aimed.species_seed), "Radial aimed scan did not finish.")
		for i in range(30): scanner._physics_process(0.1)
		_expect(progression.discovery_points == points + progression.SPECIES_DISCOVERY_POINTS, "Radial scan paid twice or lost its reward.")
	player.toggle_inspection_mode()
	await _capture("creature-and-wildlife")
	# Home/editor acceptance keeps its original, known buildable site after
	# the scan's independent camera/range setup.
	player.place(home_location, home_heading)
	await tree.physics_frame
	await tree.physics_frame
	await _until(func() -> bool: return Space.ground_ready(self, player.global_position) and player.is_on_floor(), 10000)
	var home: Node = scene.get_node("Nest/HomeGroup")
	if not home.establish_home().get("ok", false):
		_expect(false, "Cannot establish radial home before editing.")
		await _finish()
		return
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	var identity: String = state.campaign.data.id
	var original_home: Dictionary = state.get_current_body_record().home_group.duplicate(true)
	var location: Dictionary = player.location()
	var visual: Node = player.get_node("CreatureRuntimeVisual")
	var editor_path: String = visual.CREATURE_EDITOR_SCENE
	var key := InputEventKey.new()
	key.keycode = KEY_F2
	key.pressed = true
	visual._unhandled_input(key)
	await tree.scene_changed
	var editor: Node = tree.current_scene
	_expect(editor.scene_file_path == editor_path, "F2 did not open the normal creature editor.")
	await _capture("normal-creature-editor")
	var design_id: String = editor.blueprint.design_id
	editor._creature_name_edit.text = "Kugelheimat erhalten"
	editor._creature_name_edit.text_changed.emit("Kugelheimat erhalten")
	editor._play_test_placeholder()
	await _until(func() -> bool: return not flow.loading and tree.current_scene.scene_file_path == Surface.SCENE, 50000)
	if not _expect_world(): await _finish(); return
	scene = tree.current_scene
	player = scene.player
	_expect(state.campaign.data.id == identity and Blueprint.load_best_available().design_id == design_id and Blueprint.load_best_available().name == "Kugelheimat erhalten", "Editor switched campaign or lost the revised design.")
	_expect(state.get_current_body_record().home_group.id == original_home.id and Home.distance(state.get_current_body_record().home_group.anchor, original_home.anchor) < 0.005, "Editor moved home or replaced companions.")
	var returned: Dictionary = Space.encode(self, player.global_position)
	_expect(Home.distance(returned, _radius(location)) < 1.5, "Editor returned player to a different place: " + JSON.stringify({"before": _radius(location), "after": returned, "saved": saves._last_player_state.get("surface_address")}))
	await _water(scene)
	_expect(saves.save_now(), "Radial creature/water state did not save: " + saves.last_error)
	flow.return_to_title()
	await tree.scene_changed
	await _finish()

func _aim_at_wildlife(scene: Node3D) -> Node3D:
	# Budgeted loading does not promise that the first two animals are inside
	# the player's 20 m scan radius. Stage the observer near real wildlife;
	# keep the normal range, collision query and first-hit visibility checks.
	var player: CharacterBody3D = scene.player
	for animal: Node3D in scene.population.animals.values().slice(0, 2):
		if not is_instance_valid(animal): continue
		var collision: CollisionShape3D = animal.get_node_or_null("CollisionShape3D")
		if collision == null: continue
		for index in range(4):
			var location: Dictionary = Space.address(self, animal.global_position)
			var angle: float = index * TAU / 4.0
			var offset: Vector3 = scene.adapter.frame_at(location) * Vector3(cos(angle) * 6.0, 0, sin(angle) * 6.0)
			var place: Dictionary = scene.adapter.offset(location, offset)
			var ground: Dictionary = scene.adapter.sample(place)
			if ground.water: continue
			place.height = ground.height + 0.1
			player.place(place, -offset)
			await tree.physics_frame
			await tree.physics_frame
			await _until(func() -> bool: return Space.ground_ready(self, player.global_position) and player.is_on_floor(), 10000)
			if not is_instance_valid(animal): break
			player.camera.look_at(collision.global_position, player.up_direction)
			if player.get_scan_target() == animal: return animal
	return null

func _water(scene: Node3D) -> void:
	var surface: RefCounted = scene.terrain.surface
	var start: Dictionary = scene.player.location()
	var lake: Dictionary = {}
	for distance in [64.0, 128.0, 256.0, 512.0, 1024.0]:
		for index in range(16):
			var angle: float = index * TAU / 16.0
			var place: Dictionary = scene.adapter.offset(start, scene.adapter.frame_at(start) * Vector3(cos(angle) * distance, 0, sin(angle) * distance))
			var candidates: Dictionary = surface._feature(Cube.direction(place.face, place.u, place.v))
			if not candidates.is_empty(): lake = candidates; break
			for candidate: Dictionary in surface._lakes.values():
				if not candidate.is_empty(): lake = candidate; break
			if not lake.is_empty(): break
		if not lake.is_empty(): break
	_expect(not lake.is_empty(), "No versioned freshwater basin found.")
	if lake.is_empty(): return
	var address: Dictionary = Cube.from_cartesian(surface.body.id, [lake.direction[0] * surface.body.radius, lake.direction[1] * surface.body.radius, lake.direction[2] * surface.body.radius], surface.body.radius)
	address.height = lake.level - 0.5
	scene.player.place(address)
	await _until(func() -> bool: return Space.ground_ready(self, scene.player.global_position), 25000)
	var water: Node = scene.get_node("Water")
	var point: Vector3 = scene.adapter.to_local(address)
	_expect(not water.freshwater_at(point).is_empty() and water.view_sample(point).depth > 0.4, "Freshwater and underwater view disagree on canonical depth.")
	var before: float = scene.player.maximum_thirst * 0.3
	scene.player.current_thirst = before
	scene.player._try_drink_water(point)
	_expect(scene.player.current_thirst > before, "Loaded reachable freshwater could not be drunk.")
	var sample: Dictionary = water.audio_sample(point)
	_expect(sample.water_present and absf((sample.water_point - point).dot(sample.up) - 0.5) < 0.005, "Radial audio uses another water surface.")
	await _capture("freshwater-on-sphere")

func _capture(name: String) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not "--capture" in args or DisplayServer.get_name() == "headless": return
	var directory: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "Screenshot could not be saved.")

func _radius(place: Dictionary) -> Dictionary:
	var result: Dictionary = place.duplicate(true)
	result.radius = Surface.DEFAULT_RADIUS
	return result

func _until(predicate: Callable, milliseconds: int) -> void:
	var started: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - started < milliseconds: await tree.process_frame

func _finish() -> void:
	tree.paused = false
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SPHERICAL_CREATURE_PASSED: real camera scan, one reward, normal editor return, original home and body-bound freshwater/view/audio.")
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
