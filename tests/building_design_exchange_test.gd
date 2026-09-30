extends SceneTree

const Exchange = preload("res://assembly/exchange/building_design_exchange.gd")
const Package = Exchange.Package
const Building = Package.Building
const Atomic = Package.Atomic
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--building-source" in args:
		_source(args[args.find("--shared") + 1])
	elif "--building-receiver" in args:
		_receiver(args[args.find("--shared") + 1])
	elif "--building-restart" in args:
		_restart(args[args.find("--shared") + 1])
	else:
		_contract_cases()
		_file_cases()
		_separate_installations()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("BUILDING_DESIGN_EXCHANGE_PASSED checks=%d" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _fixture() -> Dictionary:
	var design: Dictionary = Building.create_default()
	design.name = "Hafenhaus Ä"
	design.design_id = "design_building_exchange_fixture"
	design.revision = 17
	design.building.type = "harbor"
	design.building.style_name = "Nordischer Hafen"
	design.parts[0].position = Vector3(-2.25, 0.5, 4.75)
	design.parts[0].rotation = Vector3(0, 45, 15)
	design.parts[0].scale = Vector3(1.25, 0.75, 1.5)
	design.parts[0].mirror_group = "pair_1"
	design.parts[0].socket_id = "foundation.main"
	design.parts[0].tags = ["timber"]
	design.parts[0].part_revision = 4 # Existing generic authored reference, retained.
	design.parts[0].extensions = {"private_part": {"scene_path": "res://private.gd"}}
	design.metadata = {"private_inventory": {"wood": 500}}
	design.extensions = {"private_owner": "campaign_private",
		Package.ORIGIN_KEY: {"schema": 1, "sources": [{"design_id": "design_ancestor", "revision": 2, "author": "Original"}]}}
	design.progression = {"private_unlocks": ["everything"]}
	design.building.production = {"private_free_building": true}
	return design


func _package(source: Dictionary = {}) -> Dictionary:
	var exported: Dictionary = Package.export_blueprint(_fixture() if source.is_empty() else source, {"author": "Author", "description": "Hafengebäude", "tags": ["harbor"]})
	_expect(exported.ok, "Fixture export failed: " + str(exported))
	return exported.get("package", {})


func _contract_cases() -> void:
	var source: Dictionary = _fixture()
	var original: String = var_to_str(source)
	var package: Dictionary = _package(source)
	if package.is_empty(): return
	var text: String = Atomic.stringify(package)
	_expect(not text.contains("private_") and not text.contains("campaign_private"), "Non-design data leaked")
	_expect(var_to_str(source) == original, "Export changed original")
	var decoded: Dictionary = Package.decode(text)
	_expect(decoded.ok, "Precise JSON transfer failed")
	var checked: Dictionary = Package.inspect(package)
	_expect(checked.ok and checked.preview.design_id == source.design_id and checked.preview.revision == 17, "Immutable identity changed")
	if not checked.ok: return
	_expect(checked.preview.parts[0].position == source.parts[0].position and checked.preview.parts[0].rotation == source.parts[0].rotation and checked.preview.parts[0].scale == source.parts[0].scale, "Transforms changed")
	_expect(checked.preview.parts[0].uid == source.parts[0].uid and checked.preview.parts[0].part_revision == 4, "Part identity/reference changed")
	_expect(checked.preview.parts[0].mirror_group == "pair_1" and checked.preview.parts[0].socket_id == "foundation.main", "Attachment fields changed")
	_expect(checked.stats == Building.calculate_stats(checked.preview) and checked.stats.cost > 0, "Local cost calculation missing")
	_expect(Package.export_blueprint(checked.preview).package.blueprint == package.blueprint, "Design geometry failed roundtrip")
	var package_before: String = Atomic.stringify(package)
	var fork: Dictionary = Package.prepare_working_copy(package)
	_expect(fork.ok and fork.blueprint.design_id != package.design_id and fork.blueprint.revision == 0, "Working copy reused immutable source")
	if fork.ok:
		var again: Dictionary = Package.export_blueprint(fork.blueprint)
		_expect(again.ok and again.package.provenance.size() == 2 and again.package.provenance[-1].design_id == package.design_id and again.package.provenance[-1].revision == 17, "Working copy lost provenance")
		Building.Assembly.transform_part(fork.blueprint, 0, Vector3.ONE)
	_expect(Atomic.stringify(package) == package_before and var_to_str(source) == original, "Preparation mutated source/package")
	var legacy: Dictionary = Building.Assembly.serialize(Building.create_default())
	legacy.erase("schema")
	legacy.erase("design_id")
	legacy.erase("revision")
	legacy.building.erase("schema")
	for part: Dictionary in legacy.parts: part.erase("uid")
	var legacy_before: String = Atomic.stringify(legacy)
	var first: Dictionary = Package.export_blueprint(legacy)
	var second: Dictionary = Package.export_blueprint(legacy)
	_expect(first.ok and second.ok and first.package == second.package, "Unversioned migration was not deterministic")
	_expect(Atomic.stringify(legacy) == legacy_before, "Legacy original changed")
	if first.ok: _expect(Package.decode(Atomic.stringify(first.package)).ok, "Migrated legacy transfer failed")
	for field: String in ["schema", "building"]:
		var future: Dictionary = source.duplicate(true)
		if field == "schema": future.schema = 2
		else: future.building.schema = 2
		var future_before: String = var_to_str(future)
		_expect(Package.export_blueprint(future).code == "future_version", "Future local version accepted: " + field)
		_expect(var_to_str(future) == future_before, "Future source modified")
	var mutations: Array[Callable] = [
		func(p): p.schema = 2,
		func(p): p.schema = 0,
		func(p): p.schema = 1.5,
		func(p): p.catalog_revision = 2,
		func(p): p.kind = "creature",
		func(p): p.blueprint.schema = 2,
		func(p): p.blueprint.building.schema = 2,
		func(p): p.blueprint.building.type = "unknown",
		func(p): p.blueprint.stats = {"cost": 0},
		func(p): p.blueprint.building.production = {"wood": 999},
		func(p): p.blueprint.parts[0].scene_path = "res://untrusted.tscn",
		func(p): p.blueprint.parts[0].extensions = {"code": "untrusted"},
		func(p): p.blueprint.parts[0].scale = [0, 1, 1],
		func(p): p.blueprint.parts[0].position = [Package.MAX_OFFSET + 1, 0, 0],
		func(p): p.blueprint.parts[0].position = [INF, 0, 0],
		func(p): p.blueprint.parts[0].rotation = [0, NAN, 0],
		func(p): p.blueprint.parts[1].uid = p.blueprint.parts[0].uid,
		func(p): p.blueprint.parts.resize(Package.MAX_PARTS + 1),
		func(p): p.required_parts = [],
		func(p): p.revision = -1,
		func(p): p.revision = 1.5,
		func(p): p.revision = 9007199254740992.0,
		func(p): p.author = "x".repeat(121),
		func(p): p.description = "x".repeat(2001),
		func(p): p.blueprint.parts[0].socket_id = "../../outside",
		func(p): p.title = " ",
		func(p): p.provenance[0].revision = -1,
		func(p): p.blueprint.parts = [],
	]
	for index in range(mutations.size()):
		var bad: Dictionary = package.duplicate(true)
		mutations[index].call(bad)
		var before: String = var_to_str(bad)
		_expect(not Package.inspect(bad).ok, "Invalid package accepted: %d" % index)
		_expect(var_to_str(bad) == before, "Rejected input modified: %d" % index)
	var missing: Dictionary = package.duplicate(true)
	missing.blueprint.parts[0].part_id = "uninstalled_structure"
	missing.required_parts = Package._requirements(missing.blueprint)
	var missing_before: String = Atomic.stringify(missing)
	_expect(Package.inspect(missing).code == "missing_parts", "Unknown part hidden by fallback")
	_expect(Atomic.stringify(missing) == missing_before, "Missing part reference lost")
	var fallback: Dictionary = source.duplicate(true)
	fallback.parts[0].missing_part_id = "retired_structure"
	_expect(Package.export_blueprint(fallback).code == "missing_part", "Fallback exported as the original")
	var unsupported: Dictionary = source.duplicate(true)
	unsupported.parts[0].scale = Vector3(21, 1, 1)
	_expect(Package.export_blueprint(unsupported).code == "unsupported_geometry", "Export silently clamped scale")
	source.extensions[Package.ORIGIN_KEY].schema = 2
	_expect(Package.export_blueprint(source).code == "invalid_provenance", "Future provenance downgraded")
	_expect(Package.export_blueprint(_fixture(), {"unknown": true}).code == "invalid_metadata", "Unknown metadata accepted")
	_expect(Package.decode("{broken").code == "invalid_json" and not Package.decode("[]").ok, "Broken JSON accepted")
	_expect(Package.decode(" ".repeat(Package.MAX_BYTES + 1)).code == "package_too_large", "Unbounded text parsed")
	var near_limit: Dictionary = Building.Assembly.serialize(Building.create_default())
	for part: Dictionary in near_limit.parts: part.erase("uid")
	near_limit.metadata = {"private_payload": ""}
	var baseline_size: int = JSON.stringify(near_limit).to_utf8_buffer().size()
	near_limit.metadata.private_payload = "x".repeat(Package.MAX_BYTES - baseline_size - 16)
	_expect(Building.Contract.inspect(near_limit, "building").ok, "Near-limit legacy fixture was not valid")
	_expect(Package.export_blueprint(near_limit).code == "unsupported_blueprint", "Legacy expansion crossed limits without a bounded failure")
	var full_origin: Dictionary = package.duplicate(true)
	full_origin.provenance.clear()
	for index in range(8): full_origin.provenance.append({"design_id": "design_%d" % index, "revision": 1, "author": "A"})
	_expect(Package.prepare_working_copy(full_origin).code == "provenance_limit", "Provenance history truncated")
	var maximum: Dictionary = package.duplicate(true)
	maximum.revision = 9007199254740990
	_expect(Package.decode(Atomic.stringify(maximum)).ok and Package.same_content(maximum, Package.decode(Atomic.stringify(maximum)).package), "Large exact revision drifted")


func _file_cases() -> void:
	var package: Dictionary = _package()
	if package.is_empty(): return
	var path: String = "user://portable.building.json"
	_expect(Package.write_file(path, package).ok, "Initial export failed")
	var original: String = FileAccess.get_file_as_string(path)
	_expect(Package.write_file(path, package).code == "already_present", "Repeated export not idempotent")
	_expect(FileAccess.get_file_as_string(path) == original, "Repeated export rewrote bytes")
	var received: Dictionary = Exchange.import_file(path)
	_expect(received.ok and received.key == Exchange.key_of(package), "Inbox import failed")
	_expect(Exchange.import_file(path).code == "already_present", "Repeated inbox import failed")
	var stored: String = FileAccess.get_file_as_string(received.get("path", path))
	var conflict: Dictionary = package.duplicate(true)
	conflict.blueprint.parts[0].position[0] += 1
	_expect(Package.write_file(path, conflict).code == "revision_conflict", "Same revision overwrote export")
	_expect(Exchange.import_package(conflict).code == "revision_conflict", "Same revision overwrote inbox")
	_expect(FileAccess.get_file_as_string(path) == original and FileAccess.get_file_as_string(received.get("path", path)) == stored, "Conflict changed originals")
	conflict.revision += 1
	var newer: Dictionary = Exchange.import_package(conflict)
	_expect(newer.ok and newer.path != received.path and FileAccess.get_file_as_string(received.path) == stored, "New revision replaced old design")
	for text: String in ["{broken", "", Atomic.stringify({"schema": 99, "future": true})]:
		var protected: String = "user://protected-%s.json" % text.sha256_text().left(8)
		_write_text(protected, text)
		_expect(Package.write_file(protected, package).code == "protected_destination", "Protected export replaced")
		_expect(FileAccess.get_file_as_string(protected) == text, "Protected original bytes changed")
	var future_path: String = Exchange.path_for(package, "user://future-inbox")
	DirAccess.make_dir_recursive_absolute(future_path.get_base_dir())
	_write_text(future_path, "{\"schema\":99}")
	_expect(Exchange.import_package(package, "user://future-inbox").code == "protected_destination", "Future inbox revision overwritten")
	_expect(FileAccess.get_file_as_string(future_path) == "{\"schema\":99}", "Future inbox bytes changed")
	_expect(Package.read_file("user://not-found.json").code == "read_failed", "Missing read accepted")
	_write_text("user://oversized.json", " ".repeat(Package.MAX_BYTES + 1))
	_expect(Package.read_file("user://oversized.json").code == "package_too_large", "Oversized file read")
	_expect(Package.write_file("user://missing-parent/export.json", package).code == "write_failed", "Write failure hidden")
	_expect(not FileAccess.file_exists("user://missing-parent/export.json"), "Failed write created destination")
	_write_text("user://blocked-parent", "preserve")
	_expect(Exchange.import_package(package, "user://blocked-parent/inbox").code == "write_failed", "Blocked inbox write accepted")
	_expect(FileAccess.get_file_as_string("user://blocked-parent") == "preserve", "Blocked parent changed")
	_write_text("user://staged.json.tmp", "other-owner")
	_expect(Package.write_file("user://staged.json", package).code == "protected_destination" and FileAccess.get_file_as_string("user://staged.json.tmp") == "other-owner", "Existing staging file overwritten")
	DirAccess.make_dir_absolute("user://busy.json.exchange-lock")
	_expect(Package.write_file("user://busy.json", package).code == "writer_busy" and not FileAccess.file_exists("user://busy.json"), "Concurrent writer lease bypassed")
	DirAccess.remove_absolute("user://busy.json.exchange-lock")
	_expect(not DirAccess.dir_exists_absolute(path + ".exchange-lock"), "Successful write left a lease")


func _separate_installations() -> void:
	var shared: String = ProjectSettings.globalize_path("user://building-exchange-test")
	DirAccess.make_dir_recursive_absolute(shared)
	var environment: Dictionary = {}
	for key: String in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"]:
		environment[key] = OS.get_environment(key) if OS.has_environment(key) else null
	for stage: String in ["source", "receiver", "restart"]:
		var installation: String = "source" if stage == "source" else "receiver"
		for key: String in environment:
			var directory: String = shared.path_join(installation).path_join(key.to_lower())
			DirAccess.make_dir_recursive_absolute(directory)
			OS.set_environment(key, directory)
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/building_design_exchange_test.gd", "--", "--building-" + stage, "--shared", shared], output, true)
		var clean: bool = status == 0 and str(output).contains("BUILDING_DESIGN_EXCHANGE_PASSED")
		for error: String in ["ERROR:", "SCRIPT ERROR", "ObjectDB instances leaked", "Parse Error"]:
			clean = clean and not str(output).contains(error)
		_expect(clean, "Isolated %s failed: %s" % [stage, str(output)])
		if clean: print("BUILDING_TRANSFER_STAGE_PASSED: " + stage)
	for key: String in environment:
		if environment[key] == null: OS.unset_environment(key)
		else: OS.set_environment(key, environment[key])


func _source(shared: String) -> void:
	var source: Dictionary = _fixture()
	var path: String = Building.save_design(source)
	_expect(not path.is_empty(), "Source design save failed")
	if path.is_empty(): return
	var original: String = FileAccess.get_file_as_string(path)
	var exported: Dictionary = Exchange.export_file(Building.load_from_file(path), shared.path_join("transfer.building.json"), {"author": "Original author"})
	_expect(exported.ok, "Source export failed")
	_expect(FileAccess.get_file_as_string(path) == original, "Export changed source design file")
	_expect(Atomic.write(shared.path_join("source-proof.json"), {"directory": OS.get_user_data_dir(), "path": ProjectSettings.globalize_path(path), "text": original}, false) == OK, "Source proof failed")


func _receiver(shared: String) -> void:
	var proof: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(shared.path_join("source-proof.json")))
	_expect(OS.get_user_data_dir() != proof.directory and Building.list_designs().is_empty(), "Receiver shares source installation")
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	var slot: String = saves.create_slot("Building receiver", 13717)
	_expect(not slot.is_empty(), "Receiver campaign creation failed")
	var state_before: String = Atomic.stringify(state.export_state())
	var progress_before: String = Atomic.stringify(progression.export_state())
	var designs_before: String = Atomic.stringify(Building.Store.capture())
	var received: Dictionary = Exchange.import_file(shared.path_join("transfer.building.json"))
	_expect(received.ok, "Receiver import failed: " + str(received))
	if not received.ok: return
	_expect(Atomic.stringify(state.export_state()) == state_before and Atomic.stringify(progression.export_state()) == progress_before, "Import granted building/progression/inventory")
	_expect(Atomic.stringify(Building.Store.capture()) == designs_before and Building.list_designs().is_empty(), "Import silently adopted campaign design")
	var loaded: Dictionary = Package.read_file(received.path)
	var reexport: String = shared.path_join("returned.building.json")
	_expect(Package.write_file(reexport, loaded.package).ok and Package.same_content(loaded.package, Package.read_file(shared.path_join("transfer.building.json")).package), "Independent-user roundtrip changed revision")
	_expect(saves.save_now(), "Receiver campaign commit failed")
	_expect(Atomic.write("user://building-restart-proof.json", {"slot": slot, "inbox": received.path,
		"package": loaded.package, "state": state_before, "progression": progress_before,
		"designs": designs_before, "directory": OS.get_user_data_dir()}, false) == OK, "Receiver restart proof failed")
	DirAccess.remove_absolute(shared.path_join("transfer.building.json"))


