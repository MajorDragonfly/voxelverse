extends RefCounted
## Read-only, versioned planning data. No wallet, unlock, production or save API.
const Civilization = preload("res://core/progression/civilization_contract.gd")
const Resources = preload("res://world/tribe/resource_catalog.gd")
const Parts = preload("res://civilization/buildings/building_part_library.gd")
const Rules = preload("res://core/progression/behavior_catalog.gd")
const PATH := "res://civilization/technology/catalog.json"
const SCHEMA: int = 1
const MAX_NODES: int = 64

static func read_catalog() -> Dictionary:
	if not FileAccess.file_exists(PATH): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return value if value is Dictionary else {}

static func requirements() -> Dictionary:
	var result: Dictionary = {}
	for rule: Array in Civilization.PHASES[2]["requirements"]:
		result[rule[0]] = {"id": rule[0], "text": rule[1], "supported": rule[2]}
	return result

static func validate(value: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not value is Dictionary or not Rules.is_integer(value.get("schema"), SCHEMA, SCHEMA):
		return PackedStringArray(["unsupported_schema"])
	if not Rules.is_integer(value.get("revision"), 1, 1_000_000) or value.get("scope") != "preview_only" or not Rules.is_integer(value.get("phase"), 2, 2):
		return PackedStringArray(["invalid_header"])
	var nodes: Variant = value.get("nodes")
	if not nodes is Array or nodes.is_empty() or nodes.size() > MAX_NODES:
		return PackedStringArray(["invalid_nodes"])
	var ids: Dictionary = {}
	var expression := RegEx.new()
	expression.compile("^medieval\\.[a-z][a-z0-9_]*$")
	var contract: Dictionary = requirements()
	for node: Variant in nodes:
		if not node is Dictionary or not node.get("id") is String or expression.search(node["id"]) == null:
			errors.append("invalid_id")
			continue
		var id: String = node["id"]
		if ids.has(id): errors.append("duplicate_id:" + id)
		ids[id] = true
		for key: String in ["title_key", "description_key", "effect_key"]:
			if not node.get(key) is String or not node[key].begins_with("MEDTECH_"):
				errors.append("invalid_text:" + id + ":" + key)
		if not node.get("implemented") is bool or node["implemented"] != false or node.get("balance") != "provisional":
			errors.append("unsafe_effect_or_balance:" + id)
		for key: String in ["requires", "contract_requirements", "resources", "building_parts"]:
			var entries: Variant = node.get(key)
			if not entries is Array or entries.size() > 16:
				errors.append("invalid_list:" + id + ":" + key)
				continue
			var seen: Dictionary = {}
			for entry: Variant in entries:
				if not entry is String or entry.is_empty() or seen.has(entry):
					errors.append("invalid_reference:" + id + ":" + key)
					continue
				seen[entry] = true
				if key == "contract_requirements" and not contract.has(entry): errors.append("unknown_contract:" + entry)
				if key == "resources" and entry not in Resources.IDS: errors.append("unknown_resource:" + entry)
				if key == "building_parts" and Parts.get_part(entry).is_empty(): errors.append("unknown_building_part:" + entry)
	if not errors.is_empty(): return errors
	for node: Dictionary in nodes:
		for dependency: String in node["requires"]:
			if not ids.has(dependency): errors.append("unknown_dependency:" + node["id"] + ":" + dependency)
	if not errors.is_empty(): return errors
	# Bounded Kahn traversal: detects cycles even in disconnected components.
	var visited: Dictionary = {}
	for iteration: int in range(nodes.size()):
		var changed: bool = false
		for node: Dictionary in nodes:
			if visited.has(node["id"]): continue
			var ready: bool = true
			for dependency: String in node["requires"]:
				if not visited.has(dependency): ready = false
			if ready:
				visited[node["id"]] = true
				changed = true
		if not changed: break
	if visited.size() != nodes.size(): errors.append("dependency_cycle")
	return errors

static func find(value: Dictionary, id: String) -> Dictionary:
	for node: Dictionary in value.get("nodes", []):
		if node.get("id") == id: return node.duplicate(true)
	return {}

## Facts and marks are explicit caller-owned preview inputs, never save data.
## Even a fully satisfied plan can never release the medieval runtime.
static func describe(value: Dictionary, id: String, facts: Dictionary = {}, marks: Array[String] = []) -> Dictionary:
	var reasons: Array[Dictionary] = []
	if not validate(value).is_empty():
		return {"id": id, "preview_ready": false, "available": false, "implemented": false, "reasons": [{"code": "invalid_catalog"}]}
	var node: Dictionary = find(value, id)
	if node.is_empty():
		return {"id": id, "preview_ready": false, "available": false, "implemented": false, "reasons": [{"code": "unknown_technology"}]}
	for dependency: String in node["requires"]:
		if dependency not in marks: reasons.append({"code": "dependency_missing", "id": dependency})
	var contract: Dictionary = requirements()
	for requirement: String in node["contract_requirements"]:
		if not contract[requirement]["supported"] or not facts.get(requirement) is bool or facts[requirement] != true:
			reasons.append({"code": "contract_missing", "id": requirement, "supported": contract[requirement]["supported"]})
	return {"id": id, "preview_ready": reasons.is_empty(), "available": false, "implemented": false,
		"balance": "provisional", "reasons": reasons, "production_blockers": ["era_runtime_missing", "technology_effect_missing"],
		"marked": id in marks}
