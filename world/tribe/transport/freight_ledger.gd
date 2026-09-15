extends RefCounted
## Cumulative inter-site transfers and held capacity, inside the village owner.
const KINDS: Array[String] = ["wood", "stone", "food", "water", "fiber", "milk", "eggs"]

static func create() -> Dictionary:
	var data: Dictionary = {"schema": 1, "imports": {}, "exports": {}, "held": {}}
	for field: String in ["imports", "exports", "held"]:
		for kind: String in KINDS: data[field][kind] = 0
	return data

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 4 or data.get("schema") != 1: return false
	for field: String in ["imports", "exports", "held"]:
		var values: Variant = data.get(field)
		if not values is Dictionary or values.size() != KINDS.size(): return false
		for kind: String in KINDS:
			var n: Variant = values.get(kind)
			if not (n is int or n is float) or not is_finite(float(n)) or n != floorf(float(n)) or n < 0 or n > (48 if field == "held" else 1000000000): return false
	return true

static func amount(data: Dictionary, field: String, kind: String) -> int:
	return int(data.get("economy", {}).get("freight", {}).get(field, {}).get(kind, 0))

static func net(data: Dictionary, kind: String) -> int:
	return amount(data, "imports", kind) - amount(data, "exports", kind)
