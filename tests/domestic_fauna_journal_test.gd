extends SceneTree
## Real D1 live spawn -> camera scan -> existing journal -> campaign save/restart.
## D1 stays optional on main; --require-d1 turns a missing dependency into a failure.
const Suitability = preload("res://ui/discovery/animal_suitability.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const SAVE := "user://d1_journal_campaign.json"
const EXPECTED := "user://d1_journal_expected.json"
const CATALOG_PATH := "res://world/fauna/domestication/planet_fauna_catalog.gd"

var failures: Array[String] = []
var scans: Array[String] = []
var heard: Array[StringName] = []
var state: Node
var saves: Node
var progression: Node
var player: Node3D
var scanner: Node
var journal: CanvasLayer
var audio: Node
var validator: Script
var representatives: Dictionary = {}
var spawn_anchor := Vector3.ZERO


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	progression = root.get_node("ProgressionService")
	audio = root.get_node("AudioManager")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	validator = Suitability.contract()
	if validator == null or not ResourceLoader.exists(CATALOG_PATH):
		check("--require-d1" not in OS.get_cmdline_user_args(), "Required D1 runtime is missing")
		await finish(false)
		return
	var reloading: bool = "--verify-reload" in OS.get_cmdline_user_args()
	if reloading:
		check(saves.load_now(), "Separate process could not load the existing campaign: " + saves.last_error)
	else:
		state.start_world_with_seed(15838)
	if not failures.is_empty():
		await finish(true)
		return
	change_scene_to_file("res://main/main.tscn")
	await scene_changed
	player = current_scene.get_node("Player")
	player.is_dead = true # Hold the player while the unchanged world and D1 spawn.
	var streamer: Node3D = current_scene.get_node("FaunaStreamerV7")
	for frame in range(900):
		await physics_frame
		if frame % 20 != 0:
			continue
		representatives.clear()
		for animal in streamer._active_fauna:
			if is_instance_valid(animal) and not animal.is_queued_for_deletion() and not animal.catalog_species.is_empty():
				representatives[animal.catalog_species["group"]] = animal
		if representatives.size() == 3:
			break
	check(representatives.size() == 3, "D1 did not spawn milk, work and companion species in the real scene")
	if not failures.is_empty():
		await finish(true)
		return
	# Freeze movement, not physics queries. Scanner still uses its actual activity,
	# range, camera ray, collider and pause checks with bounded simulation deltas.
	for node in current_scene.find_children("*", "", true, false):
		if node is CanvasLayer:
			continue
		node.set_process(false)
		node.set_physics_process(false)
	# Keep wildlife/terrain collision objects enabled while suspending the player
	# callback. is_physics_processing() still reflects its normal gameplay flag.
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(true)
	spawn_anchor = player.global_position
	player.is_dead = false
	scanner = player.get_node("CreatureScanner")
	scanner.set_physics_process(false)
	scanner.scan_completed.connect(func(key: String): scans.append(key))
	audio.scans.feedback_played.connect(func(event: StringName): heard.append(event))
	check(audio.scans.bind_scanner(scanner), "Existing audio adapter did not bind the real scanner")
	journal = player.get_node("ProgressionHUD")._discovery_journal
	check(get_nodes_in_group(&"discovery_journal").size() == 1, "Main scene installed a second book")
	if reloading:
		await verify_reload()
	else:
		await scan_and_save()
	await finish(true)


func scan_and_save() -> void:
	journal.refresh()
	check(journal._species_rows("", "domestic:milk").is_empty(), "Unscanned catalog leaked into the book")
	var expected := {"campaign_id": state.campaign.data["id"], "body_id": state.get_current_body()["id"], "animals": {}}
	for group in ["milk", "work", "companion"]:
		var animal: Node3D = representatives[group]
		if not await aim_at(animal):
			continue
		var key: String = progression.species_discovery_key(animal.species_seed)
		var count: int = progression.get_discovered_species_count()
		var points: int = progression.discovery_points
		for frame in range(12):
			step_scan()
		check(scanner.ratio() > 0.4 and scanner.ratio() < 1.0, "Real D1 collider did not allow a partial scan: " + group)
		check(not progression.has_species_scan(animal.species_seed), "Partial scan revealed D1 suitability: " + group)
		check(journal.open_journal(), "Existing book could not open during a partial scan")
		step_scan()
		check(scanner.ratio() == 0.0 and paused, "Book pause did not reset the partial scan")
		check(journal._species_rows("", "").size() == count, "Opening book discovered an unscanned D1 animal")
		await close_book()
		for frame in range(26):
			step_scan()
		check(scanner.known and scans.count(key) == 1, "Complete real scan did not emit exactly one success: " + group)
		check(progression.discovery_points == points + progression.SPECIES_DISCOVERY_POINTS, "D1 scan reward missing or duplicated: " + group)
		var entry: Dictionary = progression.discovered_species.get(key, {})
		var profile: Dictionary = Suitability.read(entry, validator)
		check(same(profile, animal.catalog_species["domestication"]), "Book changed generated D1 values: " + group)
		check(same(Records.visual_for(entry), Records.visual_for({"journal": Records.observation(animal.blueprint, "")})), "Scan lost the actual frozen D1 anatomy: " + group)
		check(animal.get_node("SocialBehavior").entry()["relation"] == "wild", "Scan converted suitability into friendship or possession")
		expected["animals"][group] = {"key": key, "identity": animal.get_campaign_identity(), "entry": entry.duplicate(true)}
		await check_book(key, profile)
		scanner.reset()
		step_scan()
		check(scanner.known and scans.count(key) == 1, "Known D1 species emitted another completion")
		check(progression.discovery_points == points + progression.SPECIES_DISCOVERY_POINTS, "Reading/known scan rewarded the species again")
	check(heard.count(&"discovery") == 3, "Three real D1 scans did not produce exactly three discovery cues")
	# Restore the spawn anchor so the separate process loads the same live habitats.
	player.global_position = spawn_anchor
	expected["points"] = progression.discovery_points
	check(saves.save_now(), "Existing SaveGameService could not save D1 scans: " + saves.last_error)
	var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
	check(file != null, "Could not write test expectations")
	if file != null:
		file.store_string(JSON.stringify(expected))
		file.close()
	var before: String = FileAccess.get_file_as_string(SAVE)
	for group in expected["animals"]:
		await check_book(expected["animals"][group]["key"], Suitability.read(expected["animals"][group]["entry"], validator))
	check(FileAccess.get_file_as_string(SAVE) == before, "Reading the book wrote the campaign")


func verify_reload() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	check(expected is Dictionary and expected.get("animals", {}).size() == 3, "Missing first-process scan expectations")
	if not expected is Dictionary or expected.get("animals", {}).size() != 3:
		return
	check(state.campaign.data["id"] == expected["campaign_id"] and state.get_current_body()["id"] == expected["body_id"], "Restart changed campaign/body identity")
	var before: String = FileAccess.get_file_as_string(SAVE)
	for group in expected["animals"]:
		var saved: Dictionary = expected["animals"][group]
		var animal: Node3D = representatives[group]
		var entry: Dictionary = progression.discovered_species.get(saved["key"], {})
		check(same(entry, saved["entry"]), "Separate process lost exact saved scan: " + group)
		# A species book must recognize another representative of the same species;
		# D1 can choose a different valid habitat/individual after loading.
		var identity: Dictionary = animal.get_campaign_identity()
		for field in ["species_id", "species_seed", "body_id", "design_ref"]:
			check(same(identity[field], saved["identity"][field]), "D1 respawn changed scanned species " + field + ": " + group)
		check(same(Records.visual_for(entry), Records.visual_for({"journal": Records.observation(animal.blueprint, "")})), "Respawn changed the frozen scanned D1 anatomy: " + group)
		await check_book(saved["key"], animal.catalog_species["domestication"])
		if await aim_at(animal):
			step_scan()
			check(scanner.known, "Restored D1 scan requires scanning again: " + group)
	check(progression.discovery_points == int(expected["points"]), "Restart/book/known animal rewarded discoveries again")
	check(scans.is_empty() and heard.count(&"discovery") == 0, "Restart/book/known animal replayed success")
	check(FileAccess.get_file_as_string(SAVE) == before, "Restart book view changed the saved campaign")


func check_book(key: String, profile: Dictionary) -> void:
	check(journal.open_journal(), "Shared book did not open")
	journal._selected_key = key
	journal.refresh()
	check(journal._selected_key == key and journal._animal_roles.text == Suitability.describe(profile), "Selected species did not display its actual D1 values")
	for role in profile.get("roles", []):
		var filtered: Array[Dictionary] = journal._species_rows("", "domestic:" + role)
		check(filtered.size() == 1 and filtered[0]["key"] == key, "D1 role filter mixed species: " + role)
		var searched: Array[Dictionary] = journal._species_rows(Suitability.ROLES[role], "")
		check(searched.size() == 1 and searched[0]["key"] == key, "Role search did not find the scanned species: " + role)
	check(journal._owned_reader.read()["rows"].is_empty(), "Scanned D1 species appeared as owned animals")
	await close_book()


func aim_at(animal: Node3D) -> bool:
	scanner.reset()
	if not player.inspection_mode_enabled:
		player.toggle_inspection_mode()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var center: Vector3 = animal.get_node("CollisionShape3D").global_position
	for index in range(8):
		var offset := Vector3(cos(index * TAU / 8.0), 0, sin(index * TAU / 8.0)) * 4.0
		player.global_position = animal.global_position + offset
		player._gameplay_camera.global_position = center + offset + Vector3.UP
		player._gameplay_camera.look_at(center)
		await physics_frame
		if player.get_scan_target() == animal:
			return true
	check(false, "No unobstructed real camera ray to spawned D1 animal: " + animal.catalog_species["group"])
	return false


func step_scan() -> void:
	scanner._physics_process(0.1)
	audio.scans._physics_process(0.1)


func close_book() -> void:
	journal.close_journal()
	await process_frame
	await process_frame
	check(not paused and not journal.is_open, "Shared book did not release its own pause")


func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func finish(d1_checked: bool) -> void:
	print(JSON.stringify({"test": "domestic_fauna_journal", "d1_checked": d1_checked, "restart": "--verify-reload" in OS.get_cmdline_user_args(), "scans": scans, "discovery_cues": heard.count(&"discovery"), "failures": failures}))
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		for frame in range(12):
			await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
