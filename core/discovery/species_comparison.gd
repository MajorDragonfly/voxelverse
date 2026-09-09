extends RefCounted
## Projections of observed anatomy. Never edits creatures or awards progression.

const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const METRICS := [
	{"id": "attack", "label": "Angriff", "hint": "Angriffswert des Körperbaus; kein garantierter Schaden pro Biss."},
	{"id": "defense", "label": "Verteidigung", "hint": "Verteidigungswert durch Körper und angesetzte Teile."},
	{"id": "health", "label": "Lebenskraft", "hint": "Körperbauwert für Gesundheit, einschließlich Körpergröße; keine aktuelle Gesundheit."},
	{"id": "speed", "label": "Tempo", "hint": "Tempo des Körperbaus einschließlich Masse; Bewegung im Spiel kann begrenzt sein."},
	{"id": "jump", "label": "Sprungkraft", "hint": "Sprungwert des Körperbaus; keine Höhenangabe in Metern."},
	{"id": "swim", "label": "Schwimmen", "hint": "Anatomischer Schwimmwert. Daraus folgt keine bestimmte Schwimmgeschwindigkeit."},
	{"id": "perception", "label": "Wahrnehmung", "hint": "Wahrnehmungswert durch Körperteile."},
	{"id": "grip", "label": "Greifkraft", "hint": "Greifwert durch Körperteile."},
	{"id": "diet_plant", "label": "Pflanzenkost", "hint": "Eignung des Körperbaus für pflanzliche Nahrung."},
	{"id": "diet_meat", "label": "Fleischkost", "hint": "Eignung des Körperbaus für tierische Nahrung."},
	{"id": "flight", "label": "Flugwert", "hint": "Anatomischer Flugwert; schaltet allein keinen Flugmodus frei."},
	{"id": "hunger_drain", "label": "Nahrungsbedarf", "hint": "Grundverbrauch des Körperbaus. Ein kleinerer Wert bedeutet weniger Verbrauch."},
]
const MAIN_METRICS := ["attack", "defense", "health", "speed", "jump", "swim"]


static func stats_for(blueprint: Dictionary) -> Dictionary:
	if blueprint.is_empty() or not blueprint.get("body") is Dictionary or not blueprint.get("parts") is Array:
		return {}
	if Records.Parts.get_part(str(blueprint["body"].get("part_id", ""))).is_empty():
		return {}
	for placement in blueprint["parts"]:
		if not placement is Dictionary or Records.Parts.get_part(str(placement.get("part_id", ""))).is_empty():
			return {}
	# An obsolete part must not silently look like a zero-value part.
	for part_id in Records.part_ids(blueprint):
		if Records.Parts.get_part(part_id).is_empty():
			return {}
	return Blueprint.calculate_stats(blueprint.duplicate(true))


static func part_rows(blueprint: Dictionary, state: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var available: Dictionary = state.get("unlocked_parts", {})
	var wishes: Array = state.get("research", {}).get("wished_parts", [])
	for id in Records.part_ids(blueprint):
		var definition: Dictionary = Records.Parts.get_part(id)
		var count: int = 0
		for field in ["body", "paint"]:
			if str(blueprint.get(field, {}).get("part_id", "")) == id:
				count += 1
		for placement in blueprint.get("parts", []):
			if placement is Dictionary and str(placement.get("part_id", "")) == id:
				count += 1
		rows.append({"id": id, "name": definition.get("name", id), "count": count,
			"available": not definition.is_empty(), "unlocked": available.has(id), "wished": wishes.has(id),
			"contribution": contribution(blueprint, id)})
	return rows


static func contribution(blueprint: Dictionary, id: String) -> Dictionary:
	var complete: Dictionary = stats_for(blueprint)
	if complete.is_empty():
		return {}
	var without: Dictionary = blueprint.duplicate(true)
	if str(without.get("body", {}).get("part_id", "")) == id:
		without["body"]["part_id"] = ""
	var retained: Array = []
	for placement in without.get("parts", []):
		if placement is Dictionary and str(placement.get("part_id", "")) != id:
			retained.append(placement)
	without["parts"] = retained
	var remaining: Dictionary = Blueprint.calculate_stats(without)
	var result: Dictionary = {}
	for metric in METRICS:
		var key: String = metric["id"]
		var value: float = float(complete.get(key, 0.0)) - float(remaining.get(key, 0.0))
		if absf(value) > 0.00001:
			result[key] = value
	return result


static func formatted(value: float, signed_value: bool = false) -> String:
	if absf(value) < 0.005:
		value = 0.0
	var result: String = ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
	if signed_value and value > 0.0:
		result = "+" + result
	return result.replace(".", ",")
