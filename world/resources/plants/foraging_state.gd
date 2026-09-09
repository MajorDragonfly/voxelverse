extends RefCounted
## Body extension. Unknown payloads and invalid entries remain untouched.

const SCHEMA: int = 1
const LIMIT: int = 32768

static func body(state: Node, expected_id: String = "") -> Dictionary:
	var key: String = str(int(state.get_world_seed()))
	if not state.campaign.data["bodies"].has(key):
		state.get_current_body()
	var record: Dictionary = state.campaign.data["bodies"][key]
	if not expected_id.is_empty() and record.get("id") != expected_id:
		return {}
	return record

static func ledger(state: Node, body_id: String) -> Dictionary:
	var record: Dictionary = body(state, body_id)
	if record.is_empty():
		return {}
	if not record.has("wildlife_foraging"):
		record["wildlife_foraging"] = {"schema": SCHEMA, "body_id": body_id, "animals": {}, "plants": {}}
	var value: Variant = record["wildlife_foraging"]
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("body_id") != body_id:
		return {}
	for section in ["animals", "plants"]:
		if not value.get(section) is Dictionary or value[section].size() > LIMIT:
			return {}
	return value

static func animal(state: Node, body_id: String, object_id: String, initial: float) -> Dictionary:
	var data: Dictionary = ledger(state, body_id)
	if data.is_empty() or object_id.is_empty():
		return {}
	var entries: Dictionary = data["animals"]
	if not entries.has(object_id):
		if entries.size() >= LIMIT:
			return {}
		entries[object_id] = {"satiety": initial, "seeking": initial < 45.0}
	var entry: Variant = entries[object_id]
	if not entry is Dictionary or not number(entry.get("satiety"), 0.0, 100.0) or not entry.get("seeking") is bool:
		return {}
	return entry

static func plant(state: Node, body_id: String, key: String, capacity: float) -> Dictionary:
	var data: Dictionary = ledger(state, body_id)
	if data.is_empty():
		return {}
	var entries: Dictionary = data["plants"]
	if not entries.has(key):
		if entries.size() >= LIMIT:
			return {}
		entries[key] = {"remaining": capacity, "regrow_at": 0.0}
	var entry: Variant = entries[key]
	if not entry is Dictionary or not number(entry.get("remaining"), 0.0, capacity) or not number(entry.get("regrow_at"), 0.0, 1.0e12):
		return {}
	return entry

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum
