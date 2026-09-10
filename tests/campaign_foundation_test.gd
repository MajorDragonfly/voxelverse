extends SceneTree

const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Building = preload("res://civilization/buildings/building_blueprint.gd")
const Factory = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Store = preload("res://core/persistence/design_store.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
const Ecology = preload("res://world/simulation/region_ecology_simulation.gd")
const TEST_SAVE: String = "user://campaign_m0_test.json"

var failures: Array[String] = []
var saves: Node
var state: Node
var progression: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	progression = root.get_node("ProgressionService")
	saves.set("autosave_enabled", false)
	saves.set("save_path", TEST_SAVE)
	if "--restart-check" in OS.get_cmdline_user_args():
		_verify_restart_checkpoint()
		return
	state.call("start_world_with_seed", 12345)
	await process_frame
	await _legacy_migration()
	_event_roundtrip()
	_process_restart()
	await _clock_and_restart()
	_phase_recovery()
	_save_failures()
	_design_compatibility()
	# Runtime resets must not leak ecology or reward history into a new campaign.
	var identity: String = state.get("campaign").data["id"]
	state.call("start_world_with_seed", 12345)
	_expect(state.get("campaign").data["id"] != identity, "Same-seed new game reused campaign identity.")
	_expect(saves.get("_regions_by_body").is_empty(), "New game retained another campaign's ecology.")
	_expect(int(progression.get("discovery_points")) == 0, "Seeded new game retained discoveries.")
	await process_frame
	if failures.is_empty():
		print("M0 campaign migration, snapshot, event, phase and time acceptance passed.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0)
	else:
		for failure in failures:
			push_error(failure)
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)


func _legacy_migration() -> void:
	var creature: Dictionary = Creature.create_default()
	creature["name"] = "M0 retained creature"
	Creature.BaseBlueprint.add_part(creature, Creature.BaseBlueprint.PartLibrary.get_first_part_id_for_category("mouth"))
	# Use a real library part, including all anchor/spine data in the old file.
	Creature.increment_revision(creature)
	_expect(Creature.save_to_file(creature) == OK, "Fixture creature save failed.")
	var first: Dictionary = Building.create_default()
	var second: Dictionary = Building.create_default()
	second["name"] = "Workshop"
	_expect(not Building.save_design(first, "Home").is_empty(), "First building save failed.")
	_expect(not Building.save_design(second, "Workshop").is_empty(), "Second building save failed.")
	# Strip new IDs to reproduce the unmodified V2 + separate editor layout.
	var originals: Dictionary = {}
	for path in Store.capture().keys():
		var design: Dictionary = JSON.parse_string(Store.read_text(path))
		design.erase("design_id")
		if path == Creature.SAVE_PATH:
			design["progression"]["phase"] = "creature"
		_expect(Atomic.write(path, design, false) == OK, "Legacy fixture could not be written.")
		originals[path] = FileAccess.get_file_as_string(path)
	saves.call("reset_runtime_for_new_game")
	progression.call("register_species_discovery", 77, Factory.create_species(77), 12345)
	progression.call("register_region_discovery", Vector2i(2, -3), 12345)
	var regions: Dictionary = {}
	for seed_value in [12345, 98765]:
		state.call("activate_planet", 12345, 0 if seed_value == 12345 else 1, seed_value)
		await process_frame
		var simulation := Ecology.new()
		root.add_child(simulation)
		await process_frame
		simulation.call("get_region_state", Vector2i(2, -3))
		simulation.call("register_plant_consumption", Vector2i(2, -3), 0.2)
		regions[str(seed_value)] = simulation.call("export_state")
		simulation.queue_free()
		await process_frame
	var old_state: Dictionary = state.call("export_state")
	old_state.erase("campaign")
	old_state.erase("body_id")
	old_state.erase("system_id")
	old_state["schema"] = 2
	var old_progression: Dictionary = progression.call("export_state")
	for entry in old_progression["discovered_species"].values():
		entry.erase("id")
		entry.erase("body_id")
	for entry in old_progression["discovered_regions"].values():
		entry.erase("id")
		entry.erase("body_id")
	# The released seed-keyed format predates body-scoped discovery keys.
	old_progression.discovered_species = {"12345:77": old_progression.discovered_species.values()[0]}
	old_progression.discovered_regions = {"12345:2:-3": old_progression.discovered_regions.values()[0]}
	old_progression.schema = 5
	var legacy: Dictionary = {"schema": 2, "game_state": old_state,
		"progression": old_progression, "player": {"position": [23.5, 8.0, -71.0], "yaw": 1.5, "health_ratio": 0.6},
		"regions_by_world": regions}
	_expect(Atomic.write(TEST_SAVE, legacy, false) == OK, "Legacy campaign fixture failed.")
	_expect(bool(saves.call("load_now")), "Legacy campaign did not migrate.")
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE + ".schema2.backup.json"))
	_expect(backup["design_files"] == originals, "Migration backup did not preserve exact design bytes.")
	_expect(JSON.parse_string(backup["legacy_save_text"]) == JSON.parse_string(JSON.stringify(legacy)), "Migration backup changed campaign data.")
	var migrated_creature: Dictionary = Creature.load_best_available()
	_expect(migrated_creature["name"] == creature["name"], "Creature name lost during migration.")
	_expect(Creature.get_revision(migrated_creature) == 1, "Creature revision lost.")
	_expect(not migrated_creature["progression"].has("phase"), "Creature owns a second campaign phase.")
	_expect(Building.list_designs().size() == 2, "Migration lost a building design.")
	_expect(int(progression.get("discovery_points")) == 4, "Migration changed discovery rewards.")
	_expect(saves.get("_regions_by_body").size() == 2, "Migration lost a visited planet.")
	_expect(bool(saves.call("save_now")), "Migrated campaign did not save.")
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	_expect(snapshot["player"]["surface_address"]["position"] == [23.5, 8.0, -71.0], "Legacy position moved during migration.")
	_expect(snapshot["player"]["surface_address"]["mode"] == "legacy_plane_v9", "Old save was converted to a new surface.")
	_expect(int(Atomic.parse_dictionary(FileAccess.get_file_as_string(TEST_SAVE + ".bak")).get("schema", 0)) == saves.SAVE_SCHEMA, "First migration backup omitted the joint design snapshot.")
	var identities: Dictionary = snapshot["game_state"]["campaign"].duplicate(true)
	# Missing/torn editor files cannot split the loaded campaign snapshot.
	DirAccess.remove_absolute(Creature.SAVE_PATH)
	for name in Building.list_designs():
		DirAccess.remove_absolute(Building.get_design_path(name))
	saves.call("reset_runtime_for_new_game")
	_expect(bool(saves.call("load_now")), "Complete snapshot did not restore without editor files.")
	_expect(Creature.load_best_available()["design_id"] == migrated_creature["design_id"], "Creature identity changed after reload.")
	_expect(Building.list_designs().size() == 2, "Bundled building registry did not restore.")
	_expect(_json_value(state.get("campaign").data) == _json_value(identities), "Campaign IDs/state changed on restart.")
	var repeated: Dictionary = progression.call("register_species_discovery", 77, Factory.create_species(77), 12345)
	_expect(not repeated["is_new"] and int(progression.get("discovery_points")) == 4, "Reload rewarded an old discovery twice.")


