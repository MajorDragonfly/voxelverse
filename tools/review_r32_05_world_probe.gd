extends "res://core/diagnostics/spherical_creature_probe.gd"
## Public sphere load, generated colonies and authoritative membership; no fixture population.
const Colony = preload("res://world/surface/wildlife_colony.gd")
const Text = preload("res://core/localization/ui_text.gd")
var output := ""
var observations: Array[Dictionary] = []
var frame := 0
var restart_exit := -1
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--verify-world-restart" in args:
		saves = tree.root.get_node("SaveGameService")
		state = tree.root.get_node("GameState")
		saves.session_managed = true; saves.autosave_enabled = false
		var start: int = args.find("--verify-world-restart")
		saves.save_path = args[start + 1]
		_expect(saves.load_now(), "Fresh process could not load sphere nest save")
		var body: Dictionary = state.get_current_body_record()
		var progression: Node = tree.root.get_node("ProgressionService")
		_expect(progression.has_nest_scan(args[start + 2], body.id, body.seed), "Fresh sphere save lost first nest")
		_expect(not progression.has_nest_scan(args[start + 3], body.id, body.seed), "Fresh sphere save discovered second nest")
		print("R32_SPHERE_NEST_FRESH_PROCESS ", JSON.stringify({"passed": failures.is_empty(), "body_id": body.id}))
		await _finish(); return
	output = args[0] if not args.is_empty() else ""
	if output.is_empty() or DisplayServer.get_name() == "headless":
		_expect(false, "Native sphere capture requires output and a real renderer")
		await _finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	tree.root.get_node("LocaleManager").save_preference(args[1] if args.size() > 1 else "de")
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var slot: String = saves.create_slot("R32-05 public sphere", 15838, Cube.MODE)
	await _open(slot)
	if not _expect_world(): await _done(); return
	var display: Node = tree.root.get_node("DisplaySettings")
	display.display_mode = display.MODE_WINDOWED; display.resolution = Vector2i(1280, 720); display.ui_scale = 1.0; display._apply_settings(false)
	var scene: Node3D = tree.current_scene
	await _until(func() -> bool: return scene.population.nests.size() >= 2, 25000)
	_expect(scene.population.nests.size() >= 2, "Two generated nests did not stream in 25 seconds")
	if scene.population.nests.size() < 2: await _done(); return
	var nest_ids: Array = scene.population.nests.keys()
	var first_id: String = nest_ids[0]
	var second_id: String = nest_ids[1]
	var first: Node3D = scene.population.nests[first_id]
	var second: Node3D = scene.population.nests[second_id]
	var scanner: Node = scene.player.get_node("CreatureScanner")
	scanner.set_physics_process(false)
	var owner: Dictionary = state.get_current_body_record()
	_expect(not tree.root.get_node("ProgressionService").has_nest_scan(second_id, owner.id, owner.seed), "Second nest was known on new campaign")
	_expect(scene.known_map_places().all(func(place: Dictionary) -> bool: return place.id != first_id and place.id != second_id), "Unknown generated nest leaked into map before scan")
	var map: Node = tree.get_first_node_in_group(&"world_map")
	if map != null:
		_expect(map.open_map(), "Normal map panel did not open before discovery")
		for tick in range(20): await tree.process_frame
		await _capture("sphere-map-before"); map.close_map()
	else: _expect(false, "Normal map controller missing")
	if not await _aim_nest(scene, first_id): await _done(); return
	first = scene.population.nests.get(first_id)
	if not is_instance_valid(first): _expect(false, "Staged first nest unloaded"); await _done(); return
	scene.player.toggle_inspection_mode()
	for tick in range(85):
		await tree.physics_frame
		if not is_instance_valid(first): _expect(false, "Nest unloaded during scan"); break
		scene.player.camera.look_at(first.global_position + first.global_basis.y * 0.45, scene.player.up_direction)
		scanner._physics_process(1.0 / 30.0)
		var living: int = Colony.living_members(scene.population, first.colony)
		first.refresh(scene.player, living)
		if tick == 0:
			_expect(scanner.target == first and first.label.text == Text.text("LIVING_NEST_UNKNOWN"), "Unknown sphere nest leaked name/count or lost target")
			await _capture("sphere-nest-before")
		await _record()
	_expect(scanner.known and scanner.target == first, "Generated nest scan did not complete")
	if is_instance_valid(first):
		var living: int = Colony.living_members(scene.population, first.colony)
		var expected: int = 0
		var loaded := 0
		for member: String in first.colony.members:
			var record: Dictionary = scene.population.storage.record(member)
			if not record.is_empty() and not scene.population._reserved(member) and not record.get("encounter", {}).get("dead", false): expected += 1
			if scene.population.animals.has(member): loaded += 1
		first.refresh(scene.player, living)
		_expect(living == expected and first.living_members == expected, "Nest count differs from actual canonical residents")
		observations.append({"case": "first_nest", "id": first_id, "species_seed": first.colony.seed, "members": first.colony.members, "actual_living": living, "physically_loaded": loaded, "label": first.label.text})
		await _capture("sphere-nest-after")
	var progression: Node = tree.root.get_node("ProgressionService")
	_expect(not progression.has_nest_scan(second_id, owner.id, owner.seed), "Scanning first generated nest discovered second")
	var map_places: Array[Dictionary] = scene.known_map_places()
	_expect(map_places.all(func(place: Dictionary) -> bool: return place.id != first_id and place.id != second_id), "Foreign nest leaked into unscanned map provider")
	observations.append({"case": "map", "places": map_places, "note": "Current sphere map lists own home/allied habitat only, no foreign nest entries before or after scanning."})
	if map != null:
		_expect(map.open_map(), "Normal map panel did not open")
		for tick in range(20): await tree.process_frame
		await _capture("sphere-map"); map.close_map()
	else: _expect(false, "Normal map controller missing")
	_expect(saves.save_now(), "Actual colony/scan save failed: " + saves.last_error)
	var child_output: Array = []
	restart_exit = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/review_r32_05_world.gd", "--", "--verify-world-restart", slot, first_id, second_id], child_output, true)
	_expect(restart_exit == 0 and str(child_output).contains("R32_SPHERE_NEST_FRESH_PROCESS") and not str(child_output).contains("ERROR"), "Fresh sphere save process failed: " + str(child_output))
	# Exercise a complete unload/reload through the public loader; snapshot identity survives.
	flow.return_to_title()
	await tree.scene_changed
	await _open(slot)
	if _expect_world():
		scene = tree.current_scene
		await _until(func() -> bool: return scene.population.nests.has(first_id), 25000)
		_expect(progression.has_nest_scan(first_id, owner.id, owner.seed) and not progression.has_nest_scan(second_id, owner.id, owner.seed), "Public reload lost first/invented second nest discovery")
		if scene.population.nests.has(first_id):
			first = scene.population.nests[first_id]
			var living: int = Colony.living_members(scene.population, first.colony)
			if await _aim_nest(scene, first_id):
				if not scene.player.inspection_mode_enabled: scene.player.toggle_inspection_mode()
				scanner = scene.player.get_node("CreatureScanner")
				scanner.set_physics_process(false)
				scanner._physics_process(1.0 / 30.0)
				first.refresh(scene.player, living)
				_expect(scanner.target == first and scanner.known and first.label.text.contains(str(living)), "Reloaded actual nest lost known label/current count")
			observations.append({"case": "reloaded_nest", "id": first_id, "actual_living": living, "members": first.colony.members})
			await _capture("sphere-reloaded")
		else: _expect(false, "Saved nest did not reload in 25 seconds")
	await _done()
