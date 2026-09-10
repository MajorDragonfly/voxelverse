extends SceneTree

const Contract = preload("res://assembly/core/blueprint_contract.gd")
const Assembly = preload("res://assembly/core/modular_assembly.gd")
const History = preload("res://assembly/core/modular_assembly_history.gd")
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Building = preload("res://civilization/buildings/building_blueprint.gd")
const Adapter = preload("res://assembly/adapters/creature_assembly_adapter.gd")
const Visual = preload("res://civilization/buildings/building_runtime_visual.gd")
const Store = preload("res://core/persistence/design_store.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const BUILDING_PATH: String = "user://arch23-building.json"
const CREATURE_PATH: String = "user://arch23-creature.json"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	if "--arch23-restart" in OS.get_cmdline_user_args():
		_verify_restart()
	else:
		_versions()
		_limits()
		_roundtrips()
		await _history_and_preview()
		_restart()
		_protected_files(saves)
	if failures.is_empty(): print("ARCH-23 blueprint versions, originals, revisions and restart passed.")
	for failure in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _versions() -> void:
	var future: Dictionary = Building.create_default()
	for section in ["root", "building"]:
		future = Building.create_default()
		if section == "root": future.schema = 2
		else: future.building.schema = 2
		var original: String = var_to_str(future)
		_expect(Contract.inspect(future).code == "future_version", "Future building not identified: " + section)
		Assembly.normalize(future)
		Building.normalize(future)
		_expect(Assembly.add_part(future, "mass_house_core") == -1, "Future building accepted an edit")
		_expect(Building.save_to_file(future, "user://never-created.json") != OK, "Future building saved")
		_expect(Assembly.serialize(future).is_empty() and Assembly.deserialize(future).is_empty(), "Future generic codec accepted data")
		_expect(var_to_str(future) == original, "Future building changed in memory")
	for section in ["version", "assembly", "attachments", "rider"]:
		future = Creature.create_default()
		match section:
			"version": future.version = 8
			"assembly": future.assembly.schema = 8
			"attachments": future.assembly.body_attachments.schema = 2
			"rider": future.assembly.body_attachments.fit_profile = {"schema": 2}
		var original: String = var_to_str(future)
		Creature.normalize(future)
		_expect(Creature.serialize_snapshot(future).is_empty(), "Future creature encoded: " + section)
		_expect(Creature.migrate_snapshot(future).is_empty(), "Future creature migrated: " + section)
		_expect(Adapter.to_modular_blueprint(future).is_empty(), "Lossy adapter accepted future creature")
		_expect(var_to_str(future) == original, "Future creature mutated: " + section)
	_expect(not FileAccess.file_exists("user://never-created.json"), "Rejected save created a file")


func _limits() -> void:
	var data: Dictionary = Building.create_default()
	data.schema = 1.5
	_expect(not Contract.inspect(data).ok, "Fractional schema accepted")
	data = Building.create_default()
	data.parts = ["bad"]
	_expect(not Contract.inspect(data).ok and Assembly.deserialize(data).is_empty(), "Malformed part accepted")
	data = Building.create_default()
	data.parts[1].uid = data.parts[0].uid
	_expect(not Contract.inspect(data).ok, "Duplicate identity accepted")
	data = Building.create_default()
	data.parts[0].position = Vector3(INF, 0, 0)
	_expect(not Contract.inspect(data).ok, "Infinite placement accepted")
	data = Building.create_default()
	data.parts.resize(Contract.MAX_PARTS + 1)
	_expect(not Contract.inspect(data).ok, "Unbounded part count accepted")
	data = Building.create_default()
	data.extensions = {"payload": "x".repeat(Contract.MAX_BYTES)}
	_expect(not Contract.inspect(data).ok, "Unbounded payload accepted")
	_expect(not Contract.inspect_text("{broken").ok, "Malformed JSON accepted")
	data = Creature.create_default()
	data.body.scale = {"invalid": 2}
	_expect(not Contract.inspect(data).ok and Creature.migrate_snapshot(data).is_empty(), "Malformed body transform reached migration")


func _roundtrips() -> void:
	var legacy: Dictionary = Creature.BaseBlueprint._serialize_blueprint(Creature.BaseBlueprint.create_default())
	var legacy_bytes: String = JSON.stringify(legacy)
	var migrated: Dictionary = Creature.migrate_snapshot(legacy, "legacy-fixture")
	_expect(JSON.stringify(legacy) == legacy_bytes, "Migration edited original")
	_expect(migrated.design_id == Creature.migrate_snapshot(legacy, "legacy-fixture").design_id, "Legacy design identity changed")
	var encoded: Dictionary = Creature.serialize_snapshot(migrated)
	_expect(encoded == Creature.serialize_snapshot(Creature.migrate_snapshot(encoded)), "Migration was not idempotent")
	for part in legacy.parts: part.erase("uid")
	var first_migration: Dictionary = Creature.migrate_snapshot(legacy, "legacy-no-uids")
	var second_migration: Dictionary = Creature.migrate_snapshot(legacy, "legacy-no-uids")
	_expect(Contract.inspect(first_migration).ok and first_migration.parts == second_migration.parts, "Missing legacy UIDs were not migrated deterministically")
	var creature: Dictionary = Creature.create_default()
	creature.name = "ARCH23 retained creature"
	creature.extensions = {"org.voxelverse.example": {"schema": 1, "label": "original"}}
	creature.parts[0].extensions = {"example": [1, "retained", true]}
	creature.parts[0].part_revision = 3
	creature.parts[0].shape_scale = Vector3(0.8, 1.2, 1.1)
	creature.assembly.revision = 17
	var original: String = var_to_str(creature)
	_expect(Creature.save_to_file(creature, CREATURE_PATH) == OK, "Creature save failed: " + str(Contract.inspect(creature)) + " / " + str(Contract.inspect(Creature.serialize_snapshot(creature))))
	_expect(var_to_str(creature) == original, "Pure serialization mutated creature")
	var loaded: Dictionary = Creature.load_from_file(CREATURE_PATH)
	_expect(loaded.extensions == JSON.parse_string(JSON.stringify(creature.extensions)) and loaded.parts[0].extensions == JSON.parse_string(JSON.stringify(creature.parts[0].extensions)), "Creature extensions lost")
	_expect(loaded.parts[0].part_revision == 3 and loaded.parts[0].shape_scale.is_equal_approx(creature.parts[0].shape_scale), "Part revision/geometry changed")
	_expect(Adapter.to_modular_blueprint(loaded).design_id == creature.design_id, "Adapter lost design identity")
	var building: Dictionary = Building.create_default()
	building.extensions = {"example": {"schema": 1, "color": "amber"}}
	building.parts[0].extensions = {"maker": "original"}
	building.parts[0].part_revision = 4
	building.revision = 8
	_expect(Building.save_to_file(building, BUILDING_PATH) == OK, "Building save failed")
	loaded = Building.load_from_file(BUILDING_PATH)
	_expect(loaded.extensions == JSON.parse_string(JSON.stringify(building.extensions)) and loaded.parts[0].extensions == building.parts[0].extensions, "Building extensions lost")
	_expect(loaded.parts[0].part_revision == 4, "Building part revision lost")
	var unknown: Dictionary = Assembly.serialize(building)
	unknown.parts[0].part_id = "retired_mass_part"
	_expect(Atomic.write("user://missing-part.json", unknown) == OK, "Unknown part fixture failed")
	loaded = Building.load_from_file("user://missing-part.json")
	_expect(loaded.parts[0].missing_part_id == "retired_mass_part", "Unknown part ID discarded")
	_expect(loaded.parts[0].extensions == building.parts[0].extensions, "Fallback lost extensions")


func _history_and_preview() -> void:
	var data: Dictionary = Building.load_from_file(BUILDING_PATH)
	var history := History.new()
	history.push_state(data)
	var original_position: Vector3 = data.parts[0].position
	Assembly.transform_part(data, 0, Vector3(1, 0, 0))
	_expect(Building.save_to_file(data, BUILDING_PATH, true) == OK and data.revision == 9, "Edit did not persist revision 9")
	var saved: Dictionary = data.duplicate(true)
	data = history.undo(data)
	_expect(data.parts[0].position == original_position, "Undo did not restore placement")
	_expect(Building.save_to_file(data, BUILDING_PATH, true) == OK and data.revision == 10, "Undo reused published revision")
	var redo: Dictionary = history.redo(data)
	_expect(redo.parts[0].position == saved.parts[0].position, "Redo lost placement")
	var before_failure: String = var_to_str(data)
	_expect(Building.save_to_file(data, "user://missing-directory/building.json", true) != OK, "Missing directory unexpectedly writable")
	_expect(var_to_str(data) == before_failure, "Failed save changed revision or content")
	var visual := Visual.new()
	visual.set_blueprint(saved)
	root.add_child(visual)
	await process_frame
	var pinned: String = var_to_str(visual.building_blueprint)
	Assembly.transform_part(saved, 0, Vector3(4, 0, 0))
	_expect(var_to_str(visual.building_blueprint) == pinned, "Existing instance followed mutable blueprint")
	var future: Dictionary = saved.duplicate(true)
	future.schema = 2
	visual.set_blueprint(future)
	_expect(var_to_str(visual.building_blueprint) == pinned, "Preview interpreted future schema")
	visual.queue_free()
	await process_frame


func _restart() -> void:
	var output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/blueprint_contract_test.gd", "--", "--arch23-restart"], output, true)
	_expect(result == 0, "Fresh-process restore failed: " + str(output))


func _verify_restart() -> void:
	var creature: Dictionary = Creature.load_from_file(CREATURE_PATH)
	var building: Dictionary = Building.load_from_file(BUILDING_PATH)
	_expect(not creature.is_empty() and Creature.get_revision(creature) == 17, "Restart lost creature/revision")
	_expect(not building.is_empty() and int(building.get("revision", 0)) == 10, "Restart lost building/revision")
	if not creature.is_empty(): _expect(creature.parts[0].part_revision == 3, "Restart lost creature part revision")
	if not building.is_empty(): _expect(building.parts[0].extensions == {"maker": "original"}, "Restart lost building extension")


func _protected_files(saves: Node) -> void:
	var path: String = "user://arch23-future.json"
	var future: Dictionary = Assembly.serialize(Building.create_default())
	future.building.schema = 2
	future.erase("design_id")
	_expect(Atomic.write(path, future) == OK, "Future fixture failed")
	var original: String = FileAccess.get_file_as_string(path)
	_expect(Building.load_from_file(path).is_empty(), "Future building loaded")
	_expect(Building.save_to_file(Building.create_default(), path) != OK, "Fallback overwrote future file")
	_expect(FileAccess.get_file_as_string(path) == original and not FileAccess.file_exists(path + ".bak"), "Rejected save touched original/backup")
	var creature_future: Dictionary = Creature.serialize_snapshot(Creature.create_default())
	creature_future.assembly.schema = 8
	var files: Dictionary = {Creature.SAVE_PATH: JSON.stringify(creature_future, "\t")}
	saves.set("_design_snapshot_active", true)
	saves.set("_design_files", files.duplicate(true))
	_expect(Creature.save_to_file(Creature.create_default()) != OK, "Future slot draft overwritten")
	_expect(saves.get("_design_files") == files, "Rejected save modified authoritative snapshot")
	var placeholder: Dictionary = Creature.load_best_available()
	Creature.normalize(placeholder)
	_expect(not placeholder.compatibility_warnings.is_empty(), "Protected fallback omitted notice")
	_expect(Creature.save_to_file(placeholder, "user://arch23-placeholder.json") != OK, "Temporary preview could be saved as original")
	_expect(bool(saves.call("_has_unsupported_contract", {"design_files": files})), "Campaign missed nested future creature")
	files = {Building.AUTOSAVE_PATH: original}
	_expect(bool(saves.call("_has_unsupported_contract", {"design_files": files})), "Campaign missed future building")
	saves.call("_upgrade_design_ids", files)
	_expect(files[Building.AUTOSAVE_PATH] == original, "ID migration changed future original")
	saves.set("_design_files", {})
	saves.set("_design_snapshot_active", false)
	root.get_node("GameState").call("start_world_with_seed", 2310)
	saves.autosave_enabled = false
	saves.save_path = "user://arch23-campaign.json"
	_expect(bool(saves.call("save_now")), "Campaign fixture save failed")
	var snapshot: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(saves.save_path))
	snapshot.design_files[Building.AUTOSAVE_PATH] = original
	_expect(Atomic.write(saves.save_path, snapshot) == OK, "Future campaign fixture failed")
	var campaign_bytes: String = FileAccess.get_file_as_string(saves.save_path)
	var backup_bytes: String = FileAccess.get_file_as_string(saves.save_path + ".bak")
	_expect(not bool(saves.call("load_now")), "Future campaign fell back to older backup")
	_expect(not bool(saves.call("save_now")), "Future campaign protection did not block writes")
	_expect(FileAccess.get_file_as_string(saves.save_path) == campaign_bytes and FileAccess.get_file_as_string(saves.save_path + ".bak") == backup_bytes, "Future campaign or backup bytes changed")


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
