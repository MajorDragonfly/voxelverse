extends RefCounted
class_name CreatureEncounters

const Rules = preload("res://core/progression/behavior_catalog.gd")
const SCHEMA: int = 1
# Only touched individuals are stored. Paid identities are never evicted.
const MAX_ENTRIES: int = 32768
var entries: Dictionary = {}


func export_state() -> Dictionary:
	return {"schema": SCHEMA, "entries": entries.duplicate(true)}


func import_state(value: Dictionary) -> bool:
	if not validate_state(value).is_empty():
		return false
	entries = value["entries"].duplicate(true)
	return true


func get_entry(identity: Dictionary, role: String, individual_seed: int) -> Dictionary:
	var key: String = str(identity.get("object_id", ""))
	if entries.has(key):
		return entries[key].duplicate(true)
	# A deterministic environmental injury gives helping a genuine, finite need.
	# Merely spawning an animal does not grow the persistent encounter ledger.
	var injured: bool = role != "predator" and posmod(individual_seed, 5) == 0
	return {"object_id": key, "species_id": str(identity.get("species_id", "")),
		"body_id": str(identity.get("body_id", "")), "region_id": str(identity.get("region_id", "")),
		"relation": "hostile" if role == "predator" else "wild", "trust": 0.0,
		"health_ratio": 0.55 if injured else 1.0, "need_origin": "environment" if injured else "none",
		"player_harmed": false, "conflict_relation": "", "conflict_reason": "",
		"dead": false, "carcass_food": 0.0}


func put(entry: Dictionary) -> bool:
	if not validate_entry(entry).is_empty():
		return false
	var key: String = entry["object_id"]
	if not entries.has(key) and entries.size() >= MAX_ENTRIES:
		return false
	entries[key] = entry.duplicate(true)
	return true


static func has_unsupported_contract(value: Variant) -> bool:
	return value is Dictionary and Rules.is_newer_version(value.get("schema"), SCHEMA)


static func validate_state(value: Variant) -> String:
	if not value is Dictionary or not Rules.is_integer(value.get("schema"), SCHEMA, SCHEMA):
		return "Unsupported creature encounter schema."
	if not value.get("entries") is Dictionary or value["entries"].size() > MAX_ENTRIES:
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
	return ""