func _aim_nest(scene: Node3D, id: String) -> bool:
	for index in range(4):
		var nest: Node3D = scene.population.nests.get(id)
		if not is_instance_valid(nest): return false
		var location: Dictionary = nest.colony.anchor.duplicate(true)
		var angle: float = index * TAU / 4
		var offset: Vector3 = scene.adapter.frame_at(location) * Vector3(cos(angle) * 6, 0, sin(angle) * 6)
		var place: Dictionary = scene.adapter.offset(location, offset)
		var ground: Dictionary = scene.adapter.sample(place)
		if ground.water: continue
		place.height = ground.height + 0.1
		scene.player.place(place, -offset)
		await _until(func() -> bool: return Space.ground_ready(self, scene.player.global_position) and scene.player.is_on_floor(), 10000)
		nest = scene.population.nests.get(id)
		if not is_instance_valid(nest): continue
		scene.player.camera.look_at(nest.global_position + nest.global_basis.y * 0.45, scene.player.up_direction)
		if scene.player.get_scan_target() == nest: return true
	_expect(false, "Generated nest never reachable by the actual spherical camera")
	return false
func _record() -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	_expect(tree.root.get_texture().get_image().save_png(output.path_join("frame-%05d.png" % frame)) == OK, "Sphere video frame write failed")
	frame += 1
func _done() -> void:
	var file := FileAccess.open(output.path_join("world.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "seed": 15838, "observations": observations, "failures": failures, "frames": frame, "restart_exit": restart_exit, "target_pc_accepted": false}, "\t")); file.close()
	await _finish()

func _capture(name: String) -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	_expect(tree.root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Sphere screenshot write failed")

func _finish() -> void:
	tree.paused = false
	for failure: String in failures: push_error(failure)
	print("R32_05_WORLD_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
