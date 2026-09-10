extends SceneTree

const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--exchange-source" in args:
		_source(args[args.find("--shared") + 1])
	elif "--exchange-receiver" in args:
		await _receiver(args[args.find("--shared") + 1])
	elif "--exchange-restart" in args:
		await _restart_receiver()
	else:
		_contract_cases()
		await _preview_roundtrip()
		_separate_installations()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("COMMUNITY_BLUEPRINT_PACKAGE_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _fixture() -> Dictionary:
	var result: Dictionary = Creature.create_default()
	result.name = "Kupferläufer"
	result.assembly.revision = 14
	result.body.shape = Vector3(1.6, 1.15, 2.6)
	result.body.spine[2].width_scale = 1.3
	result.body.spine[3].y_offset = 0.2
	result.body.spine_length_scale = 1.25
	Creature.BaseBlueprint.add_part(result, "legs_stubby")
	Anatomy.reset_all_anchors(result)
	var legs: Array = []
	for part: Dictionary in result.parts:
		if part.category == "legs":
			part.end_part_id = "feet_claws"
			part.joint = {"upper": 1.3, "lower": 0.8, "offset": Vector3(0.1, 0.05, 0.1)}
			part.shape_scale = Vector3(0.8, 1.2, 1.1)
			part.end_shape_scale = Vector3(1.1, 0.9, 1.2)
			part.end_rotation = Vector3(3, 14, -5)
			part.manual_offset = Vector3(0.02, 0.03, 0.04)
			legs.append(part)
	legs[0].paired_uid = legs[1].uid
	legs[1].paired_uid = legs[0].uid
	Anatomy.rebind_all_parts(result)
	result.appearance = {"base_color": "cfa86a", "accent_color": "704b39", "belly_color": "f1dbad",
		"eye_color": "448e9c", "horn_color": "e5dcc8", "skin_type": "scales", "skin_strength": 0.8, "skin_scale": 1.2}
	result.assembly.body_attachments.sockets["saddle.primary"].t = 0.57
	result.assembly.body_attachments.sockets["harness.left"].rotation_degrees = [0.0, 12.0, 0.0]
	result.assembly.body_attachments.fit_profile = {"schema": 1, "rider_scale": 1.1, "leg_spacing": 0.65, "seat_height": 0.3}
	result.progression = {"unlocked_parts": ["private_source_unlock"], "discoveries": ["private_source_discovery"]}
	result.extensions = {"private_campaign": {"owner": "private_owner", "inventory": ["private_item"]}}
	return result


func _contract_cases() -> void:
	var source: Dictionary = _fixture()
	var before: String = var_to_str(source)
	var exported: Dictionary = Package.export_blueprint(source, {"author": "Test author", "tags": ["vierbeinig"]})
	_expect(exported.ok, "Valid export rejected: " + str(exported))
	if not exported.ok: return
	var package: Dictionary = exported.package
	var bytes: String = JSON.stringify(package)
	_expect(not bytes.contains("private_"), "Export leaked campaign/opaque extension fields")
	_expect(var_to_str(source) == before, "Export mutated source")
	_expect(Package.decode(bytes).ok, "JSON transfer failed")
	var current: Dictionary = Creature.create_default()
	current.name = "Empfänger"
	current.assembly.revision = 6
	current.extensions = {"local": "retained"}
	current.progression.discoveries = ["receiver_discovery"]
	var target_before: String = var_to_str(current)
	var imported: Dictionary = Package.prepare_import(package, current, 0, package.required_parts)
	_expect(imported.ok, "Prepared import rejected: " + str(imported))
	if imported.ok:
		_expect(imported.blueprint.design_id == current.design_id and imported.blueprint.name == current.name, "Target identity/name changed")
		_expect(imported.blueprint.progression == current.progression and imported.blueprint.extensions.local == "retained", "Target state lost")
		_expect(imported.blueprint.assembly.revision == 6, "Preparation published a revision before saving")
		var variant: Dictionary = Package.export_blueprint(imported.blueprint)
		_expect(variant.ok and variant.package.provenance[0].design_id == source.design_id, "Re-export lost provenance")
		var uids: Array = []
		for part in imported.blueprint.parts: uids.append(part.uid)
		Creature.BaseBlueprint.add_part(imported.blueprint, "eyes_wide")
		_expect(not imported.blueprint.parts[-1].uid in uids, "Editor reused transferred part identity")
	_expect(var_to_str(current) == target_before and JSON.stringify(package) == bytes, "Import mutated caller/source")
	_expect(Package.prepare_import(package, current, 1, package.required_parts).code == "phase_not_editable", "Later phase accepted species redesign")
	var unlocks: Array = package.required_parts.duplicate()
	unlocks.erase("feet_claws")
	var locked: Dictionary = Package.prepare_import(package, current, 0, unlocks)
	_expect(locked.code == "locked_parts" and locked.missing_parts == ["feet_claws"], "Terminal unlock bypassed")
	current._protected_design_source = "future"
	_expect(Package.prepare_import(package, current, 0, package.required_parts).code == "protected_target", "Protected target accepted import")
	current.erase("_protected_design_source")
	var mutations: Array[Callable] = [
		func(p): p.schema = 2,
		func(p): p.catalog_revision = 2,
		func(p): p.blueprint.version = 8,
		func(p): p.blueprint.assembly.body_attachments.fit_profile.schema = 2,
		func(p): p.blueprint.progression = {"unlocked_parts": ["everything"]},
		func(p): p.blueprint.stats = {"attack": 999999},
		func(p): p.blueprint.parts[0].resource_path = "res://untrusted.gd",
		func(p): p.blueprint.parts[0].joint.script = "res://untrusted.gd",
		func(p): p.blueprint.parts[0].position = [INF, 0, 0],
		func(p): p.blueprint.parts[0].mirrored = "false",
		func(p): p.blueprint.body.shape = [1, 10000, 1],
		func(p): p.blueprint.body.spine[2].t = 0,
		func(p): p.blueprint.parts[0].part_id = "missing_part",
		func(p): p.blueprint.parts[0].category = "legs",
		func(p): p.blueprint.parts[0].end_part_id = "feet_claws",
		func(p): p.blueprint.parts[0].paired_uid = "missing_uid",
		func(p): p.blueprint.parts[1].uid = p.blueprint.parts[0].uid,
		func(p): p.blueprint.appearance.base_color = "not_a_color",
		func(p): p.required_parts = [],
		func(p): p.blueprint.parts.resize(Package.Schema.MAX_PARTS + 1),
		func(p): p.description = "x".repeat(2001),
		func(p): p.author = {"bad": true},
	]
	for index in range(mutations.size()):
		var bad: Dictionary = package.duplicate(true)
		mutations[index].call(bad)
		var original: String = var_to_str(bad)
		_expect(not Package.prepare_import(bad, current, 0, package.required_parts).ok, "Invalid package accepted: %d" % index)
		_expect(var_to_str(bad) == original and var_to_str(current) == target_before, "Rejected import mutated inputs: %d" % index)
	_expect(not Package.decode("{broken").ok and not Package.decode("[]").ok, "Invalid JSON accepted")
	_expect(Package.decode(" ".repeat(Package.Schema.MAX_BYTES + 1)).code == "package_too_large", "Unbounded text parsed")
	var unknown: Dictionary = package.duplicate(true)
	unknown.required_parts.erase(unknown.blueprint.parts[0].part_id)
	unknown.blueprint.parts[0].part_id = "uninstalled_part"
	unknown.required_parts.append("uninstalled_part")
	unknown.required_parts.sort()
	_expect(Package.inspect(unknown).code == "unknown_part", "Truthful manifest accepted an unknown part")
	var future_source: Dictionary = source.duplicate(true)
	future_source.parts[0].part_revision = 2
	_expect(Package.export_blueprint(future_source).code == "unsupported_catalog", "Export discarded an unsupported part revision")
	future_source = source.duplicate(true)
	future_source.extensions[Package.ORIGIN_KEY] = {"schema": 2, "sources": []}
	_expect(Package.export_blueprint(future_source).code == "invalid_provenance", "Export downgraded future provenance")
	_expect(Package.export_blueprint(source, {"tags": "bad"}).code == "invalid_metadata", "Malformed local metadata was accepted")
	# Float32 Vector3 boundaries must survive decimal JSON (e.g. 0.3 and 2.4).
	for shape in [Vector3(0.55, 0.45, 0.85), Vector3(3.0, 2.4, 4.5)]:
		var boundary: Dictionary = source.duplicate(true)
		boundary.body.shape = shape
		boundary.parts[2].joint.offset = Vector3(-0.6, 0.3, 0.6)
		var exported_boundary: Dictionary = Package.export_blueprint(boundary)
		_expect(exported_boundary.ok, "Legal editor boundary rejected: " + str(exported_boundary))
		if exported_boundary.ok:
			_expect(Package.decode(JSON.stringify(exported_boundary.package)).ok, "JSON rejected a legal Vector3 boundary")
	var costly: Dictionary = package.duplicate(true)
	for index in range(40):
		var part: Dictionary = costly.blueprint.parts[0].duplicate(true)
		part.uid = "costly_%d" % index
		costly.blueprint.parts.append(part)
	_expect(Package.prepare_import(costly, current, 0, package.required_parts).code == "complexity_exceeded", "Form budget bypassed")
	_file_cases(package)


func _file_cases(package: Dictionary) -> void:
	var path: String = "user://immutable.creature.json"
	_expect(Package.write_file(path, package).ok and Package.write_file(path, package).ok, "Idempotent export failed")
	var original: String = FileAccess.get_file_as_string(path)
	var changed: Dictionary = package.duplicate(true)
	changed.title = "Changed without revision"
	_expect(Package.write_file(path, changed).code == "destination_conflict", "Existing revision replaced")
	_expect(FileAccess.get_file_as_string(path) == original, "Conflict altered original file")
	changed.schema = 99
	Atomic.write("user://future.creature.json", changed, false)
	var future: String = FileAccess.get_file_as_string("user://future.creature.json")
	_expect(Package.write_file("user://future.creature.json", package).code == "protected_destination", "Future file overwritten")
	_expect(FileAccess.get_file_as_string("user://future.creature.json") == future, "Future file bytes changed")
	_expect(Package.write_file("user://absent/package.json", package).code == "write_failed", "Unavailable destination accepted")
	_expect(not FileAccess.file_exists("user://absent/package.json"), "Failed export created final file")


func _preview_roundtrip() -> void:
	var source: Dictionary = _fixture()
	var exported: Dictionary = Package.export_blueprint(source)
	if not exported.ok: return
	var decoded: Dictionary = Package.decode(JSON.stringify(exported.package))
	var checked: Dictionary = Package.inspect(decoded.package)
	var first := Preview.new()
	var second := Preview.new()
	root.add_child(first)
	root.add_child(second)
	first.set_editor_state(source, -1, -1, false)
	second.set_editor_state(checked.preview, -1, -1, false)
	await process_frame
	_expect(_geometry(first) == _geometry(second), "Actual renderer geometry/materials changed after file transfer")
	_expect(not _geometry(first).is_empty(), "Preview assertion had no geometry")
	for id: String in Creature.BodyAttachments.IDS:
		_expect(first.body_socket(id) == second.body_socket(id), "Transferred socket moved: " + id)
	first.queue_free()
	second.queue_free()
	await process_frame


func _geometry(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D and node.mesh != null:
		var geometry: Array = []
		for index in range(node.mesh.get_surface_count()): geometry.append(node.mesh.surface_get_arrays(index))
		var material: Material = node.get_active_material(0)
		result.append([node.name, node.transform, node.mesh.get_aabb(), geometry,
			material.albedo_color if material is StandardMaterial3D else Color.WHITE])
	elif node is MultiMeshInstance3D and node.multimesh != null:
		result.append([node.name, node.transform, node.multimesh.buffer])
	for child in node.get_children(): result.append_array(_geometry(child))
	return result


func _separate_installations() -> void:
	var shared: String = ProjectSettings.globalize_path("user://exchange-test")
	DirAccess.make_dir_recursive_absolute(shared)
	var original_environment: Dictionary = {}
	for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"]:
		original_environment[key] = OS.get_environment(key) if OS.has_environment(key) else null
	for stage in ["source", "receiver", "restart"]:
		var installation: String = "source" if stage == "source" else "receiver"
		for key: String in original_environment:
			var directory: String = shared.path_join(installation).path_join(key.to_lower())
			DirAccess.make_dir_recursive_absolute(directory)
			OS.set_environment(key, directory)
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/community_blueprint_package_test.gd", "--", "--exchange-" + stage, "--shared", shared], output, true)
		var clean: bool = status == 0 and str(output).contains("COMMUNITY_BLUEPRINT_PACKAGE_PASSED")
		for error in ["ERROR:", "SCRIPT ERROR", "ObjectDB instances leaked", "Parse Error"]:
			clean = clean and not str(output).contains(error)
		_expect(clean, "Isolated %s failed: %s" % [stage, str(output)])
		if clean: print("COMMUNITY_TRANSFER_STAGE_PASSED: " + stage)
	for key: String in original_environment:
		if original_environment[key] == null: OS.unset_environment(key)
		else: OS.set_environment(key, original_environment[key])


func _source(shared: String) -> void:
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	var path: String = saves.create_slot("Source campaign", 15838)
	_expect(not path.is_empty(), "Source campaign creation failed")
	var creature: Dictionary = _fixture()
	_expect(Creature.save_to_file(creature) == OK and saves.save_now(), "Source save failed")
	var package: Dictionary = Package.export_blueprint(Creature.load_best_available(), {"author": "Source author"})
	_expect(package.ok, "Source export failed: " + str(package))
	if not package.ok: return
	var bytes: String = JSON.stringify(package.package)
	for key in ["id", "player_species_id", "player_faction_id", "player_object_id"]:
		_expect(not bytes.contains(state.campaign.data[key]), "Campaign identity leaked: " + key)
	_expect(Package.write_file(shared.path_join("transfer.creature.json"), package.package).ok, "Transfer file write failed")


func _receiver(shared: String) -> void:
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	_expect(not FileAccess.file_exists(Creature.SAVE_PATH), "Receiver inherited source user directory")
	var path: String = saves.create_slot("Receiver campaign", 18842)
	_expect(not path.is_empty(), "Receiver campaign creation failed")
	var current: Dictionary = Creature.load_best_available()
	current.name = "Meine Spezies"
	current.assembly.revision = 3
	current.progression.discoveries = ["receiver_only"]
	_expect(Creature.save_to_file(current) == OK and saves.save_now(), "Receiver starting point failed")
	var transfer: Dictionary = Package.read_file(shared.path_join("transfer.creature.json"))
	if not transfer.ok:
		_expect(false, "Transfer read failed: " + str(transfer))
		return
	# A local discovery authorizes these parts; no downloaded unlock is merged.
	for id: String in transfer.package.required_parts: progression.unlock_part(id, "Receiver fixture discovery")
	progression.discovery_points = 19
	var before_progression: Dictionary = progression.export_state()
	var before_campaign: Dictionary = state.campaign.export_state()
	var prepared: Dictionary = Package.prepare_for_active_editor(transfer.package, current)
	_expect(prepared.ok, "Receiver import failed: " + str(prepared))
	if not prepared.ok: return
	_expect(state.campaign.export_state() == before_campaign and progression.export_state() == before_progression, "Preparation mutated campaign")
	# This is the existing explicit editor save path, not a second campaign saver.
	Creature.increment_revision(prepared.blueprint)
	_expect(Creature.save_to_file(prepared.blueprint) == OK and saves.save_now(), "Adopted design save failed")
	_expect(Creature.get_revision(prepared.blueprint) == 4, "Adoption did not publish the receiving revision")
	_expect(progression.export_state() == before_progression, "Adoption changed receiver progression")
	for key in ["id", "player_species_id", "player_faction_id", "player_object_id"]:
		_expect(state.campaign.data[key] == before_campaign[key], "Adoption changed receiver identity: " + key)
	_expect(prepared.blueprint.design_id != transfer.package.design_id, "Receiver inherited source design identity")
	Atomic.write("user://receiver-expectations.json", {"slot": path, "campaign": before_campaign,
		"progression": before_progression, "design": Creature.serialize_snapshot(prepared.blueprint),
		"user_directory": OS.get_user_data_dir()}, false)
	# The receiver's saved design/provenance has no dependency on the transfer file.
	DirAccess.remove_absolute(shared.path_join("transfer.creature.json"))
	await process_frame


func _restart_receiver() -> void:
	var saved: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://receiver-expectations.json"))
	_expect(not saved.is_empty(), "Restart did not find receiver installation")
	if saved.is_empty(): return
	_expect(OS.get_user_data_dir() == saved.user_directory, "Restart used a different installation")
	var saves: Node = root.get_node("SaveGameService")
	_expect(saves.select_slot(saved.slot), "Fresh process could not select receiver slot")
	var loaded: Dictionary = Creature.load_best_available()
	_expect(JSON.parse_string(JSON.stringify(Creature.serialize_snapshot(loaded))) == saved.design, "Offline restart lost adopted authoring/provenance")
	_expect(JSON.parse_string(JSON.stringify(root.get_node("ProgressionService").export_state())) == saved.progression, "Offline restart changed progress")
	for key in ["id", "player_species_id", "player_faction_id", "player_object_id"]:
		_expect(root.get_node("GameState").campaign.data[key] == saved.campaign[key], "Restart changed receiving identity: " + key)
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(loaded, -1, -1, false)
	await process_frame
	_expect(not _geometry(preview).is_empty(), "Offline restored template has no preview")
	preview.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