func _restart(shared: String) -> void:
	var saved: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://building-restart-proof.json"))
	_expect(not saved.is_empty(), "Restart lost receiver installation")
	if saved.is_empty(): return
	_expect(OS.get_user_data_dir() == saved.directory, "Restart used different user directory")
	_expect(root.get_node("SaveGameService").select_slot(saved.slot), "Restart failed to select slot")
	var package: Dictionary = Package.read_file(saved.inbox)
	_expect(package.ok and Package.same_content(package.package, saved.package), "Offline restart lost design/provenance/revision")
	_expect(Atomic.parse_dictionary(Atomic.stringify(root.get_node("GameState").export_state())) == Atomic.parse_dictionary(saved.state), "Restart changed campaign state")
	_expect(Atomic.parse_dictionary(Atomic.stringify(root.get_node("ProgressionService").export_state())) == Atomic.parse_dictionary(saved.progression), "Restart changed progression")
	_expect(Atomic.stringify(Building.Store.capture()) == saved.designs and Building.list_designs().is_empty(), "Restart created campaign building design")
	var original: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(shared.path_join("source-proof.json")))
	_expect(FileAccess.get_file_as_string(original.path) == original.text, "Receiving/restart changed source original")
	_expect(Package.same_content(package.package, Package.read_file(shared.path_join("returned.building.json")).package), "Returned revision changed")


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Fixture file open failed: " + path)
	if file != null:
		file.store_string(text)
		file.close()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
