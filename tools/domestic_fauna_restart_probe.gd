extends SceneTree
const Registry = preload("res://core/campaign/body_registry.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Planner = preload("res://world/fauna/domestication/domestic_habitat_planner.gd")
const Legacy = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	var progression: Node = root.get_node("ProgressionService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://d1-restart.json"
	var mode: String = OS.get_environment("D1_RESTART_MODE")
	if mode == "write":
		state.start_world_with_seed(15838)
		state.campaign.reset("d1-restart-campaign")
		state.active_system_id = ""
		state.set_world_seed(state.world_seed, false)
		var body: Dictionary = state.get_current_body()
		var region: String = state.campaign.region_id(body["id"], Vector2i.ZERO)
		var legacy_id: String = state.campaign.object_id(region, "habitat:old:1")
		var identity := {"object_id": legacy_id, "body_id": body["id"], "region_id": region, "species_id": state.campaign.species_id(body["id"], 771), "species_seed": 771, "habitat_cell": "old:1"}
		var encounter: Dictionary = progression.get_creature_encounter(identity, "grazer", 889)
		encounter["relation"] = "ally"
		encounter["trust"] = 100.0
		check(progression.store_creature_encounter(encounter)["ok"], "Store legacy encounter")
		progression.register_species_scan(771, Legacy.create_species(771, Vector2i.ZERO, "grazer"))
		check(saves.save_now("user://d1-legacy.json"), "Save original pre-D1 campaign")
		var old_progression: String = JSON.stringify(JSON.parse_string(JSON.stringify(progression.export_state())))
		var signatures: Dictionary = {}
		for seed_value in [15838, 63352, 23757]:
			state.activate_planet(15838, 0, seed_value)
			var catalog: Dictionary = Catalog.ensure(state)
			var planner := Planner.new()
			planner.begin(root.get_node("WorldGenerator"))
			while not planner.finished: planner.step(root.get_node("WorldGenerator"), catalog, 32)
			catalog["habitats"] = planner.habitats
			catalog["habitat_status"] = "ready"
			signatures[str(seed_value)] = JSON.stringify(JSON.parse_string(JSON.stringify(catalog)))
		check(saves.save_now(), "Save D1 campaign: " + saves.last_error)
		check(Atomic.write("user://d1-expected.json", {"catalogs": signatures, "progression": old_progression, "legacy_id": legacy_id}) == OK, "Save expected signatures")
	elif mode == "read":
		check(saves.load_now(), "Cold load: " + saves.last_error)
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://d1-expected.json"))
		check(JSON.stringify(JSON.parse_string(JSON.stringify(progression.export_state()))) == expected["progression"], "Old discoveries/relations changed")
		for seed_value in [23757, 15838, 63352]:
			state.activate_planet(15838, 0, seed_value)
			check(JSON.stringify(Catalog.ensure(state)) == expected["catalogs"][str(seed_value)], "Restart/order changed species, body or habitats")
		check(saves.save_now(), "Resave after restart")
		var snapshot: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(saves.save_path))
		var body: Dictionary = Registry.active(snapshot.game_state)
		for kind in ["schema", "generator", "suitability"]:
			var future: Dictionary = snapshot.duplicate(true)
			var catalog: Dictionary = Registry.active(future.game_state)["fauna_catalog"]
			if kind == "schema": catalog["schema"] = Catalog.ROLE_SCHEMA + 1
			elif kind == "generator": catalog["generator_version"] = "future_v2"
			else: catalog["species"][0]["domestication"]["schema"] = Catalog.Contract.EGG_SCHEMA + 1
			check(Atomic.write("user://d1-future.json", future, false) == OK, "Write future fixture")
			check(Atomic.write("user://d1-future.json.bak", snapshot, false) == OK, "Write compatible backup")
			var before: String = FileAccess.get_file_as_string("user://d1-future.json")
			check(not saves.load_now("user://d1-future.json"), "Future contract silently downgraded: " + kind)
			check(not saves.save_now("user://d1-future.json"), "Overwrote future contract")
			check(FileAccess.get_file_as_string("user://d1-future.json") == before, "Future file changed")
			check(saves.load_now(), "Restore known compatible campaign")
		var broken: Dictionary = body["fauna_catalog"].duplicate(true)
		broken["species"][0]["blueprint"]["body"]["shape"] = {"$vector3": [1]}
		check(not Catalog.validate(broken, body).is_empty(), "Malformed blueprint accepted")
		check(saves.load_now("user://d1-legacy.json"), "Load pre-D1 save")
		check(not state.get_current_body().has("fauna_catalog"), "Old file unexpectedly contains D1")
		var legacy_before: String = JSON.stringify(progression.export_state())
		var migrated: Dictionary = Catalog.ensure(state)
		check(not migrated.is_empty(), "Additive old-save upgrade")
		var expected_catalog: Dictionary = JSON.parse_string(expected["catalogs"]["15838"])
		check(JSON.stringify(JSON.parse_string(JSON.stringify(migrated["species"]))) == JSON.stringify(expected_catalog["species"]), "Fresh and migrated body seeds generated different species")
		check(JSON.stringify(progression.export_state()) == legacy_before, "Migration altered old encounters")
	else: failures.append("Set D1_RESTART_MODE=write/read; run in separate processes")
	print(JSON.stringify({"test": "domestic_fauna_restart", "mode": mode, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
