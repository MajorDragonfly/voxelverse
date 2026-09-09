extends RefCounted
## Body-owned extension with existing object IDs and ordinary campaign saves.

const BodyState = preload("res://world/resources/plants/foraging_state.gd")
const SCHEMA: int = 1
const LIMIT: int = 32768

static func animal(state: Node, identity: Dictionary, initial: float) -> Dictionary:
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
