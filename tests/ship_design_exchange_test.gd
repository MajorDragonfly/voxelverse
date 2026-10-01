extends SceneTree
const Package = preload("res://assembly/exchange/ship_blueprint_package.gd")
const Exchange = preload("res://assembly/exchange/ship_design_exchange.gd")
const Ship = Package.Ship
const Atomic = Package.Atomic
const MeshBuilder = preload("res://assembly/runtime/modular_voxel_mesh_builder.gd")
const Placement = preload("res://space/ships/ship_placement.gd")
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--ship-exchange-stage" in args:
		var index: int = args.find("--ship-exchange-stage")
		_stage(args[index + 1], args[index + 2])
	else:
		_model_checks()
		_storage_checks()
		_process_checks()
	print(JSON.stringify({"test": "ship_design_exchange", "checks": checks,
		"passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _design(role: String = "lander", yaw: int = -1) -> Dictionary:
	var data: Dictionary = Ship.template(role)
	data.revision = 7
	data.name = "Entwurf Ä · " + role
	# Transform the entire assembly, with every permitted quarter turn exercised.
	if yaw < 0: yaw = 90 if role == "lander" else 270
	for part: Dictionary in data.parts:
		var p: Vector3 = part.position
		match yaw:
			0: part.position = p
			90: part.position = Vector3(p.z, p.y, -p.x)
			180: part.position = Vector3(-p.x, p.y, -p.z)
			270: part.position = Vector3(-p.z, p.y, p.x)
		part.position += Vector3(12, 4, 8)
		part.rotation = Vector3(0, yaw, 0)
		part.mirror_group = "pair_example"
		part.socket_id = "socket_example"
		part.tags = ["paint_catalog", "engine"]
	return data


func _package(role: String = "lander") -> Dictionary:
	var exported: Dictionary = Package.export_blueprint(_design(role), {"author": "Lars", "tags": ["test"]})
	_expect(exported.ok, "Native design exports through Ship/Assembly: " + role + " " + exported.code)
	return exported.get("package", {})


func _model_checks() -> void:
	var state_before: String = Atomic.stringify(root.get_node("GameState").export_state())
	for yaw in [0, 90, 180, 270]:
		for role: String in ["expedition", "lander"]:
			var source: Dictionary = _design(role, yaw)
			var exported: Dictionary = Package.export_blueprint(source)
			_expect(exported.ok, "All quarter-turn module transformations can be exported")
			if exported.ok:
				var prepared: Dictionary = Package.prepare_import(Package.decode(Atomic.stringify(exported.package)).package)
				_expect(prepared.ok and _metrics(source) == _metrics(prepared.blueprint), "Every quarter-turn retains catalog colors and geometry")
	for role: String in ["expedition", "lander"]:
		var source: Dictionary = _design(role)
		var before: Dictionary = source.duplicate(true)
		source.cargo = {"gold": 9999}
		source.crew = ["person_secret"]
		source.ship_id = "instance_secret"
		source.place = {"kind": "surface"}
		source.metadata = {"campaign": "private"}
		source.extensions = {"private": {"script": "res://secret.gd"}}
		source.parts[0].inventory = ["private"]
		var snapshot: Dictionary = source.duplicate(true)
		var exported: Dictionary = Package.export_blueprint(source)
		_expect(exported.ok and source == snapshot, "Export never mutates authoring/source data: " + exported.code)
		if not exported.ok: continue
		var encoded: String = Atomic.stringify(exported.package)
		_expect(not encoded.contains("secret") and not encoded.contains("private") and not encoded.contains("inventory"), "Runtime/cargo/crew/opaque extensions are excluded recursively")
		var decoded: Dictionary = Package.decode(encoded)
		_expect(decoded.ok, "Full precision JSON decodes: " + decoded.code)
		if not decoded.ok: continue
		var prepared: Dictionary = Package.prepare_import(decoded.package)
		_expect(prepared.ok and prepared.ready, "Ready design remains ready after decoding")
		_expect(_metrics(before) == _metrics(prepared.blueprint), "Colors, vertex positions, module counts, stats, bounds and bay frames round-trip")
		_expect(Package.same_content(Package.export_blueprint(prepared.blueprint).package, exported.package), "Native re-export retains exact metadata/source revision")
		var copy: Dictionary = prepared.blueprint.duplicate(true)
		copy.design_id = "new_copy_id"
		copy.revision = 1
		copy.name = "My variant"
		var variant: Dictionary = Package.export_blueprint(copy)
		_expect(variant.ok and variant.package.provenance.size() == 1 and variant.package.provenance[0].design_id == source.design_id, "A local variant retains the original source without claiming its author")
		_expect(variant.package.author.is_empty() and variant.package.title == "My variant", "Local variant metadata does not misattribute the original author")
	var package: Dictionary = _package()
	if package.is_empty(): return
	var repeated_modules: Dictionary = Placement.add_attached(Ship.template("lander"), 0, "cargo_s", 0, 0, true).blueprint
	repeated_modules.revision = 1
	var multi: Dictionary = Package.export_blueprint(repeated_modules)
	var received_multi: Dictionary = Package.prepare_import(Package.decode(Atomic.stringify(multi.package)).package)
	_expect(received_multi.ok and Ship.evaluate(received_multi.blueprint).stats.cargo == 36 and _metrics(repeated_modules) == _metrics(received_multi.blueprint), "Three copies of one module retain their counts and individual identities")
	for field: String in ["schema", "payload_schema", "catalog_revision"]:
		for version in [0, 2, 100]:
			var bad: Dictionary = package.duplicate(true)
			bad[field] = version
			_expect(not Package.inspect(bad).ok, "Old/unknown envelope version rejected: " + field)
	for field: String in ["schema", "catalog_revision"]:
		var bad: Dictionary = package.duplicate(true)
		bad.blueprint.ship[field] = 2
		_expect(not Package.inspect(bad).ok, "Unknown native ship/catalog version rejected")
	var changed: Dictionary = package.duplicate(true)
	changed.blueprint.schema = 2
	_expect(not Package.inspect(changed).ok, "Unknown Assembly payload rejected before normalization")
	changed = package.duplicate(true)
	changed.blueprint.parts[0].part_id = "not_installed"
	changed.required_modules.erase("hull_s")
	changed.required_modules.append("not_installed")
	changed.required_modules.sort()
	_expect(Package.inspect(changed).code == "ship.unknown_module", "Unknown module is never substituted")
	changed = package.duplicate(true)
	changed.blueprint.parts[0].part_revision = 2
	_expect(not Package.inspect(changed).ok, "Unknown module revision rejected")
	for field: String in ["script", "crew", "ship_id", "cargo", "capabilities", "place", "color"]:
		changed = package.duplicate(true)
		changed.blueprint.parts[0][field] = "injected"
		_expect(not Package.inspect(changed).ok, "Unknown/downloaded runtime/appearance field rejected: " + field)
		changed = package.duplicate(true)
		changed[field] = "injected"
		_expect(not Package.inspect(changed).ok, "Unknown envelope field rejected: " + field)
		changed = package.duplicate(true)
		changed.blueprint.ship[field] = "injected"
		_expect(not Package.inspect(changed).ok, "Unknown nested ship field rejected: " + field)
	changed = package.duplicate(true)
	changed.required_modules.pop_back()
	_expect(not Package.inspect(changed).ok, "Requirements cannot hide a module")
	changed = package.duplicate(true)
	changed.blueprint.parts[1].uid = changed.blueprint.parts[0].uid
	_expect(not Package.inspect(changed).ok, "Duplicate module UID rejected")
	changed = package.duplicate(true)
	changed.blueprint.design_id = "another"
	_expect(not Package.inspect(changed).ok, "Envelope/payload identity must match")
	for field: String in ["position", "rotation", "scale"]:
		changed = package.duplicate(true)
		changed.blueprint.parts[0][field][0] = 0.5
		_expect(not Package.inspect(changed).ok, "Unsafe/non-grid transform rejected: " + field)
	changed = package.duplicate(true)
	changed.blueprint.parts[0].position[0] = INF
	_expect(not Package.inspect(changed).ok, "Nonfinite transformation rejected")
	changed = package.duplicate(true)
	changed.blueprint.parts[0].position = {"x": 0, "y": 0, "z": 0}
	_expect(not Package.inspect(changed).ok, "Portable vectors use exactly three scalars")
	changed = package.duplicate(true)
	changed.blueprint.parts[0].position[0] = 100
	_expect(Package.inspect(changed).code == "ship.size_limit", "Geometric role limits enforced independently of byte size")
	changed = package.duplicate(true)
	for i in range(Ship.MAX_MODULES):
		var part: Dictionary = changed.blueprint.parts[0].duplicate(true)
		part.uid = "extra_%d" % i
		changed.blueprint.parts.append(part)
	_expect(not Package.inspect(changed).ok, "128-module limit is not enlarged by exchange")
	_expect(Package.decode(" ".repeat(Package.MAX_BYTES + 1)).code == "ship_exchange.package_too_large", "JSON byte budget enforced before parsing")
	_expect(not Package.decode("{broken}").ok and not Package.decode("[]").ok, "Malformed/nonobject JSON rejected")
	changed = package.duplicate(true)
	changed.revision = 0
	_expect(not Package.inspect(changed).ok, "Uncommitted source revision rejected")
	_expect(not Package.export_blueprint(Ship.template("lander")).ok, "Unsaved templates require the normal save command")
	changed = package.duplicate(true)
	changed.blueprint.parts.remove_at(3) # no reactor: safe draft, not a ready ship
	changed.required_modules.erase("reactor_s")
	var unfinished: Dictionary = Package.inspect(changed)
	_expect(unfinished.ok and not unfinished.ready and not Ship.pin(unfinished.preview).ok, "Unfinished draft can be edited but cannot produce a ready pin")
	_expect(Atomic.stringify(root.get_node("GameState").export_state()) == state_before, "Export/inspection/preparation never change campaign or fleet state")


func _storage_checks() -> void:
	var package: Dictionary = _package()
	if package.is_empty(): return
	var state_before: String = Atomic.stringify(root.get_node("GameState").export_state())
	var directory: String = "user://exchange_storage"
	var received: Dictionary = Exchange.import_package(package, directory)
	_expect(received.ok, "Import persists a native design in the local authoring directory")
	if not received.ok: return
	var bytes: String = FileAccess.get_file_as_string(received.path)
	var repeated: Dictionary = Exchange.import_package(package, directory)
	_expect(repeated.ok and repeated.code == "already_present" and bytes == FileAccess.get_file_as_string(received.path), "Repeated same revision is a byte-preserving no-op")
	# Rename demonstrates duplicate detection is based on identity, not filename.
	var renamed: String = directory.path_join("renamed.json")
	DirAccess.rename_absolute(received.path, renamed)
	repeated = Exchange.import_package(package, directory)
	_expect(repeated.ok and repeated.path == renamed and not FileAccess.file_exists(received.path), "Duplicate import finds an existing revision under another filename")
	var conflict: Dictionary = package.duplicate(true)
	conflict.blueprint.name = "Different content"
	_expect(Exchange.import_package(conflict, directory).code == "ship_exchange.revision_conflict" and FileAccess.get_file_as_string(renamed) == bytes, "Same ID/revision with different content preserves the original")
	var next: Dictionary = package.duplicate(true)
	next.revision += 1
	next.blueprint.revision = next.revision
	var added: Dictionary = Exchange.import_package(next, directory)
	_expect(added.ok and added.path != renamed and FileAccess.get_file_as_string(renamed) == bytes, "New revision is stored alongside the original")
	var future: Dictionary = Ship.Assembly.serialize(_design())
	future.ship.schema = 99
	var protected_path: String = directory.path_join("future.json")
	Atomic.write(protected_path, future)
	var protected_bytes: String = FileAccess.get_file_as_string(protected_path)
	_expect(Exchange.import_package(package, directory).code == "ship_exchange.protected_library", "An unsupported original prevents unverifiable uniqueness")
	_expect(FileAccess.get_file_as_string(protected_path) == protected_bytes and FileAccess.get_file_as_string(renamed) == bytes, "Protection preserves both unknown and known original bytes")
	DirAccess.remove_absolute(protected_path)
	var export_path: String = "user://portable_ship.json"
	_expect(Package.write_file(export_path, package).ok, "Immutable portable export is written atomically")
	var export_bytes: String = FileAccess.get_file_as_string(export_path)
	_expect(Package.write_file(export_path, package).code == "already_present", "Duplicate portable write does not rewrite")
	_expect(Package.write_file(export_path, next).code == "ship_exchange.destination_conflict" and FileAccess.get_file_as_string(export_path) == export_bytes, "New exported revision cannot overwrite a prior revision")
	var corrupted: String = "user://corrupted_ship.json"
	_write(corrupted, "{invalid}")
	_expect(Package.write_file(corrupted, package).code == "ship_exchange.protected_destination" and FileAccess.get_file_as_string(corrupted) == "{invalid}", "Corrupt export destination is preserved")
	var future_export: String = "user://future_portable.json"
	var unsupported: Dictionary = package.duplicate(true)
	unsupported.schema = 99
	_write(future_export, Atomic.stringify(unsupported))
	_expect(Package.write_file(future_export, package).code == "ship_exchange.protected_destination" and FileAccess.get_file_as_string(future_export) == Atomic.stringify(unsupported), "Unknown portable destination is preserved")
	var failed_dir: String = "user://exchange_write_fail"
	DirAccess.make_dir_recursive_absolute(failed_dir)
	var blocked: String = Exchange.destination_for(package, failed_dir)
	DirAccess.make_dir_recursive_absolute(blocked + ".tmp")
	var failed: Dictionary = Exchange.import_package(package, failed_dir)
	_expect(not failed.ok and failed.code == "ship_exchange.write_failed" and not FileAccess.file_exists(blocked), "Real staging-open failure publishes no import/revision")
	DirAccess.remove_absolute(blocked + ".tmp")
	var retry: Dictionary = Exchange.import_package(package, failed_dir)
	_expect(retry.ok and retry.blueprint.revision == package.revision and Exchange.import_package(package, failed_dir).code == "already_present", "Retry after a failed write stores exactly one unchanged revision")
	DirAccess.make_dir_recursive_absolute("user://export_write_fail.json.tmp")
	_expect(Package.write_file("user://export_write_fail.json", package).code == "ship_exchange.write_failed", "Real export staging-write failure is reported")
	var rename_failure: String = "user://rename_failure.json"
	DirAccess.make_dir_recursive_absolute(rename_failure)
	_write(rename_failure.path_join("original.txt"), "preserve")
	_expect(Package.write_file(rename_failure, package).code == "ship_exchange.write_failed" and FileAccess.get_file_as_string(rename_failure.path_join("original.txt")) == "preserve", "Actual final rename failure keeps an existing destination intact")
	var too_large: String = "user://too_large_ship.json"
	_write(too_large, " ".repeat(Package.MAX_BYTES + 1))
	_expect(Package.read_file(too_large).code == "ship_exchange.package_too_large", "File size checked before reading content")
	var crowded: String = "user://crowded_exchange"
	DirAccess.make_dir_recursive_absolute(crowded)
	for i in range(Exchange.MAX_FILES): _write(crowded.path_join("filler_%d.txt" % i), "x")
	_expect(Exchange.import_package(package, crowded).code == "ship_exchange.library_limit", "Directory scan/write has a fixed file-count budget")
	_expect(FileAccess.get_file_as_string(renamed) == bytes, "All error probes retain the successful original")
	_expect(Atomic.stringify(root.get_node("GameState").export_state()) == state_before, "Successful/failed native writes never add fleet instances, cargo or crew")
	var path_identity: Dictionary = package.duplicate(true)
	path_identity.design_id = "../../outside/ship"
	path_identity.blueprint.design_id = path_identity.design_id
	var path_probe: Dictionary = Exchange.import_package(path_identity, "user://hash_only_exchange")
	_expect(path_probe.ok and path_probe.path.get_base_dir() == "user://hash_only_exchange" and not path_probe.path.get_file().contains("outside"), "Downloaded identities never become filesystem paths")


func _process_checks() -> void:
	var shared: String = ProjectSettings.globalize_path("user://ship_exchange_transfer")
	DirAccess.make_dir_recursive_absolute(shared)
	var variables: Array[String] = ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"]
	var previous: Dictionary = {}
	for key: String in variables: previous[key] = OS.get_environment(key) if OS.has_environment(key) else null
	for stage: String in ["source", "receiver", "restart"]:
		var user_root: String = shared.path_join("author" if stage == "source" else "recipient")
		for key: String in variables:
			var location: String = user_root.path_join(key.to_lower())
			DirAccess.make_dir_recursive_absolute(location)
			OS.set_environment(key, location)
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/ship_design_exchange_test.gd", "--", "--ship-exchange-stage", stage, shared], output, true)
		var log: String = "\n".join(output)
		_expect(code == 0 and not log.contains("SCRIPT ERROR") and not log.contains("ERROR:") and log.contains('"passed":true'), "Separate user-directory stage succeeds: " + stage)
		print(log)
	for key: String in variables:
		if previous[key] == null: OS.unset_environment(key)
		else: OS.set_environment(key, previous[key])


func _stage(stage: String, shared: String) -> void:
	var state_before: String = Atomic.stringify(root.get_node("GameState").export_state())
	if stage == "source":
		var expectations: Dictionary = {"source_user_dir": OS.get_user_data_dir(), "designs": {}}
		for role: String in ["expedition", "lander"]:
			var design: Dictionary = _design(role)
			var saved: Dictionary = Ship.save_design(design)
			_expect(saved.ok, "Sender saves through the original Ship command")
			var exported: Dictionary = Exchange.export_file(saved.path, shared.path_join(role + ".ship.json"), {"author": "Lars", "description": "Portable offline design"})
			_expect(exported.ok, "Sender exports from the real saved native file")
			expectations.designs[role] = {"path": ProjectSettings.globalize_path(saved.path), "bytes": FileAccess.get_file_as_string(saved.path),
				"identity": {"design_id": design.design_id, "revision": design.revision}, "metrics": _metrics(design)}
		var host: Dictionary = Ship.load_design(expectations.designs.expedition.path).blueprint
		var guest: Dictionary = Ship.load_design(expectations.designs.lander.path).blueprint
		expectations.hangar = _fit_metrics(host, guest)
		_expect(Atomic.write(shared.path_join("expected.json"), expectations, false) == OK, "Cross-process expectations saved")
	else:
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(shared.path_join("expected.json")))
		_expect(OS.get_user_data_dir() != expected.source_user_dir, "Receiver uses a genuinely different user data directory")
		var loaded_designs: Dictionary = {}
		for role: String in ["expedition", "lander"]:
			var portable: String = shared.path_join(role + ".ship.json")
			var path: String = Exchange.destination_for(expected.designs[role].identity)
			if stage == "receiver":
				_expect(not FileAccess.file_exists(path), "Recipient has no native original before import")
				var imported: Dictionary = Exchange.import_file(portable)
				_expect(imported.ok and imported.ready, "Receive valid ready design offline")
				_expect(Exchange.import_file(portable).code == "already_present", "Duplicate file import has no second design")
			var loaded: Dictionary = Ship.load_design(path)
			_expect(loaded.ok and _metrics(loaded.blueprint) == expected.designs[role].metrics, "Fresh native load retains colors/transforms/IDs/revision/capabilities: " + role)
			loaded_designs[role] = loaded.blueprint
			var bytes: String = FileAccess.get_file_as_string(path)
			if stage == "receiver":
				_expect(Exchange.export_file(path, shared.path_join(role + ".returned.json")).ok, "Recipient can re-export the installed native design")
				_expect(Package.same_content(Package.read_file(portable).package, Package.read_file(shared.path_join(role + ".returned.json")).package), "Round trip preserves the immutable envelope and provenance")
				DirAccess.remove_absolute(portable) # Restart no longer depends on download.
			else:
				_expect(not FileAccess.file_exists(portable) and not bytes.is_empty(), "Installed design survives offline restart after deleting the transfer")
			_expect(FileAccess.get_file_as_string(expected.designs[role].path) == expected.designs[role].bytes, "Sender native original remains byte-identical")
		_expect(_fit_metrics(loaded_designs.expedition, loaded_designs.lander) == expected.hangar, "All yaw/offset hangar decisions and clearances survive the round trip")
	_expect(Atomic.stringify(root.get_node("GameState").export_state()) == state_before, "No cross-process stage creates/modifies campaign fleet, cargo or crew")


func _fit_metrics(host: Dictionary, guest: Dictionary) -> Array:
	var result: Array = []
	for yaw in [0, 90, 180, 270]:
		for offset: Vector3 in [Vector3.ZERO, Vector3(2, 1, 0), Vector3(20, 0, 0)]:
			var fit: Dictionary = Ship.hangar_fit(host, guest, "", yaw, offset)
			result.append({"ok": fit.ok, "code": fit.code, "bay_id": fit.get("bay_id", ""),
				"clearance": Ship.array(fit.get("clearance", Vector3.ZERO))})
	return result


func _metrics(data: Dictionary) -> Dictionary:
	var inspected: Dictionary = Ship.evaluate(data)
	var mesh: ArrayMesh = MeshBuilder.build_mesh(data, Ship.Catalog.all())
	var arrays: Array = mesh.surface_get_arrays(0)
	var wire: Dictionary = Package.export_blueprint(data).package.blueprint
	var bays: Dictionary = {}
	for key: String in inspected.bays:
		bays[key] = {"size": Ship.array(inspected.bays[key].size), "position": Ship.array(inspected.bays[key].position), "yaw": inspected.bays[key].yaw}
	return Atomic.parse_dictionary(Atomic.stringify({"wire": wire, "stats": inspected.stats,
		"bounds": {"position": Ship.array(inspected.bounds.position), "size": Ship.array(inspected.bounds.size)},
		"bays": bays, "vertices_sha256": var_to_bytes(arrays[Mesh.ARRAY_VERTEX]).hex_encode().sha256_text(),
		"colors_sha256": var_to_bytes(arrays[Mesh.ARRAY_COLOR]).hex_encode().sha256_text()}))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Fixture file can be opened")
	if file != null:
		file.store_string(text)
		file.close()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