func _event_roundtrip() -> void:
	var campaign = state.get("campaign")
	var event = campaign.next_event(GameEvent.Kind.INTERACTION, campaign.data["player_species_id"], 0, "befriended")
	_expect(bool(state.call("record_campaign_event", event)), "Valid interaction was rejected.")
	_expect(not bool(state.call("record_campaign_event", event)), "Repeated interaction was accepted.")
	_expect(bool(saves.call("save_now")), "Event checkpoint failed.")
	saves.call("load_now")
	_expect(not bool(state.call("record_campaign_event", event)), "Event was accepted again after reload.")
	var cursor: int = int(campaign.data["event_cursors"][event.channel()])
	event.campaign_id = "different_campaign"
	event.sequence += 1
	_expect(not bool(state.call("record_campaign_event", event)), "Foreign campaign event was accepted.")
	event.campaign_id = campaign.data["id"]
	event.outcome = "clicked"
	_expect(not bool(state.call("record_campaign_event", event)), "Incomplete behavior produced an event.")
	_expect(int(campaign.data["event_cursors"][event.channel()]) == cursor, "Invalid event consumed a sequence.")
	for index in range(40):
		var next = campaign.next_event(GameEvent.Kind.CONFLICT_RESULT, "encounter_%d" % index, 0, "won")
		state.call("record_campaign_event", next)
	_expect(campaign.data["recent_events"].size() == 32, "Diagnostic event history grew without limit.")
	_expect(campaign.data["event_cursors"].size() <= 4, "Reward cursors grew per event instead of per producer/kind.")


