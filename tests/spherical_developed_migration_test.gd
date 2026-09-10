extends SceneTree
const Registry = preload("res://core/campaign/body_registry.gd")
const Migration = preload("res://core/campaign/spherical_migration.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Housing = preload("res://world/tribe/village_housing.gd")
const H = preload("res://world/tribe/village_husbandry.gd")
const Animal = preload("res://world/domestication/animal_state.gd")
const Saved = preload("res://world/domestication/campaign_animal_state.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--developed-restart" in OS.get_cmdline_user_args():
		await _runtime(Atomic.parse_dictionary(FileAccess.get_file_as_string("user://developed_restart.json")), true)
		await _finish()
		return
	var path: String = saves.create_slot("Bestehendes Dorf", 15838)
	var source: Dictionary = saves._read_save(path)
	var campaign: Dictionary = source.game_state.campaign
	var body: Dictionary = Registry.active(source.game_state)
	body.home_group = Home.create(body.id, campaign.player_species_id, Vector3.ZERO)
	body.tribe = Model.create(body.home_group, campaign, {"position": [0, 0, 0]}, {"wood": [-5,0,-4], "stone": [5,0,-4], "food": [-5,0,4], "huts": [[5,0,4], [8,0,0]]})
	var village: Dictionary = body.tribe
	village.tools = 1
	village.members[0].merge({"cargo": "wood", "order": "wait", "paused_order": "wood", "stage": "return", "work": 1.25}, true)
	village.deposits.wood.remaining -= 1
	village.housing.homes.append(Housing.site(village, "hut", [5,0,4], 0))
	village.huts = 1
	village.housing.clock = 17.0
	body.tribal_neighbor = Neighbor.create(campaign, village, Vector3(0,0,12), [Vector3(-2,0,12), Vector3(2,0,12)])
	body.fauna_catalog = Catalog.create(body)
	var positions: Array = [[8,0,0], [-8,0,0], [0,0,-8]]
	for i in range(3):
		var species: Dictionary = body.fauna_catalog.species[i]
		var p: Array = positions[i]
		body.fauna_catalog.habitats.append({"key": "original-" + str(i), "species_id": species.id, "position": p, "spawn_position": p.duplicate(), "path": [[0,0,0], p.duplicate()],
			"region_id": Model.Ids.scoped("region", body.id, "legacy:%d:%d" % [floori(p[0]/256.0), floori(p[2]/256.0)]), "generation": 0, "replacement_at": 0.0,
			"travel_mode": "walk", "food": "plant", "water_supply": "requires_transport", "freshwater_distance": -1})
	body.fauna_catalog.habitat_status = "ready"
	var species: Dictionary = body.fauna_catalog.species[0]
	var habitat: Dictionary = body.fauna_catalog.habitats[0]
	var id: String = Model.Ids.scoped("object", habitat.region_id, "habitat:d1:" + habitat.key + ":0")
	var animal: Dictionary = Animal.individual(id, species.id, body.id, {"id": species.blueprint.design_id, "revision": 0}, Vector3(0,0,7))
	animal.merge({"owner_faction_id": campaign.player_faction_id, "status": "tamed", "trust": 100.0, "health": 72.0, "hunger": 13.0, "thirst": 21.0}, true)
	body.domesticated_animals = Saved.create(campaign, body)
	body.domesticated_animals.registry.animals[id] = animal
	body.domesticated_animals.sources[id] = {"identity": {"object_id": id, "species_id": species.id, "body_id": body.id, "region_id": habitat.region_id,
		"design_ref": {"design_id": species.blueprint.design_id, "revision": 0}}, "blueprint": species.blueprint.duplicate(true), "visual_scale": species.visual_scale,
		"maximum_health": 80.0, "speed": species.domestication.movement_speed, "species_seed": species.species_seed, "individual_seed": 781, "role": species.role, "name": "Ursprüngliches Milchtier", "fear_until": 0.0, "heading": 0.7, "preview_offset": [0,0.7,0]}
	var pen: Dictionary = Housing.site(village, "pen", [0,0,7], 0)
	pen.merge({"animal_id": "", "food": 4.0, "water": 8.0})
	village.husbandry.pens.append(pen)
	village.husbandry.withdrawn = {"food": 4, "water": 8}
	village.husbandry.delivered = {"food": 4, "water": 8}
	village.deposits.food.remaining -= 4
	village.economy.stations.well = {"id": Model.Ids.scoped("workplace", village.id, "well"), "position": village.anchor.duplicate()}
	village.economy.produced.water = 8
	_expect(H.bind(village, pen, animal, {"milk_yield": species.domestication.milk_yield, "milk_interval": species.domestication.milk_interval, "water_need": species.domestication.water_need}).is_empty(), "Cannot bind original production.")
	for i in range(ceili(species.domestication.milk_interval * 4)): H.advance(village, pen, 0.25)
	_expect(H.offer(village, id), "Cannot prepare completed undelivered milk.")
	for i in range(70): H.advance(village, pen, 0.25)
	source.game_state.phase = 1
	source.regions_by_body = {body.id: {"schema": 1, "world_seed": 15838, "simulation_tick": 42, "regions": {"0,0": {"x": 0, "z": 0, "plant_biomass": 0.61, "water_availability": 0.73, "carcass_biomass": 0.18, "species": [], "last_touched_tick": 42}}}}
	var problem: String = saves._validate_save(source)
	_expect(problem.is_empty(), "Invalid developed source fixture: " + problem)
	if not problem.is_empty(): await _finish(); return
	Atomic.write(path, source, false)
	saves.session_active = false
	var original: String = FileAccess.get_file_as_string(path)
	var original_body: Dictionary = Registry.active(JSON.parse_string(original).game_state)
	var plan: Dictionary = saves.preview_spherical_migration(path)
	_expect(plan.ok, "Developed migration blocked: " + str(plan.get("blockers")))
	if plan.ok:
		var destination: String = saves.migrate_slot_to_sphere(path, original.sha256_text())
		_expect(not destination.is_empty(), "Developed copy failed: " + saves.last_error)
		if not destination.is_empty():
			var result: Dictionary = saves._read_save(destination)
			_expect(Migration.inventory(source) == Migration.inventory(result), "Changed people, ownership, recipes, cargo or regional inventory.")
			var copied: Dictionary = Registry.active(result.game_state)
			_expect(copied.domesticated_animals.sources == original_body.domesticated_animals.sources, "Original frozen animal bodies changed.")
			_expect(copied.tribe.economy.incoming[0].remaining == original_body.tribe.economy.incoming[0].remaining and copied.tribe.members[0].cargo == "wood", "In-flight stock was lost or credited early.")
			_expect(copied.tribe.husbandry.records[id].clock == village.husbandry.records[id].clock, "Partial cycle changed.")
			_expect(FileAccess.get_file_as_string(path) == original, "Developed source was overwritten.")
			await _runtime({"target": destination, "source": path, "source_hash": original.sha256_text(), "saved": result, "animal_id": id}, false)
	await _finish()

func _runtime(expected: Dictionary, restarting: bool) -> void:
	var flow: Node = root.get_node("SessionFlow")
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	flow.world_started.connect(flow.toggle_pause, CONNECT_ONE_SHOT)
	flow.load_game(expected.target)
	await process_frame
	var started: int = Time.get_ticks_msec()
	while flow.loading and Time.get_ticks_msec() - started < 50000: await process_frame
	if flow.loading or current_scene.scene_file_path != flow.SPHERE_SCENE:
		_expect(false, "Developed runtime did not load: " + saves.last_error)
		return
	saves.autosave_enabled = false
	var previous: Dictionary = Registry.active(expected.saved.game_state)
	var current: Dictionary = state.get_current_body_record()
	for field in ["home_group", "tribe", "domesticated_animals", "tribal_neighbor"]:
		_expect(Migration.fingerprint(current[field]) == Migration.fingerprint(previous[field]), "Loading changed developed inventory: " + field)
	_expect(FileAccess.get_file_as_string(expected.source).sha256_text() == expected.source_hash, "Runtime changed migration source.")
	if restarting:
		if failures.is_empty(): print("DEVELOPED_FRESH_PROCESS_PASSED")
	else:
		flow.resume()
		var tribe: Node = current_scene.get_node("Nest/Tribe")
		started = Time.get_ticks_msec()
		while (not tribe.is_active() or not tribe.domestication._ready_runtime) and Time.get_ticks_msec() - started < 30000: await process_frame
		_expect(tribe.is_active() and tribe.actors.size() == 3, "Original migrated residents did not activate.")
		_expect(tribe.domestication.animals.has(expected.animal_id), "Original owned animal did not activate.")
		flow.toggle_pause()
		_expect(saves.save_now(), "Developed runtime could not save: " + saves.last_error)
		expected.saved = saves._read_save(expected.target)
		_expect(Atomic.write("user://developed_restart.json", expected, false) == OK, "Cannot write developed restart evidence.")
	flow.return_to_title()
	await scene_changed
	if not restarting and failures.is_empty():
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/spherical_developed_migration_test.gd", "--", "--developed-restart"], output, true)
		_expect(code == 0 and str(output).contains("DEVELOPED_FRESH_PROCESS_PASSED"), "Developed fresh process failed: " + str(output))

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for message in failures: push_error(message)
	if failures.is_empty(): print("SPHERICAL_DEVELOPED_MIGRATION_PASSED: original home, citizens, hut, neighbor, owned frozen animal, pen, partial production, pending milk, wood cargo and ecology.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
