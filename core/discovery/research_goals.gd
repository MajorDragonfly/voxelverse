extends RefCounted
## Goals derive progress from discoveries. Only player choices are persisted.

const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Rules = preload("res://core/progression/behavior_catalog.gd")
const VERSION: int = 1
const MAX_WISHES: int = 32
const GOALS: Array[Dictionary] = [
	{"id": "species.first", "name": "Erste Begegnung", "kind": "species", "target": 1, "unit": "Art", "description": "Entdecke deine erste Tierart. Ziele auf ein Tier in deiner Nähe und beobachte es mit Linksklick."},
	{"id": "species.three", "name": "Artenvielfalt", "kind": "species", "target": 3, "unit": "Arten", "description": "Entdecke drei verschiedene Tierarten. Bereits bekannte Arten zählen beim erneuten Beobachten nicht noch einmal."},
	{"id": "role.swimmer", "name": "Leben im Wasser", "kind": "role", "role": "swimmer", "target": 1, "unit": "Wasserart", "description": "Entdecke eine wasserbewohnende Tierart. Suche an Gewässern nach Tieren und beobachte sie mit Linksklick."},
	{"id": "regions.three", "name": "Neue Horizonte", "kind": "regions", "target": 3, "unit": "Regionen", "description": "Erkunde drei verschiedene Regionen. Neu betretene Regionen werden vom Spiel erfasst; wiederholte Besuche zählen nicht mehrfach."},
	{"id": "species.ten", "name": "Feldforscher", "kind": "species", "target": 10, "unit": "Arten", "description": "Entdecke zehn verschiedene Tierarten. Die Entdeckungen deiner gesamten Kampagne zählen mit."},
]


static func defaults() -> Dictionary:
	return {"version": VERSION, "pinned": "", "wished_parts": []}


static func validate(value: Variant) -> String:
	if not value is Dictionary or not Rules.is_integer(value.get("version", 0), 1, VERSION):
		return "Unsupported research settings."
	if not value.get("pinned") is String or value["pinned"].length() > 200:
		return "Invalid pinned research goal."
	var wishes: Variant = value.get("wished_parts")
	if not wishes is Array or wishes.size() > MAX_WISHES:
		return "Invalid research wishlist."
	var seen: Dictionary = {}
	for id in wishes:
		if not id is String or id.is_empty() or id.length() > 160 or seen.has(id):
			return "Invalid or repeated wishlist part."
		seen[id] = true
	if value["pinned"].begins_with("part:") and not seen.has(value["pinned"].trim_prefix("part:")):
		return "Pinned part is missing from the wishlist."
	return ""


static func has_unsupported_contract(value: Variant) -> bool:
	return value is Dictionary and Rules.is_newer_version(value.get("version", 0), VERSION)


static func is_goal(id: String) -> bool:
	for goal in GOALS:
		if goal["id"] == id:
			return true
	return false


static func rows(state: Dictionary, query: String = "") -> Array[Dictionary]:
	var species: Dictionary = state.get("discovered_species", {})
	var regions: Dictionary = state.get("discovered_regions", {})
	var roles: Dictionary = {}
	var species_count: int = 0
	var region_count: int = 0
	for entry in species.values():
		if entry is Dictionary:
			species_count += 1
			var role: String = str(entry.get("role", ""))
			roles[role] = int(roles.get(role, 0)) + 1
	for entry in regions.values():
		if entry is Dictionary:
			region_count += 1
	var result: Array[Dictionary] = []
	for definition in GOALS:
		var row: Dictionary = definition.duplicate(true)
		if not query.strip_edges().is_empty() and not (row["name"] + " " + row["description"]).to_lower().contains(query.strip_edges().to_lower()):
			continue
		var count: int = species_count
		if row["kind"] == "regions": count = region_count
		if row["kind"] == "role": count = int(roles.get(row["role"], 0))
		row["key"] = row["id"]
		row["current"] = mini(count, int(row["target"]))
		row["complete"] = count >= int(row["target"])
		row["available"] = true
		result.append(row)
	var old_pin: String = state.get("research", {}).get("pinned", "")
	if not old_pin.is_empty() and not old_pin.begins_with("part:") and not is_goal(old_pin) and query.strip_edges().is_empty():
		result.append({"id": old_pin, "key": old_pin, "name": "Ziel nicht mehr verfügbar", "current": 0,
			"target": 1, "unit": "", "complete": false, "available": false, "kind": "missing",
			"description": "Dieses vorgemerkte Ziel gehört zu einem früheren Stand. Du kannst die Vormerkung entfernen oder ein anderes Ziel wählen."})
	return result


static func pinned(state: Dictionary, settings: Dictionary) -> Dictionary:
	var id: String = settings.get("pinned", "")
	if id.is_empty():
		return {}
	if id.begins_with("part:"):
		var part_id: String = id.trim_prefix("part:")
		var definition: Dictionary = Parts.get_part(part_id)
		var available: bool = not definition.is_empty()
		var complete: bool = state.get("unlocked_parts", {}).has(part_id)
		return {"id": id, "key": part_id, "name": definition.get("name", part_id), "target": 1,
			"current": 1 if complete else 0, "complete": complete, "available": available,
			"unit": "Teil", "kind": "part"}
	for row in rows(state):
		if row["id"] == id:
			return row
	return {"id": id, "key": id, "name": "Ziel nicht mehr verfügbar", "current": 0,
		"target": 1, "unit": "", "kind": "missing", "available": false, "complete": false}
