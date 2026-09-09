extends RefCounted
## Body-owned extension with existing object IDs and ordinary campaign saves.

const BodyState = preload("res://world/resources/plants/foraging_state.gd")
const SCHEMA: int = 1
const LIMIT: int = 32768

static func animal(state: Node, identity: Dictionary, initial: float) -> Dictionary:
	var population: Node = state.get_tree().get_first_node_in_group(&"campaign_surface_population")
	if population != null and population.body().id == identity.get("body_id"): return population.needs(str(identity.get("object_id", "")), "drinking", initial)
	var body: Dictionary = BodyState.body(state, str(identity.get("body_id", "")))
	var object_id: String = str(identity.get("object_id", ""))
	if body.is_empty() or object_id.is_empty() or identity.get("body_id") != body["id"]:
		return {}
	if not body.has("wildlife_drinking"):
		body["wildlife_drinking"] = {"schema": SCHEMA, "body_id": body["id"], "animals": {}}
	var ledger: Variant = body["wildlife_drinking"]
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or ledger.get("body_id") != body["id"] or not ledger.get("animals") is Dictionary or ledger["animals"].size() > LIMIT:
		return {}
	var entries: Dictionary = ledger["animals"]
	if not entries.has(object_id):
		if entries.size() >= LIMIT:
			return {}
		entries[object_id] = {"hydration": initial, "seeking": initial < 45.0}
	var value: Variant = entries[object_id]
	if not value is Dictionary or not BodyState.number(value.get("hydration"), 0.0, 100.0) or not value.get("seeking") is bool:
		return {}
	return value

static func validate(value: Variant, body_id: String) -> String:
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("body_id") != body_id or not value.get("animals") is Dictionary or value.animals.size() > LIMIT: return "Ungültiger Trinkbestand."
	for id in value.animals:
		var item: Variant = value.animals[id]
		if not id is String or id.is_empty() or not item is Dictionary or not BodyState.number(item.get("hydration"), 0, 100) or not item.get("seeking") is bool: return "Ungültiger Durstzustand."
	return ""
