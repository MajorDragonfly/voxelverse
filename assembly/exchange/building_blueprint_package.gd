extends RefCounted
## Closed, portable building design v1. No scene paths, stats or campaign state.
## Reuses the released schema walker and BuildingBlueprint/Assembly validation.
const Schema = preload("res://assembly/exchange/creature_package_schema.gd")
const Building = preload("res://civilization/buildings/building_blueprint.gd")
const Assembly = Building.Assembly
const Contract = Building.Contract
const Atomic = preload("res://core/persistence/atomic_json.gd")
const ORIGIN_KEY: String = "org.voxelverse.community_blueprint"
const MAX_BYTES: int = Contract.MAX_BYTES
const MAX_PARTS: int = Contract.MAX_PARTS
const MAX_OFFSET: float = 4096.0
const PART: Dictionary = {
	"uid": "id", "part_id": "id", "position": ["vec", -MAX_OFFSET, MAX_OFFSET],
	"rotation": ["vec", -36000, 36000], "scale": ["vec", 0.05, 20],
	"mirror_group": "optional_id", "socket_id": "optional_id",
	"tags": ["list", ["text", 40], 12],
	"part_revision?": Schema.REVISION, "catalog_revision?": Schema.REVISION,
}
const BLUEPRINT: Dictionary = {
	"schema": ["int", 1, 1], "assembly_type": ["enum", "building"],
	"name": ["text", 120], "grid_snap": "bool", "grid_size": ["num", 0.03125, 4],
	"parts": ["list", PART, MAX_PARTS],
	"building": {"schema": ["int", 1, 1], "type": ["enum", "residential", "commercial",
		"industrial", "civic", "military", "harbor"], "style_name": ["text", 120]},
}
const PACKAGE: Dictionary = {
	"schema": ["int", 1, 1], "kind": ["enum", "building"], "catalog_revision": ["int", 1, 1],
	"design_id": "id", "revision": Schema.REVISION,
	"title": ["text", 120], "description": ["text", 2000], "author": ["text", 120],
	"tags": ["list", ["text", 40], 12], "provenance": ["list", Schema.ORIGIN, 8],
	"required_parts": ["list", "id", MAX_PARTS], "blueprint": BLUEPRINT,
}


static func export_blueprint(blueprint: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	if blueprint.has("_protected_design_source"): return _fail("protected_source")
	var checked: Dictionary = Contract.inspect(blueprint, "building")
	if not checked.ok: return checked
	if Contract.kind_of(blueprint) != "building": return _fail("invalid_building")
	var metadata_rule: Dictionary = {"title?": ["text", 120], "description?": ["text", 2000],
		"author?": ["text", 120], "tags?": ["list", ["text", 40], 12]}
	if not Schema.problem(metadata, metadata_rule).is_empty(): return _fail("invalid_metadata")
	var origin: Variant = blueprint.get("extensions", {}).get(ORIGIN_KEY, {})
	var origin_rule: Dictionary = {"schema": ["int", 1, 1], "sources": ["list", Schema.ORIGIN, 8]}
	if not origin is Dictionary or (not origin.is_empty() and not Schema.problem(origin, origin_rule).is_empty()):
		return _fail("invalid_provenance")
	for part: Dictionary in blueprint.get("parts", []):
		if not str(part.get("missing_part_id", "")).is_empty(): return _fail("missing_part")
		# Validate authored geometry before the local normalizer's clamping.
		for field: String in ["position", "rotation", "scale"]:
			if part.has(field):
				var vector: Array = Assembly._serialize_vector3(Assembly._as_vector3(part[field]))
				if not Schema.problem(vector, PART[field]).is_empty(): return _fail("unsupported_geometry", field)
	if blueprint.has("grid_size") and not Schema.problem(blueprint.grid_size, BLUEPRINT.grid_size).is_empty():
		return _fail("unsupported_geometry", "grid_size")
	if blueprint.get("building", {}).has("type") and not blueprint.building.type in Building.BUILDING_TYPES:
		return _fail("invalid_building")
	# Unversioned local BuildingBlueprints are explicitly supported by Contract.
	# Bind missing legacy identities to the content, never the receiving pathname.
	var candidate: Dictionary = blueprint.duplicate(true)
	if str(candidate.get("design_id", "")).is_empty():
		candidate["design_id"] = Building.Ids.scoped("design", "building-exchange-legacy-v1", Atomic.stringify(candidate, ""))
	candidate = Contract.migrate_part_ids(candidate)
	# Reject unavailable parts before Building.normalize can install a fallback.
	for part: Dictionary in candidate.get("parts", []):
		if Building.Parts.get_part(str(part.get("part_id", ""))).is_empty(): return _fail("missing_part")
	Building.normalize(candidate)
	var serialized: Dictionary = Assembly.serialize(candidate)
	if serialized.is_empty(): return _fail("unsupported_blueprint")
	var package: Dictionary = {
		"schema": 1, "kind": "building", "catalog_revision": 1,
		"design_id": candidate.design_id, "revision": candidate.revision,
		"title": metadata.get("title", candidate.name), "description": metadata.get("description", ""),
		"author": metadata.get("author", ""), "tags": metadata.get("tags", []).duplicate(true),
		"provenance": origin.get("sources", []).duplicate(true),
		"blueprint": Schema.project(serialized, BLUEPRINT),
	}
	package["required_parts"] = _requirements(package.blueprint)
	checked = inspect(package)
	return {"ok": true, "code": "", "package": package} if checked.ok else checked


static func inspect(package: Variant) -> Dictionary:
	if package is Dictionary:
		if package.has("schema") and package.schema != 1: return _fail("unsupported_package_version")
		if package.has("catalog_revision") and package.catalog_revision != 1: return _fail("unsupported_catalog")
	var problem: String = Schema.problem(package, PACKAGE)
	if not problem.is_empty(): return _fail("invalid_package", problem)
	if Atomic.stringify(package).to_utf8_buffer().size() > MAX_BYTES: return _fail("package_too_large")
	if package.title.strip_edges().is_empty() or package.blueprint.name.strip_edges().is_empty(): return _fail("missing_title")
	var data: Dictionary = package.blueprint.duplicate(true)
	data["design_id"] = package.design_id
	data["revision"] = int(package.revision)
	var checked: Dictionary = Contract.inspect(data, "building")
	if not checked.ok: return checked
	if package.required_parts != _requirements(data): return _fail("requirements_mismatch")
	var missing: Array = []
	for id: String in package.required_parts:
		if Building.Parts.get_part(id).is_empty(): missing.append(id)
	if not missing.is_empty(): return {"ok": false, "code": "missing_parts", "missing_parts": missing}
	var errors: Array[String] = Building.validate(data)
	if not errors.is_empty(): return {"ok": false, "code": "invalid_building", "errors": errors}
	var preview: Dictionary = Assembly.deserialize(data)
	Building.normalize(preview)
	if not package.provenance.is_empty():
		preview["extensions"] = {ORIGIN_KEY: {"schema": 1, "sources": package.provenance.duplicate(true)}}
	return {"ok": true, "code": "", "preview": preview,
		"stats": Building.calculate_stats(preview), "required_parts": package.required_parts.duplicate()}


## Editing a received revision starts a distinct design. Never save over its
## author, and never copy downloaded production/cost/inventory/unlock values.
## Pure preparation only; UI phase checks and normal save remain caller-owned.
static func prepare_working_copy(package: Variant) -> Dictionary:
	var checked: Dictionary = inspect(package)
	if not checked.ok: return checked
	var sources: Array = package.provenance.duplicate(true)
	var origin: Dictionary = {"design_id": package.design_id, "revision": int(package.revision), "author": package.author}
	if not origin in sources: sources.append(origin)
	if sources.size() > 8: return _fail("provenance_limit")
	var candidate: Dictionary = checked.preview.duplicate(true)
	candidate["design_id"] = Building.Ids.create("design")
	candidate["revision"] = 0
	candidate["extensions"] = {ORIGIN_KEY: {"schema": 1, "sources": sources}}
	return {"ok": true, "code": "", "blueprint": candidate, "stats": checked.stats.duplicate(true)}


static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return _fail("package_too_large")
	var parser := JSON.new()
	if parser.parse(text) != OK: return _fail("invalid_json")
	var checked: Dictionary = inspect(parser.data)
	return {"ok": true, "code": "", "package": parser.data} if checked.ok else checked


static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail("read_failed")
	if file.get_length() > MAX_BYTES: return _fail("package_too_large")
	return decode(file.get_as_text())


## Immutable destination, including corrupt and future originals. Keep the
## existing Atomic transport's precision and userdata lease unchanged.
static func write_file(path: String, package: Variant) -> Dictionary:
	var checked: Dictionary = inspect(package)
	if not checked.ok: return checked
	# Atomic's userdata lease is shared by runtime owners. A destination-local
	# mkdir lease also serializes this adapter across processes and threads.
	var lock_path: String = path + ".exchange-lock"
	var error: Error = DirAccess.make_dir_absolute(lock_path)
	if error != OK:
		return _fail("writer_busy" if DirAccess.dir_exists_absolute(lock_path) else "write_failed")
	var result: Dictionary = _write_owned(path, package)
	DirAccess.remove_absolute(lock_path)
	return result


static func _write_owned(path: String, package: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path):
		var old: Dictionary = read_file(path)
		if not old.ok: return _fail("protected_destination")
		return {"ok": true, "code": "already_present"} if same_content(old.package, package) else _fail("revision_conflict")
	if DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path + ".tmp") or DirAccess.dir_exists_absolute(path + ".tmp"):
		return _fail("protected_destination")
	var error: Error = Atomic.write(path, package, false)
	return {"ok": error == OK, "code": "" if error == OK else "write_failed", "error": error}


static func same_content(first: Dictionary, second: Dictionary) -> bool:
	# Compare precise wire values, not native int versus JSON float variants.
	return Atomic.parse_dictionary(Atomic.stringify(first, "")) == Atomic.parse_dictionary(Atomic.stringify(second, ""))


static func _requirements(data: Dictionary) -> Array:
	var ids: Array = []
	for part: Dictionary in data.parts:
		if not part.part_id in ids: ids.append(part.part_id)
	ids.sort()
	return ids


static func _fail(code: String, field: String = "") -> Dictionary:
	return {"ok": false, "code": code, "field": field}