func _clock_and_restart() -> void:
	var campaign = state.get("campaign")
	campaign.data["elapsed_seconds"] = 12.5
	state.call("set_simulation_speed", 2.0)
	_expect(is_equal_approx(float(state.call("simulation_delta", 1.5)), 3.0), "Campaign speed was not applied.")
	state.call("_process", 2.0)
	_expect(is_equal_approx(float(campaign.data["elapsed_seconds"]), 12.5), "Editor/no-player time advanced campaign.")
	var player := Node3D.new()
	player.add_to_group(&"player")
	root.add_child(player)
	player.set_physics_process(true)
	state.call("_process", 2.0)
	_expect(is_equal_approx(float(campaign.data["elapsed_seconds"]), 16.5), "Campaign clock did not use gameplay delta.")
	state.call("set_simulation_speed", 0.0)
	state.call("_process", 200.0)
	_expect(is_equal_approx(float(campaign.data["elapsed_seconds"]), 16.5), "Paused simulation advanced.")
	_expect(not bool(state.call("set_simulation_speed", -1.0)), "Invalid simulation speed accepted.")
	paused = true
	await process_frame
	_expect(is_equal_approx(float(campaign.data["elapsed_seconds"]), 16.5), "SceneTree pause advanced campaign.")
	paused = false
	player.queue_free()
	await process_frame
	saves.call("save_now")
	campaign.data["elapsed_seconds"] = 99999.0
	saves.call("load_now")
	_expect(is_equal_approx(float(campaign.data["elapsed_seconds"]), 16.5), "Reload used wall clock or lost campaign time.")
	state.call("set_simulation_speed", 1.0)


func _phase_recovery() -> void:
	_expect(not bool(saves.call("request_phase_transition", 1)), "Unimplemented tribe gameplay unlocked through phase enum.")
	_expect(not bool(saves.call("debug_prepare_phase_transition", 3)), "Debug transition skipped phases.")
	_expect(bool(saves.call("debug_prepare_phase_transition", 1)), "Phase prepare checkpoint failed.")
	_expect(int(state.get("current_phase")) == 0, "Prepared transition switched phase before commit.")
	var identity: String = state.get("campaign").data["player_species_id"]
	# Simulated restart at the interruption point: load the committed prepare file.
	_expect(bool(saves.call("load_now")), "Interrupted phase transition did not resume.")
	_expect(int(state.get("current_phase")) == 1, "Resumed transition did not enter target phase.")
	_expect(state.get("campaign").data["player_species_id"] == identity, "Phase transition replaced species identity.")
	var events: Dictionary = state.get("campaign").data["event_cursors"].duplicate(true)
	saves.call("load_now")
	_expect(state.get("campaign").data["completed_transitions"].size() == 1, "Phase transition completed twice.")
	_expect(_json_value(state.get("campaign").data["event_cursors"]) == _json_value(events), "Reload emitted phase completion twice.")
	_expect(bool(saves.call("debug_prepare_phase_transition", 2)), "Second phase preparation failed.")
	_expect(not bool(saves.call("resume_phase_transition", "user://missing_directory/save.json")), "Failed phase commit reported success.")
	_expect(int(state.get("current_phase")) == 1, "Failed phase commit changed live phase.")
	_expect(not state.get("campaign").data["pending_transition"].is_empty(), "Failed phase commit discarded retry state.")
	_expect(bool(saves.call("resume_phase_transition")), "Prepared transition could not be retried.")


