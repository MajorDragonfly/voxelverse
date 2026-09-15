extends SceneTree
## Full-coordinate JSON and historical frozen-body hashes must coexist.
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Evidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const PATH: String = "user://frozen_body_precision.json"
const INDEX: String = "user://frozen_body_precision_index.json"
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--frozen-restart" in OS.get_cmdline_user_args():
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(INDEX))
		_expect(saves.select_slot(expected.slot), "Cold process rejected a legitimate body proof.")
		_expect(saves._design_files.has("user://building_designs/keep.json"), "Cold load fell back past the new design.")
		_expect(state.campaign.data.id == expected.campaign, "Cold load changed campaign identity.")
		_check_nested(Atomic.parse_dictionary(FileAccess.get_file_as_string(PATH)), expected.hashes)
		await _finish()
		return
	var slot: String = saves.create_slot("Frozen proof + precise coordinates", 15838)
	var hashes: Dictionary = {}
	var entries: Array = []
	var old_failures: int = 0
	for seed_value in [15838, 63352, 23757, 42]:
		var body: Dictionary = state.get_current_body_record()
		var descriptor: Dictionary = preload("res://core/campaign/surface_context.gd").descriptor(body)
		descriptor.seed = seed_value
		var catalog: Dictionary = Catalog.create_surface(descriptor, body.surface_context.spawn)
		if seed_value == 15838: body.fauna_catalog = catalog
		for entry: Dictionary in catalog.species:
			Evidence.confirm(entry, root)
			_expect(Evidence.validate(entry).is_empty(), "Fresh body evidence was invalid.")
			hashes[entry.id] = entry.body_evidence.source_sha256
			entries.append(entry.duplicate(true))
			var old_roundtrip: Dictionary = JSON.parse_string(JSON.stringify(entry, "", true, true))
			old_failures += int(not Evidence.validate(old_roundtrip).is_empty())
	var archive: String = "original quoted source: " + JSON.stringify(entries)
	var nested: Dictionary = {"schema": 1, "surface": _coordinates(), "entries": entries, "original_text": archive,
		"owned_copy": entries[0].blueprint.duplicate(true)}
	var original: String = var_to_str(nested)
	_expect(old_failures > 0, "Regression no longer detects the unconditional full-precision writer.")
	_expect(Atomic.write(PATH, nested, false) == OK, "Combined JSON could not be stored.")
	_expect(var_to_str(nested) == original, "Serialization mutated the source body/campaign.")
	for revision in range(3):
		var readback: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(PATH))
		_check_nested(readback, hashes)
		_expect(readback.original_text == archive, "Encoded archive text was rewritten.")
		_expect(readback.owned_copy == readback.entries[0].blueprint, "Copied frozen source diverged from the species.")
		_expect(Atomic.write(PATH, readback) == OK, "Repeated snapshot write failed.")
	saves.record_design("user://building_designs/keep.json", '{"name":"Preserve this latest design"}')
	_expect(saves.save_now(), "Shared snapshot with evidence failed: " + saves.last_error)
	_expect(saves.load_now() and saves._design_files.has("user://building_designs/keep.json"), "Reload lost the latest design.")
	var protected_text: String = FileAccess.get_file_as_string(slot)
	var saved_body: Dictionary = state.get_current_body_record()
	var changed_entry: Dictionary = saved_body.fauna_catalog.species[0]
	changed_entry.blueprint.body.shape["$vector3"][0] += 0.25
	_expect(not Evidence.validate(changed_entry).is_empty(), "Actual changed anatomy retained its old proof.")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(slot) == protected_text, "Changed anatomy was saved under stale proof.")
	_expect(saves.load_now(), "Valid source could not be restored after rejecting changed anatomy.")
	_expect(Atomic.write(INDEX, {"slot":slot,"campaign":state.campaign.data.id,"hashes":hashes}, false) == OK, "Cannot write cold-load expectations.")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--frozen-restart"], output, true)
	_expect(code == 0 and str(output).contains("FROZEN_BODY_SERIALIZATION_PASSED"), "Cold-load regression failed: " + str(output))
	print("FROZEN_BODY_SERIALIZATION_EVIDENCE ", JSON.stringify({"entries":entries.size(), "old_writer_rejections":old_failures, "checks":checks}))
	await _finish()
func _coordinates() -> Dictionary:
	return {"position": [149597870700.03125, -1000000000000.125, 6371000.123456789],
		"u": 0.12345678901234567, "v": -0.9876543210987654, "tiny": 1.2345678901234567e-12}
func _check_nested(value: Dictionary, hashes: Dictionary) -> void:
	_expect(not value.is_empty(), "Snapshot is missing.")
	if value.is_empty(): return
	var source: Dictionary = _coordinates()
	for field in source:
		if source[field] is Array:
			for index in range(source[field].size()):
				_expect(var_to_bytes(float(value.surface[field][index])) == var_to_bytes(source[field][index]), "Global coordinate bits changed.")
		else: _expect(var_to_bytes(float(value.surface[field])) == var_to_bytes(source[field]), "Precise surface address bits changed.")
	for entry: Dictionary in value.entries:
		_expect(entry.body_evidence.source_sha256 == hashes[entry.id] and Evidence.validate(entry).is_empty(), "Existing proof was regenerated or lost.")
func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _finish() -> void:
	for message in failures: push_error(message)
	if failures.is_empty(): print("FROZEN_BODY_SERIALIZATION_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
