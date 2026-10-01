extends RefCounted
## Portable authoring data only. Ship/Assembly remain the native validators/codecs.
const Ship = preload("res://space/ships/ship_blueprint.gd")
const Rules = preload("res://assembly/exchange/creature_package_schema.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const MAX_BYTES: int = Ship.Contract.MAX_BYTES
const ORIGIN_KEY: String = "org.voxelverse.ship_exchange"
const REVISION: Array = ["int", 1, 9007199254740990.0]
const SOURCE: Dictionary = {"design_id": ["text", 120], "revision": REVISION, "author": ["text", 120]}
const METADATA: Dictionary = {"title": ["text", 120], "description": ["text", 2000],
	"author": ["text", 120], "tags": ["list", ["text", 40], 12]}
const ORIGIN: Dictionary = {"schema": ["int", 1, 1], "source": SOURCE,
	"provenance": ["list", SOURCE, 8], "metadata": METADATA}
const PART: Dictionary = {"uid": ["text", 120], "part_id": "id", "part_revision": ["int", 1, 1],
	"position": ["vec", -200, 200], "rotation": ["vec", 0, 270], "scale": ["vec", 1, 1],
	"mirror_group": ["text", 120], "socket_id": ["text", 120], "tags": ["list", ["text", 40], 12]}
const BLUEPRINT: Dictionary = {"schema": ["int", 1, 1], "design_id": ["text", 120],
	"revision": REVISION, "assembly_type": ["enum", "ship"], "name": ["text", 120],
	"grid_snap": "bool", "grid_size": ["num", 0.03125, 4], "parts": ["list", PART, Ship.MAX_MODULES],
	"ship": {"schema": ["int", 1, 1], "role": ["enum", "expedition", "lander"],
		"catalog_revision": ["int", 1, 1]}}
const PACKAGE: Dictionary = {"schema": ["int", 1, 1], "kind": ["enum", "ship"],
	"payload_schema": ["int", 1, 1], "catalog_revision": ["int", 1, 1],
	"design_id": ["text", 120], "revision": REVISION, "title": ["text", 120],
	"description": ["text", 2000], "author": ["text", 120], "tags": ["list", ["text", 40], 12],
	"provenance": ["list", SOURCE, 8], "required_modules": ["list", "id", Ship.MAX_MODULES],
	"blueprint": BLUEPRINT}
static var _write_mutex := Mutex.new()


static func export_blueprint(blueprint: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	var checked: Dictionary = Ship.inspect(blueprint)
	if not checked.ok: return checked
	if int(blueprint.revision) < 1: return _fail("ship_exchange.unsaved_design")
	var metadata_rule: Dictionary = {}
	for key: String in METADATA: metadata_rule[key + "?"] = METADATA[key]
	if not Rules.problem(metadata, metadata_rule).is_empty(): return _fail("ship_exchange.invalid_metadata")
	var origin: Variant = blueprint.get("extensions", {}).get(ORIGIN_KEY, {})
	if not origin is Dictionary or (not origin.is_empty() and not Rules.problem(origin, ORIGIN).is_empty()):
		return _fail("ship_exchange.invalid_provenance")
	var public_metadata: Dictionary = {"title": blueprint.name, "description": "", "author": "", "tags": []}
	var provenance: Array = []
	if not origin.is_empty():
		provenance = origin.provenance.duplicate(true)
		if origin.source.design_id == blueprint.design_id and int(origin.source.revision) == int(blueprint.revision):
			public_metadata = origin.metadata.duplicate(true)
		elif not origin.source in provenance:
			provenance.append(origin.source.duplicate(true))
	public_metadata.merge(metadata, true)
	var serialized: Dictionary = Ship.Assembly.serialize(blueprint)
	# A fallback must never be published as the missing original module.
	for part: Dictionary in serialized.parts:
		if not str(part.get("missing_part_id", "")).is_empty(): return _fail("ship_exchange.missing_module")
	var package: Dictionary = {"schema": 1, "kind": "ship", "payload_schema": 1,
		"catalog_revision": Ship.Catalog.REVISION, "design_id": blueprint.design_id,
		"revision": blueprint.revision, "provenance": provenance,
		"blueprint": Rules.project(serialized, BLUEPRINT)}
	package.merge(public_metadata, true)
	package.required_modules = _requirements(package.blueprint)
	checked = inspect(package)
	return {"ok": true, "code": "", "package": package} if checked.ok else checked


static func inspect(package: Variant) -> Dictionary:
	# Closed rules reject unknown fields before any normalization/preview.
	if package is Dictionary:
		for key: String in ["schema", "payload_schema", "catalog_revision"]:
			if package.has(key) and Ship._integer(package[key]) and int(package[key]) != 1:
				return _fail("ship_exchange.unsupported_version", key)
	var problem: String = Rules.problem(package, PACKAGE)
	if not problem.is_empty(): return _fail("ship_exchange.invalid_package", problem)
	if Atomic.stringify(package).to_utf8_buffer().size() > MAX_BYTES: return _fail("ship_exchange.package_too_large")
	if package.title.strip_edges().is_empty() or package.design_id.strip_edges().is_empty():
		return _fail("ship_exchange.invalid_identity")
	if package.design_id != package.blueprint.design_id or int(package.revision) != int(package.blueprint.revision):
		return _fail("ship_exchange.identity_mismatch")
	if package.required_modules != _requirements(package.blueprint): return _fail("ship_exchange.requirements_mismatch")
	for source: Dictionary in package.provenance:
		if source.design_id.strip_edges().is_empty(): return _fail("ship_exchange.invalid_provenance")
	var checked: Dictionary = Ship.inspect(package.blueprint)
	if not checked.ok: return checked
	# Do not let approximate native checks silently clamp/round wire transforms.
	for part: Dictionary in package.blueprint.parts:
		for number in part.position:
			if not Ship._integer(number): return _fail("ship.transform")
		if part.rotation[0] != 0 or part.rotation[2] != 0 or float(part.rotation[1]) not in [0.0, 90.0, 180.0, 270.0]:
			return _fail("ship.rotation")
		for number in part.scale:
			if number != 1: return _fail("ship.scale")
	var preview: Dictionary = Ship.Assembly.deserialize(package.blueprint)
	var evaluation: Dictionary = Ship.evaluate(preview)
	for issue: Dictionary in evaluation.issues:
		if issue.code in ["ship.size_limit", "ship.module_role", "ship.overlap"]: return _fail(issue.code)
	# Unfinished safe drafts remain editable, but cannot become ready fleet pins.
	return {"ok": true, "code": "", "preview": preview, "ready": evaluation.ok,
		"evaluation": evaluation, "required_modules": package.required_modules.duplicate()}


## Native working copy with bounded provenance; no fleet/campaign mutation.
static func prepare_import(package: Variant) -> Dictionary:
	var checked: Dictionary = inspect(package)
	if not checked.ok: return checked
	var candidate: Dictionary = checked.preview.duplicate(true)
	candidate.extensions = {ORIGIN_KEY: {"schema": 1,
		"source": {"design_id": package.design_id, "revision": package.revision, "author": package.author},
		"provenance": package.provenance.duplicate(true), "metadata": Rules.project(package, METADATA)}}
	return {"ok": true, "code": "", "blueprint": candidate, "ready": checked.ready,
		"evaluation": checked.evaluation}


static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return _fail("ship_exchange.package_too_large")
	var parser := JSON.new()
	if parser.parse(text) != OK: return _fail("ship_exchange.invalid_json")
	var checked: Dictionary = inspect(parser.data)
	return {"ok": true, "code": "", "package": parser.data} if checked.ok else checked


static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail("ship_exchange.read_failed")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _fail("ship_exchange.package_too_large")
	var text: String = file.get_as_text()
	file.close()
	return decode(text)


## Immutable exports. Corrupt/future files never fall back or get overwritten.
static func write_file(path: String, package: Variant) -> Dictionary:
	var checked: Dictionary = inspect(package)
	if not checked.ok: return checked
	_write_mutex.lock()
	var result: Dictionary = _write_file_owned(path, package)
	_write_mutex.unlock()
	return result


static func _write_file_owned(path: String, package: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path):
		var old: Dictionary = read_file(path)
		if not old.ok: return _fail("ship_exchange.protected_destination")
		return {"ok": true, "code": "already_present", "path": path} if same_content(old.package, package) else _fail("ship_exchange.destination_conflict")
	var error: Error = Atomic.write(path, package, false)
	return {"ok": error == OK, "code": "" if error == OK else "ship_exchange.write_failed", "error": error, "path": path}


static func same_content(first: Dictionary, second: Dictionary) -> bool:
	# JSON's released reader uses floats for numeric scalars. Canonicalize both
	# operands through it, retaining all precise geometry and safe revisions.
	return Atomic.stringify(Atomic.parse_dictionary(Atomic.stringify(first)), "") == Atomic.stringify(Atomic.parse_dictionary(Atomic.stringify(second)), "")


static func _requirements(data: Dictionary) -> Array:
	var ids: Array = []
	for part: Dictionary in data.parts:
		if not part.part_id in ids: ids.append(part.part_id)
	ids.sort()
	return ids


static func _fail(code: String, field: String = "") -> Dictionary:
	return {"ok": false, "code": code, "field": field}
