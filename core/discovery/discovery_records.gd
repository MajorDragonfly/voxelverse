extends RefCounted
## Read-only journal views and JSON-safe observations. Progression owns persistence.

const Parts = preload("res://creatures/editor/creature_part_library.gd")
const KeyHints = preload("res://core/input_preferences.gd")
const ROLES := {"grazer": "Pflanzenfresser", "predator": "Räuber", "forager": "Sammler",
	"scavenger": "Aasfresser", "climber": "Kletterer", "swimmer": "Wasserbewohner"}
const CATEGORIES := {"body": "Körper", "mouth": "Mäuler", "eyes": "Augen", "legs": "Beine",
	"arms": "Arme", "tail": "Schwänze", "horns": "Hörner", "plates": "Panzerplatten",
	"spikes": "Stacheln", "decor": "Verzierungen", "paint": "Farben", "feet": "Füße", "hands": "Hände"}


static func observation(blueprint: Dictionary, location: String) -> Dictionary:
	# Keep anatomy, including future nested skin/attachment fields, but no player unlocks.
	var visual: Dictionary = {}
	for key in ["name", "version", "design_id", "body", "parts", "paint", "species", "assembly"]:
		if blueprint.has(key):
			visual[key] = blueprint[key]
	return {"version": 1, "location": location, "visual": encode(visual),
		"part_ids": part_ids(blueprint)}


