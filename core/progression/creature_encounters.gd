extends RefCounted
class_name CreatureEncounters

const Rules = preload("res://core/progression/behavior_catalog.gd")
const SCHEMA: int = 1
const PAGED_SCHEMA: int = 2
const Store = preload("res://core/persistence/region_store.gd")
# Legacy planar saves retain their inline format. The spherical campaign pages
# touched individuals; cache eviction never deletes an encounter or paid identity.
const MAX_ENTRIES: int = 32768
var entries: Dictionary = {}
var store = null
var last_error: String = ""


func reset() -> void:
	entries.clear()
	store = null
	last_error = ""


func enable_paging() -> bool:
	if store != null:
		last_error = store.last_error
		return last_error.is_empty()
	# Write the complete old ledger before relinquishing it. The last on-disk
	# campaign still owns its inline copy until the shared save commits.
	var candidate := Store.new()
	candidate.validate_value = payload_problem
	for key: String in entries:
		if not candidate.put(key, {"schema": 1, "entry": entries[key].duplicate(true)}):
			last_error = candidate.last_error
			return false
	if candidate.checkpoint().is_empty():
		last_error = candidate.last_error
		return false
	store = candidate
	entries.clear()
	last_error = ""
	return true


func export_state() -> Dictionary:
	if store == null: return {"schema": SCHEMA, "entries": entries.duplicate(true)}
	var manifest: Dictionary = store.checkpoint()
	last_error = store.last_error
	if manifest.is_empty(): return {}
	return {"schema": PAGED_SCHEMA, "storage": manifest}


func import_state(value: Dictionary) -> bool:
	if not validate_state(value).is_empty(): return false
	if value.schema == PAGED_SCHEMA:
		var candidate := Store.new()
		candidate.validate_value = payload_problem
		if not candidate.open(value.storage):
			last_error = candidate.last_error
			return false
		reset()
		store = candidate
		return true
	reset()
	entries = value["entries"].duplicate(true)
	for entry in entries.values(): _normalize(entry)
	return true


func saved(key: String) -> Dictionary:
	if store == null: return entries.get(key, {}).duplicate(true)
	var payload: Dictionary = store.get_value(key)
	if not payload.is_empty():
		var problem: String = payload_problem(key, payload)
		if not problem.is_empty(): store._fail(problem)
	last_error = store.last_error
	if payload.is_empty() or not last_error.is_empty(): return {}
	var result: Dictionary = payload.entry.duplicate(true)
	_normalize(result)
	return result


func erase(key: String) -> bool:
	if store == null:
		entries.erase(key)
		return true
	# Tombstones preserve immutable historical roots; no archive file is deleted.
	var ok: bool = store.put(key, {"schema": 1, "entry": {}})
	last_error = store.last_error
	return ok


func restore(key: String, before: Dictionary) -> void:
	if store == null:
		if before.is_empty(): entries.erase(key)
		else: entries[key] = before.duplicate(true)
		return
	# The transaction pins its key. Undo must restore RAM even after a failed
	# blob write; the storage error continues to block publication.
	store.cache[key] = {"schema": 1, "entry": before.duplicate(true)}
	store.dirty[key] = true


static func _normalize(entry: Dictionary) -> void:
	if entry.has("habitat"):
		entry.habitat.species_seed = int(entry.habitat.species_seed)
		entry.habitat.individual_seed = int(entry.habitat.individual_seed)


static func payload_problem(key: String, value: Dictionary) -> String:
	if value.get("schema") != 1 or not value.get("entry") is Dictionary or value.size() != 2:
		return "Unsupported encounter archive payload."
	if value.entry.is_empty(): return "" # Explicit removal, never an absent/corrupt blob.
	if value.entry.get("object_id") != key: return "Encounter archive identity mismatch."
	return validate_entry(value.entry)


func get_entry(identity: Dictionary, role: String, individual_seed: int) -> Dictionary:
	var key: String = str(identity.get("object_id", ""))
	var stored: Dictionary = saved(key)
	if not stored.is_empty(): return stored
	if not last_error.is_empty(): return {}
	# A deterministic environmental injury gives helping a genuine, finite need.
	# Merely spawning an animal does not grow the persistent encounter ledger.
	var injured: bool = role != "predator" and posmod(individual_seed, 5) == 0
	var result := {"object_id": key, "species_id": str(identity.get("species_id", "")),
		"body_id": str(identity.get("body_id", "")), "region_id": str(identity.get("region_id", "")),
		"relation": "hostile" if role == "predator" else "wild", "trust": 0.0,
		"health_ratio": 0.55 if injured else 1.0, "need_origin": "environment" if injured else "none",
		"player_harmed": false, "conflict_relation": "", "conflict_reason": "",
		"dead": false, "carcass_food": 0.0}
	if identity.has("habitat_cell") and not str(identity["habitat_cell"]).is_empty():
		result["habitat"] = {"cell": identity["habitat_cell"], "role": role,
			"species_seed": identity["species_seed"], "individual_seed": individual_seed}
	return result


