extends RefCounted
## BP-COMMUNITY.1: file transport and pure preparation for the existing editor.
## Only trusted local callers supply the receiving phase and unlocked parts.
const Schema = preload("res://assembly/exchange/creature_package_schema.gd")
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const ORIGIN_KEY: String = "org.voxelverse.community_blueprint"


static func export_blueprint(blueprint: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	var metadata_rule: Dictionary = {"title?": ["text", 120], "description?": ["text", 2000],
		"author?": ["text", 120], "tags?": ["list", ["text", 40], 12]}
	if not Schema.problem(metadata, metadata_rule).is_empty(): return _fail("invalid_metadata")
	var serialized: Dictionary = Creature.serialize_snapshot(blueprint)
	if serialized.is_empty(): return _fail("unsupported_blueprint")
	var origin: Variant = serialized.get("extensions", {}).get(ORIGIN_KEY, {})
	var origin_rule: Dictionary = {"schema": ["int", 1, 1], "sources": ["list", Schema.ORIGIN, 8]}
	if not origin is Dictionary or (not origin.is_empty() and not Schema.problem(origin, origin_rule).is_empty()):
		return _fail("invalid_provenance")
	# Missing part fallbacks cannot be represented as the original design.
	for section in [serialized, serialized.body, serialized.paint] + serialized.parts:
		if not str(section.get("missing_part_id", "")).is_empty(): return _fail("missing_part")
		for revision_field in ["catalog_revision", "part_revision"]:
			if int(section.get(revision_field, 1)) != 1: return _fail("unsupported_catalog")
	if not Schema.problem(serialized.appearance, Schema.APPEARANCE).is_empty(): return _fail("unsupported_appearance")
	var attachment_problem: String = Schema.problem(serialized.assembly.body_attachments, Schema.ATTACHMENTS)
	if not attachment_problem.is_empty(): return _fail("unsupported_attachments", attachment_problem)
	var package: Dictionary = {
		"schema": 1, "kind": "creature", "catalog_revision": 1,
		"design_id": serialized.design_id, "revision": Creature.get_revision(blueprint),
		"title": metadata.get("title", serialized.name), "description": metadata.get("description", ""),
		"author": metadata.get("author", ""), "tags": metadata.get("tags", []).duplicate(true),
		"provenance": origin.get("sources", []).duplicate(true),
		"blueprint": Schema.project(serialized, Schema.BLUEPRINT),
	}
	package["required_parts"] = _requirements(package.blueprint)
	var checked: Dictionary = inspect(package)
	if not checked.ok: return checked
	return {"ok": true, "code": "", "package": package}


## Strict validation precedes V7 migration; downloaded stats are never read.
static func inspect(package: Variant) -> Dictionary:
	var problem: String = Schema.problem(package)
	if not problem.is_empty(): return {"ok": false, "code": "invalid_package", "field": problem}
	if JSON.stringify(package).to_utf8_buffer().size() > Schema.MAX_BYTES: return _fail("package_too_large")
	if package.title.strip_edges().is_empty(): return _fail("missing_title")
	var data: Dictionary = package.blueprint
	if package.required_parts != _requirements(data): return _fail("requirements_mismatch")
	for id: String in package.required_parts:
		if Parts.get_part(id).is_empty(): return _fail("unknown_part", id)
	if not data.body.part_id in _category_ids("body") or not data.paint.part_id in _category_ids("paint"):
		return _fail("invalid_body_or_paint")
	var spine: Array = data.body.spine
	if spine.size() != 7 or float(spine[0].t) != 0 or float(spine[6].t) != 1: return _fail("invalid_spine")
	for index in range(1, 7):
		if float(spine[index].t) - float(spine[index - 1].t) < Creature.SpineProfile.MIN_KNOT_GAP - 0.000001:
			return _fail("invalid_spine")
	var epsilon: float = Schema.VECTOR_EPSILON
	if data.body.shape[0] < 0.55 - epsilon or data.body.shape[0] > 3 + epsilon or data.body.shape[1] > 2.4 + epsilon or data.body.shape[2] < 0.85 - epsilon:
		return _fail("invalid_body_shape")
	var identities: Dictionary = {}
	for part: Dictionary in data.parts:
		if identities.has(part.uid): return _fail("duplicate_part_uid", part.uid)
		identities[part.uid] = part
		if Parts.get_part(part.part_id).get("category", "") != part.category: return _fail("invalid_category", part.uid)
		var end_category: String = "feet" if part.category == "legs" else ("hands" if part.category == "arms" else "")
		if not part.end_part_id.is_empty() and (end_category.is_empty() or Parts.get_part(part.end_part_id).get("category", "") != end_category):
			return _fail("invalid_terminal", part.uid)
		if absf(float(part.joint.offset[1])) > 0.3 + epsilon or (part.center_locked and part.mirrored): return _fail("invalid_attachment", part.uid)
	for part: Dictionary in data.parts:
		if not part.paired_uid.is_empty():
			if part.paired_uid == part.uid or not identities.has(part.paired_uid): return _fail("invalid_pair", part.uid)
			var other: Dictionary = identities[part.paired_uid]
			if other.paired_uid != part.uid or other.category != part.category: return _fail("invalid_pair", part.uid)
	var preview: Dictionary = Creature.migrate_snapshot(data, package.design_id)
	if preview.is_empty(): return _fail("invalid_blueprint")
	return {"ok": true, "code": "", "preview": preview,
		"stats": Creature.BaseBlueprint.calculate_stats(preview), "required_parts": package.required_parts.duplicate()}


## No live state or file mutation. Caller previews this copy, then uses the
## editor's normal history/save command after explicit user adoption.
static func prepare_import(package: Variant, current: Dictionary, phase: int, unlocked_parts: Array) -> Dictionary:
	var checked: Dictionary = inspect(package)
	if not checked.ok: return checked
	if phase != 0: return _fail("phase_not_editable")
	if current.has("_protected_design_source") or not Creature.Contract.inspect(current, "creature").ok or str(current.get("design_id", "")).is_empty():
		return _fail("protected_target")
	if Creature.get_revision(current) >= 9007199254740990: return _fail("revision_exhausted")
	var missing: Array = []
	for id: String in checked.required_parts:
		if not id in unlocked_parts: missing.append(id)
	if not missing.is_empty(): return {"ok": false, "code": "locked_parts", "missing_parts": missing}
	if checked.stats.complexity > Creature.BaseBlueprint.COMPLEXITY_LIMIT: return _fail("complexity_exceeded")
	var candidate: Dictionary = current.duplicate(true)
	candidate["assembly"] = current.get("assembly", {"schema": 7, "revision": 0}).duplicate(true)
	for field in ["body", "paint", "parts", "appearance"]:
		candidate[field] = checked.preview[field].duplicate(true)
	candidate["assembly"]["body_attachments"] = checked.preview.assembly.body_attachments.duplicate(true)
	# Revision publication remains the existing editor save command's job.
	candidate["assembly"]["revision"] = Creature.get_revision(current)
	# Part IDs are local to the design. Allocate future editor IDs above all
	# transferred part_N identifiers, independent of the author's counter.
	var next_uid: int = 1
	for part: Dictionary in candidate.parts:
		var suffix: String = part.uid.trim_prefix("part_")
		if part.uid.begins_with("part_") and suffix.is_valid_int():
			if suffix.length() > 9: return _fail("invalid_part_counter")
			next_uid = maxi(next_uid, suffix.to_int() + 1)
	candidate["next_part_uid"] = next_uid
	var sources: Array = package.provenance.duplicate(true)
	var origin: Dictionary = {"design_id": package.design_id, "revision": package.revision, "author": package.author}
	if not origin in sources: sources.append(origin)
	if sources.size() > 8: return _fail("provenance_limit")
	var extensions: Dictionary = candidate.get("extensions", {}).duplicate(true)
	extensions[ORIGIN_KEY] = {"schema": 1, "sources": sources}
	candidate["extensions"] = extensions
	return {"ok": true, "code": "", "blueprint": candidate, "stats": checked.stats.duplicate(true)}


static func prepare_for_active_editor(package: Variant, current: Dictionary) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return _fail("no_campaign")
	var state := tree.root.get_node_or_null("GameState")
	var progression := tree.root.get_node_or_null("ProgressionService")
	var saves := tree.root.get_node_or_null("SaveGameService")
	if state == null or progression == null or saves == null or not saves.session_active: return _fail("no_campaign")
	if saves.is_phase_transition_active(): return _fail("transition_active")
	return prepare_import(package, current, int(state.current_phase), progression.get_unlocked_part_ids())


static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > Schema.MAX_BYTES: return _fail("package_too_large")
	var parser := JSON.new()
	if parser.parse(text) != OK: return _fail("invalid_json")
	var checked: Dictionary = inspect(parser.data)
	if not checked.ok: return checked
	return {"ok": true, "code": "", "package": parser.data}


static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail("read_failed")
	if file.get_length() > Schema.MAX_BYTES: return _fail("package_too_large")
	return decode(file.get_as_text())


## A portable revision is immutable at its chosen destination. A different
## revision needs a new filename; corrupted/future files also remain intact.
static func write_file(path: String, package: Variant) -> Dictionary:
	var checked: Dictionary = inspect(package)
	if not checked.ok: return checked
	if FileAccess.file_exists(path):
		var old: Dictionary = read_file(path)
		if not old.ok: return _fail("protected_destination")
		# Existing immutable exports may use either released number encoding.
		var precise: Dictionary = Atomic.parse_dictionary(Atomic.stringify(package))
		var legacy: Dictionary = JSON.parse_string(JSON.stringify(package))
		if old.package != precise and old.package != legacy: return _fail("destination_conflict")
		return {"ok": true, "code": ""}
	var error: Error = Atomic.write(path, package, false)
	return {"ok": error == OK, "code": "" if error == OK else "write_failed", "error": error}


static func _requirements(data: Dictionary) -> Array:
	var ids: Array = [data.body.part_id, data.paint.part_id]
	for part: Dictionary in data.parts:
		for id: String in [part.part_id, part.end_part_id]:
			if not id.is_empty() and not id in ids: ids.append(id)
	ids.sort()
	return ids


static func _category_ids(category: String) -> Array:
	var result: Array = []
	var definitions: Array = Parts.get_body_parts() if category == "body" else Parts.get_paint_parts()
	for definition: Dictionary in definitions: result.append(definition.id)
	return result


static func _fail(code: String, item: String = "") -> Dictionary:
	return {"ok": false, "code": code, "item": item}
