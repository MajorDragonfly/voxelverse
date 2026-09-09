extends RefCounted
## D2 owns individuals only. Species suitability belongs exclusively to D1.
const SCHEMA: int = 1
const ORDERS: Array[String] = ["wait", "follow", "home"]
const STATES: Array[String] = ["wild", "taming", "tamed", "dead"]
const OFFER_SECONDS: float = 2.0
const MAX_ANIMALS: int = 256

static func empty_registry(campaign_id: String, body_id: String) -> Dictionary:
	return {"schema": SCHEMA, "campaign_id": campaign_id, "body_id": body_id, "animals": {}}

static func individual(object_id: String, species_id: String, body_id: String, design_ref: Dictionary, position: Vector3) -> Dictionary:
	return {"object_id": object_id, "species_id": species_id, "body_id": body_id,
		"design_ref": design_ref.duplicate(true), "surface_mode": "legacy_plane_v9",
		"position": point_array(position), "home": point_array(position), "wait_position": point_array(position),
		"owner_faction_id": "", "claim_faction_id": "", "status": "wild", "trust": 0.0,
		"health": 100.0, "hunger": 0.0, "thirst": 0.0, "order": "wait", "handler_id": "",
		"pending": {}, "equipment": {}, "cargo": {}}

static func occupied(registry: Dictionary, faction_id: String) -> int:
	var count: int = 0
	for animal: Dictionary in registry["animals"].values():
		if animal["status"] != "dead" and (animal["owner_faction_id"] == faction_id or animal["claim_faction_id"] == faction_id):
			count += 1
	return count

static func validate(value: Variant) -> String:
	if not value is Dictionary or not integer(value.get("schema"), SCHEMA, SCHEMA):
		return "Nicht unterstütztes D2-Tierformat."
	if not identity(value.get("campaign_id")) or not identity(value.get("body_id")):
		return "Kampagnen- oder Körperidentität fehlt."
	var animals: Variant = value.get("animals")
	if not animals is Dictionary or animals.size() > MAX_ANIMALS:
		return "Ungültiges Tierregister."
	for key: Variant in animals:
		var a: Variant = animals[key]
		if not a is Dictionary or a.get("object_id") != key or not identity(key) or not identity(a.get("species_id")) or a.get("body_id") != value["body_id"]:
			return "Ungültige Tieridentität."
		if a.get("surface_mode") != "legacy_plane_v9":
			return "D2-Prüfszene unterstützt nur den ausdrücklich benannten Ebenenadapter."
		var design: Variant = a.get("design_ref")
		if not design is Dictionary or not identity(design.get("id")) or not integer(design.get("revision"), 0, 1000000000):
			return "Ungültiger Körperentwurfsbezug."
		for field in ["position", "home", "wait_position"]:
			if not point(a.get(field)):
				return "Ungültiger Tierort."
		for field in ["owner_faction_id", "claim_faction_id", "handler_id"]:
			if not a.get(field) is String or a[field].length() > 160:
				return "Ungültiger Besitzer oder Betreuer."
		for field in ["trust", "health", "hunger", "thirst"]:
			if not number(a.get(field), 0.0, 100.0):
				return "Ungültiger Tierzustand."
		if a.get("status") not in STATES or a.get("order") not in ORDERS:
			return "Ungültiger Tierauftrag."
		# Reserved future D3/D4 payloads must never silently disappear.
		if a.get("equipment") != {} or a.get("cargo") != {}:
			return "Ausrüstung und Produktion benötigen einen späteren Vertrag."
		var owned: bool = not a["owner_faction_id"].is_empty()
		var claimed: bool = not a["claim_faction_id"].is_empty()
		if a["status"] == "tamed" and (not owned or claimed or float(a["trust"]) != 100.0):
			return "Gezähmtes Tier ohne gültige Bindung."
		if a["status"] in ["wild", "taming"] and (owned or float(a["trust"]) >= 100.0):
			return "Wildtier darf keinen Besitzer haben."
		if (a["status"] == "taming") != claimed:
			return "Ungültige Bestandsreservierung."
		if (a["status"] == "dead") != (float(a["health"]) == 0.0):
			return "Tod und Gesundheit widersprechen sich."
		if a["status"] != "tamed" and (a["order"] != "wait" or not a["handler_id"].is_empty()):
			return "Nur lebende gezähmte Tiere erhalten Befehle."
		if a["order"] == "follow" and a["handler_id"].is_empty():
			return "Folgen benötigt einen konkreten Betreuer."
		var pending: Variant = a.get("pending")
		if not pending is Dictionary:
			return "Ungültiger Zähmversuch."
		if not pending.is_empty():
			if a["status"] != "taming" or not identity(pending.get("actor_id")) or pending.get("faction_id") != a["claim_faction_id"] or not identity(pending.get("food")) or not number(pending.get("elapsed"), 0.0, OFFER_SECONDS - 0.000001):
				return "Ungültiger gespeicherter Zähmversuch."
	return ""

static func identity(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 160

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value, low, high) and float(value) == floorf(float(value))

static func point(value: Variant) -> bool:
	return value is Array and value.size() == 3 and number(value[0], -1.0e7, 1.0e7) and number(value[1], -1.0e7, 1.0e7) and number(value[2], -1.0e7, 1.0e7)

static func point_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
