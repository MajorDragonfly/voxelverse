extends SceneTree
const Library = preload("res://assembly/exchange/creature_design_library.gd")
const Starter = preload("res://assembly/exchange/creature_start_templates.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	if "--library-restart" in OS.get_cmdline_user_args():
		_restart(saves)
	else:
		_storage()
		_starter(saves)
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_design_library_test.gd", "--", "--library-restart"], output, true)
		_expect(code == 0 and str(output).contains("CREATURE_DESIGN_LIBRARY_PASSED") and not str(output).contains("ERROR:"), "Offline restart failed: " + str(output))
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("CREATURE_DESIGN_LIBRARY_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _storage() -> void:
	var templates: Array[Dictionary] = Starter.packages()
	_expect(templates.size() == 3, "Three built-in starting forms were not produced")
	if templates.size() != 3: return
	_expect(Library.read().ok and Library.read().packages.is_empty(), "Empty installation did not have an empty library")
	var original: Dictionary = templates[0].duplicate(true)
	var native: Dictionary = Package.inspect(original).preview
	var before: String = var_to_str(native)
	var first: Dictionary = Library.save_variant(native, "Meine Kreatur")
	_expect(first.ok, "Saving variant failed: " + str(first))
	_expect(var_to_str(native) == before, "Saving a variant modified the live design")
	var stored: Dictionary = Library.get_package(first.get("key", ""))
	_expect(stored.ok and stored.package.design_id != original.design_id, "Variant retained source design identity")
	if not stored.ok: return
	_expect(stored.package.provenance[0].design_id == native.design_id, "Variant lost its source")
	var second: Dictionary = Library.save_variant(native, "Meine Kreatur")
	_expect(second.ok and second.key != first.key and Library.read().packages.size() == 2, "Equal names collided")
	var bytes: String = FileAccess.get_file_as_string(Library.PATH)
	_expect(Library.add(stored.package).code == "already_present" and FileAccess.get_file_as_string(Library.PATH) == bytes, "Duplicate import rewrote the library")
	var conflict: Dictionary = stored.package.duplicate(true)
	conflict.blueprint.appearance.base_color = "ffffff"
	_expect(Library.add(conflict).code == "revision_conflict" and FileAccess.get_file_as_string(Library.PATH) == bytes, "Changed immutable revision replaced a library entry")
	_expect(Package.write_file("user://incoming.json", original).ok, "Incoming file fixture failed")
	var imported: Dictionary = Library.import_file("user://incoming.json")
	_expect(imported.ok, "Import did not create a local copy")
	DirAccess.remove_absolute("user://incoming.json")
	_expect(Library.get_package(imported.get("key", "")).ok, "Library retained a source-file dependency")
	_expect(Library.remove(second.key).ok and not Library.get_package(second.key).ok, "Removing a selected variant failed")
	_expect(Library.get_package(first.key).ok, "Removing a same-name variant affected another identity")
	_expect(Library.add(original, "user://missing-folder/library.json").code == "write_failed", "Failed library write reported success")
	Atomic.write("user://future-library.json", {"schema": 99, "packages": []}, false)
	bytes = FileAccess.get_file_as_string("user://future-library.json")
	_expect(not Library.add(original, "user://future-library.json").ok and not Library.remove(first.key, "user://future-library.json").ok, "Future library accepted mutation")
	_expect(FileAccess.get_file_as_string("user://future-library.json") == bytes, "Future library bytes were replaced")
	var malformed: Dictionary = original.duplicate(true)
	malformed.blueprint.progression = {"unlocked_parts": ["everything"]}
	bytes = FileAccess.get_file_as_string(Library.PATH)
	_expect(not Library.add(malformed).ok and FileAccess.get_file_as_string(Library.PATH) == bytes, "Untrusted fields reached durable library")
	# A blocked staging path must preserve the last complete library.
	DirAccess.make_dir_absolute(Library.PATH + ".tmp")
	_expect(not Library.add(templates[1]).ok and FileAccess.get_file_as_string(Library.PATH) == bytes, "Failed staging destroyed library")
	DirAccess.remove_absolute(Library.PATH + ".tmp")
	Atomic.write("user://library-expectations.json", {"variant_key": first.key, "import_key": imported.key}, false)


func _starter(saves: Node) -> void:
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	var templates: Array[Dictionary] = Starter.packages()
	for package in templates:
		var current: Dictionary = Creature.create_default()
		var result: Dictionary = Starter.prepare(package, current)
		_expect(result.ok, "Starter cannot be used without extra unlocks: " + str(result))
	var original_slot: String = saves.create_slot("Original campaign", 15838)
	_expect(not original_slot.is_empty(), "Original slot fixture failed")
	var original_bytes: String = FileAccess.get_file_as_string(original_slot)
	var before_campaign: Dictionary = state.export_state()
	var before_progression: Dictionary = progression.export_state()
	var locked: Dictionary = templates[0].duplicate(true)
	locked.blueprint.parts[2].end_part_id = "feet_claws"
	locked.required_parts.append("feet_claws")
	locked.required_parts.sort()
	_expect(saves.create_slot("Blocked", 18842, "cube_sphere_m1_v1", locked).is_empty(), "New-game template bypassed starting unlocks")
	_expect(state.export_state() == before_campaign and progression.export_state() == before_progression and saves.save_path == original_slot, "Rejected start changed current campaign")
	var chosen: Dictionary = templates[2]
	var slot: String = saves.create_slot("Template adventure", 18842, "cube_sphere_m1_v1", chosen)
	_expect(not slot.is_empty(), "Selected starter did not create a playable slot")
	var creature: Dictionary = Creature.load_best_available()
	_expect(creature.design_id != chosen.design_id, "New campaign took the starter's identity")
	_expect(FileAccess.get_file_as_string(original_slot) == original_bytes, "New template adventure overwrote previous save")
	_expect(progression.get_unlocked_part_ids() == Starter.unlocked_parts(), "Template gave new unlocks")
	var original_shape: Dictionary = Package.Schema.project(Creature.serialize_snapshot(creature), Package.Schema.BLUEPRINT)
	Starter.Connections.normalize(creature)
	_expect(Package.Schema.project(Creature.serialize_snapshot(creature), Package.Schema.BLUEPRINT) == original_shape, "Runtime migration changed chosen geometry")
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://library-expectations.json"))
	expected.merge({"slot": slot, "design": Creature.serialize_snapshot(creature), "campaign": state.campaign.export_state(), "progression": progression.export_state()})
	Atomic.write("user://library-expectations.json", expected, false)


func _restart(saves: Node) -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://library-expectations.json"))
	_expect(Library.get_package(expected.variant_key).ok and Library.get_package(expected.import_key).ok, "Restart lost offline variants/import")
	_expect(not FileAccess.file_exists("user://incoming.json"), "Offline proof retained transfer file")
	_expect(saves.select_slot(expected.slot), "Restart failed to load template adventure")
	var creature: Dictionary = Creature.load_best_available()
	_expect(JSON.parse_string(JSON.stringify(Creature.serialize_snapshot(creature))) == expected.design, "Restart altered template authoring data")
	_expect(JSON.parse_string(JSON.stringify(root.get_node("ProgressionService").export_state())) == expected.progression, "Restart changed starting progress")
	for key in ["id", "player_species_id", "player_faction_id", "player_object_id"]:
		_expect(root.get_node("GameState").campaign.data[key] == expected.campaign[key], "Restart changed identity: " + key)


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