static func part_ids(blueprint: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for field in ["body", "paint"]:
		var item: Variant = blueprint.get(field, {})
		if item is Dictionary:
			_append_id(result, str(item.get("part_id", "")))
	var placements: Variant = blueprint.get("parts", [])
	if placements is Array:
		for item in placements:
			if item is Dictionary:
				_append_id(result, str(item.get("part_id", "")))
	result.sort()
	return result


static func _append_id(result: Array[String], part_id: String) -> void:
	if not part_id.is_empty() and not result.has(part_id):
		result.append(part_id)


static func visual_for(entry: Dictionary) -> Dictionary:
	var record: Dictionary = as_dictionary(entry.get("journal", {}))
	if int(record.get("version", 0)) != 1:
		return {}
	var decoded: Variant = decode(record.get("visual", {}))
	if not decoded is Dictionary or not decoded.get("body") is Dictionary or not decoded.get("parts") is Array:
		return {}
	return decoded


static func species_rows(state: Dictionary, query: String = "", role: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var species: Dictionary = as_dictionary(state.get("discovered_species", {}))
	for key in species:
		if not species[key] is Dictionary:
			continue
		var entry: Dictionary = species[key].duplicate()
		entry["key"] = str(key)
		entry["role_label"] = ROLES.get(str(entry.get("role", "")), "Noch nicht bekannt")
		entry["location"] = location_for(entry)
		if not role.is_empty() and str(entry.get("role", "")) != role:
			continue
		var searchable: String = "%s %s %s" % [entry.get("name", ""), entry["role_label"], entry["location"]]
		if not query.strip_edges().is_empty() and not searchable.to_lower().contains(query.strip_edges().to_lower()):
			continue
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var comparison: int = str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", "")))
		return str(a["key"]) < str(b["key"]) if comparison == 0 else comparison < 0)
	return result


static func location_for(entry: Dictionary) -> String:
	var record: Dictionary = as_dictionary(entry.get("journal", {}))
	return str(record.get("location", "Welt %s" % saved_integer(entry.get("world_seed", "unbekannt"))))


static func saved_integer(value: Variant) -> String:
	# JSON reloads numbers as floats; world IDs and region cells remain integers.
	return str(int(value)) if value is int or value is float else str(value)


static func region_rows(state: Dictionary, query: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var regions: Dictionary = as_dictionary(state.get("discovered_regions", {}))
	for key in regions:
		if not regions[key] is Dictionary:
			continue
		var entry: Dictionary = regions[key].duplicate()
		entry["key"] = str(key)
		entry["name"] = "Region %s / %s" % [saved_integer(entry.get("x", "?")), saved_integer(entry.get("z", "?"))]
		entry["location"] = location_for(entry)
		var searchable: String = "%s %s" % [entry["name"], entry["location"]]
		if not query.strip_edges().is_empty() and not searchable.to_lower().contains(query.strip_edges().to_lower()):
			continue
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (str(a["location"]) + str(a["name"]) + str(a["key"])).naturalnocasecmp_to(str(b["location"]) + str(b["name"]) + str(b["key"])) < 0)
	return result


static func part_rows(state: Dictionary, query: String = "", category: String = "", status: int = 0) -> Array[Dictionary]:
	var unlocks: Dictionary = as_dictionary(state.get("unlocked_parts", {}))
	var settings: Dictionary = as_dictionary(state.get("research", {}))
	var wishes: Array = settings.get("wished_parts", []) if settings.get("wished_parts", []) is Array else []
	var catalog: Dictionary = {}
	for section in Parts.get_categories():
		for definition in Parts.get_parts_for_category(str(section["id"])):
			var row: Dictionary = definition.duplicate(true)
			row["category"] = str(section["id"])
			catalog[str(row["id"])] = row
	# Preserve unavailable saved IDs visibly, rather than silently hiding old unlocks.
	for part_id in unlocks.keys() + wishes:
		if not catalog.has(part_id):
			catalog[part_id] = {"id": str(part_id), "name": str(part_id), "category": "missing",
				"description": "Dieses gespeicherte Teil ist im aktuellen Teilekatalog nicht verfügbar."}
	var result: Array[Dictionary] = []
	for part_id in catalog:
		var row: Dictionary = catalog[part_id]
		row["unlocked"] = unlocks.has(part_id)
		row["wished"] = wishes.has(part_id)
		row["source"] = source_for(str(part_id), state)
		if not category.is_empty() and row["category"] != category:
			continue
		if (status == 1 and not row["unlocked"]) or (status == 2 and row["unlocked"]):
			continue
		if status == 3 and not row["wished"]:
			continue
		var search_text: String = "%s %s %s" % [row.get("name", ""), row["source"], CATEGORIES.get(row["category"], row["category"])]
		if not query.strip_edges().is_empty() and not search_text.to_lower().contains(query.strip_edges().to_lower()):
			continue
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["unlocked"] != b["unlocked"]:
			return a["unlocked"]
		return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	return result


static func source_for(part_id: String, state: Dictionary) -> String:
	var unlocks: Dictionary = as_dictionary(state.get("unlocked_parts", {}))
	if not unlocks.has(part_id):
		return "Noch gesperrt · weitere Arten beobachten"
	var unlock: Dictionary = as_dictionary(unlocks[part_id])
	var key: String = str(unlock.get("species_key", ""))
	var species: Dictionary = as_dictionary(state.get("discovered_species", {}))
	if not key.is_empty() and species.get(key) is Dictionary:
		return "Entdeckt bei %s · %s" % [species[key].get("name", "unbekannter Art"), location_for(species[key])]
	match str(unlock.get("reason", "")):
		"Starter part": return "Von Beginn an verfügbar"
		"Species discovery": return "Durch Artenentdeckung · ursprüngliche Art nicht vermerkt"
		"Migrated creature save": return "Aus deinem bisherigen Kreaturenentwurf übernommen"
	return "Bereits freigeschaltet"


static func next_step(state: Dictionary, health: float = 1.0, thirst: float = 1.0, hunger: float = 1.0) -> String:
	if health <= 0.0:
		return "Zurück zum Nest · nach der Erholung kannst du weiter erkunden."
	if thirst < 0.3:
		return "Wasser suchen · gehe ans Wasser und trinke mit Linksklick."
	if hunger < 0.3:
		return "Nahrung suchen · nutze Linksklick an Nahrung, die zu deiner Kreatur passt."
	if as_dictionary(state.get("discovered_species", {})).is_empty():
		return "Deine erste Art · %s öffnet den Scanmodus. Halte ein Tier im Fadenkreuz, bis der Kreis voll ist." % KeyHints.binding_label("inspection_mode")
	return "Weiter entdecken · scanne mit %s unbekannte Arten. Neue Teile findest du im Editor mit F2." % KeyHints.binding_label("inspection_mode")


static func as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func encode(value: Variant) -> Variant:
	if value is Vector3:
		return {"_journal_type": "v3", "v": [value.x, value.y, value.z]}
	if value is Color:
		return {"_journal_type": "color", "v": [value.r, value.g, value.b, value.a]}
	if value is Vector2i:
		return {"_journal_type": "v2i", "v": [value.x, value.y]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[str(key)] = encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(encode(item))
		return result
	if value == null or value is bool or value is String or value is int or value is float:
		return value
	return null


static func decode(value: Variant, depth: int = 0) -> Variant:
	if depth > 32:
		return null
	if value is Dictionary:
		if value.has("_journal_type"):
			var components: Variant = value.get("v", [])
			if not components is Array:
				return null
			for component in components:
				if not (component is float or component is int) or not is_finite(float(component)):
					return null
			match value["_journal_type"]:
				"v3":
					if components.size() == 3: return Vector3(components[0], components[1], components[2])
				"color":
					if components.size() == 4: return Color(components[0], components[1], components[2], components[3])
				"v2i":
					if components.size() == 2: return Vector2i(int(components[0]), int(components[1]))
			return null
		var result: Dictionary = {}
		for key in value:
			result[key] = decode(value[key], depth + 1)
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(decode(item, depth + 1))
		return result
	return value