func put(entry: Dictionary) -> bool:
	if not validate_entry(entry).is_empty():
		return false
	var key: String = entry["object_id"]
	if store != null:
		var ok: bool = store.put(key, {"schema": 1, "entry": entry.duplicate(true)})
		last_error = store.last_error
		return ok
	if not entries.has(key) and entries.size() >= MAX_ENTRIES:
		return false
	entries[key] = entry.duplicate(true)
	return true


static func has_unsupported_contract(value: Variant) -> bool:
	if not value is Dictionary: return false
	if Rules.is_newer_version(value.get("schema"), PAGED_SCHEMA): return true
	var fields: Array = ["schema", "storage"] if value.get("schema") == PAGED_SCHEMA else ["schema", "entries"]
	for key in value:
		if key not in fields: return true
	if value.get("schema") == PAGED_SCHEMA and value.get("storage") is Dictionary:
		for key in value.storage:
			if key not in ["schema", "format", "root"]: return true
		var reader := Store.new()
		reader.open(value.storage)
		return reader.unsupported
	return false


static func validate_state(value: Variant) -> String:
	if value is Dictionary and Rules.is_integer(value.get("schema"), PAGED_SCHEMA, PAGED_SCHEMA):
		if value.size() != 2 or not value.has("storage"): return "Invalid encounter archive envelope."
		return Store.manifest_problem(value.storage)
	if not value is Dictionary or not Rules.is_integer(value.get("schema"), SCHEMA, SCHEMA):
		return "Unsupported creature encounter schema."
	if value.size() != 2 or not value.get("entries") is Dictionary or value["entries"].size() > MAX_ENTRIES:
		return "Invalid creature encounter ledger."
	for key in value["entries"]:
		var entry: Variant = value["entries"][key]
		var problem: String = validate_entry(entry)
		if not problem.is_empty() or key != entry["object_id"]:
			return "Invalid creature encounter entry: " + problem
	return ""


static func validate_entry(entry: Variant) -> String:
	if not entry is Dictionary:
		return "Missing encounter data."
	for field in ["object_id", "species_id", "body_id", "region_id"]:
		var value: Variant = entry.get(field)
		if not value is String or value.is_empty() or value.length() > 256:
			return "Invalid encounter identity."
	for field in ["trust", "health_ratio", "carcass_food"]:
		var value: Variant = entry.get(field)
		var limit: float = 1.0 if field == "health_ratio" else 100.0
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > limit:
			return "Invalid encounter value."
	if entry.get("relation") not in ["wild", "ally", "hostile"] or entry.get("need_origin") not in ["none", "environment", "third_party", "player"]:
		return "Invalid encounter relationship or need."
	if entry.get("conflict_relation") not in ["", "prey", "hostile", "ally", "wild"] or entry.get("conflict_reason") not in ["", "hunt", "self_defense", "unprovoked"]:
		return "Invalid conflict evidence."
	if not entry.get("dead") is bool or not entry.get("player_harmed") is bool:
		return "Invalid encounter flags."
	if entry["dead"] != (float(entry["health_ratio"]) == 0.0):
		return "Inconsistent creature death."
	if entry["relation"] == "ally" and float(entry["trust"]) < 100.0:
		return "Incomplete ally relationship."
	if entry.has("habitat"):
		var habitat: Variant = entry["habitat"]
		if not habitat is Dictionary or not habitat.get("cell") is String or habitat["cell"].is_empty() or habitat["cell"].length() > 64 or habitat.get("role") not in ["forager", "grazer", "scavenger", "predator", "climber", "swimmer"]:
			return "Invalid persistent habitat."
		if not Rules.is_integer(habitat.get("species_seed"), 0, 9007199254740991) or not Rules.is_integer(habitat.get("individual_seed"), 0, 2147483647):
			return "Invalid persistent habitat seed."
	return ""