func _save_failures() -> void:
	saves.call("save_now")
	var previous: String = FileAccess.get_file_as_string(TEST_SAVE)
	var file := FileAccess.open(TEST_SAVE + ".tmp", FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	_expect(bool(saves.call("load_now")), "Uncommitted temporary file displaced valid snapshot.")
	_expect(FileAccess.get_file_as_string(TEST_SAVE) == previous, "Loading changed a committed snapshot.")
	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	_expect(bool(saves.call("load_now")), "Corrupt current snapshot did not recover complete backup.")
	_expect(not saves.get("last_migration_report").is_empty(), "Recovery produced no report.")
	var future: Dictionary = JSON.parse_string(previous)
	future["schema"] = 999
	Atomic.write(TEST_SAVE, future, false)
	_expect(not bool(saves.call("load_now")), "Newer schema was silently downgraded.")
	_expect(not bool(saves.call("save_now")), "Autosave could overwrite a newer schema.")
	_expect(int(JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))["schema"]) == 999, "Newer save was overwritten.")
	var unsupported_generator: Dictionary = JSON.parse_string(previous)
	unsupported_generator["game_state"]["campaign"]["bodies"].values()[0]["generator_version"] = "planetary_v99"
	Atomic.write(TEST_SAVE, unsupported_generator, false)
	_expect(not bool(saves.call("load_now")), "Unsupported generator silently loaded an older backup.")
	_expect(not bool(saves.call("save_now")), "Unsupported generator could be overwritten.")
	Atomic.write(TEST_SAVE, JSON.parse_string(previous), false)
	_expect(bool(saves.call("load_now")), "Compatible save did not unblock recovery.")


func _design_compatibility() -> void:
	var creature: Dictionary = Creature.create_default()
	creature["body"]["part_id"] = "unavailable_body"
	Creature.normalize(creature)
	_expect(creature["body"]["missing_part_id"] == "unavailable_body", "Missing body identity was discarded.")
	_expect(not creature["compatibility_warnings"].is_empty(), "Missing body fallback was silent.")
	Creature.save_to_file(creature, "user://missing_part_test.json")
	var restored: Dictionary = Creature.load_from_file("user://missing_part_test.json")
	_expect(restored["body"]["missing_part_id"] == "unavailable_body", "Missing body could not roundtrip.")
	var building: Dictionary = Building.create_default()
	building["parts"][0]["part_id"] = "unavailable_wall"
	Building.normalize(building)
	Building.save_to_file(building, "user://missing_building_test.json")
	var loaded: Dictionary = Building.load_from_file("user://missing_building_test.json")
	_expect(loaded["parts"][0]["missing_part_id"] == "unavailable_wall", "Missing building part was discarded.")
	_expect(loaded["design_id"] == building["design_id"], "Building ID changed after fallback/reload.")
	var first: Dictionary = Factory.create_species(777)
	var second: Dictionary = Factory.create_species(777)
	_expect(first == second, "Procedural species/designs lost determinism.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _json_value(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _process_restart() -> void:
	_expect(bool(saves.call("save_now")), "Restart checkpoint could not be saved.")
	var expected: Dictionary = {"campaign": state.get("campaign").export_state(),
		"progression": progression.call("export_state"), "creature": Creature.load_best_available(),
		"buildings": Building.list_designs()}
	# Creature transforms are Variants; compare identity, not their debug strings.
	expected["creature"] = {"design_id": expected["creature"]["design_id"], "revision": Creature.get_revision(expected["creature"])}
	Atomic.write("user://m0_restart_expected.json", expected, false)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/campaign_foundation_test.gd", "--", "--restart-check"], output, true)
	_expect(code == 0, "Separate Godot process failed to restore the checkpoint: " + str(output))
	_expect(str(output).contains("M0 separate-process restart passed"), "Restart probe did not execute.")


func _verify_restart_checkpoint() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://m0_restart_expected.json"))
	_expect(not expected.is_empty(), "Restart expectations missing.")
	if expected.is_empty():
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	_expect(bool(saves.call("load_now")), "Separate process did not load checkpoint.")
	_expect(_json_value(state.get("campaign").export_state()) == expected["campaign"], "Campaign identity/events/time changed across processes.")
	_expect(_json_value(progression.call("export_state")) == expected["progression"], "Discovery state changed across processes.")
	var creature: Dictionary = Creature.load_best_available()
	_expect(creature["design_id"] == expected["creature"]["design_id"], "Creature identity changed across processes.")
	_expect(Creature.get_revision(creature) == int(expected["creature"]["revision"]), "Creature revision changed across processes.")
	_expect(Building.list_designs() == expected["buildings"], "Building registry changed across processes.")
	if failures.is_empty():
		print("M0 separate-process restart passed")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0)
	else:
		for failure in failures:
			push_error(failure)
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
