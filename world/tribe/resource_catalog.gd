extends RefCounted
## Fixed resource identities. Revision 1 retains the existing stock units/balance.
## Legacy ledger keys are storage adapters, never duplicate counters.
const REVISION: int = 1
const IDS: Array[String] = ["wood", "stone", "food", "water", "fiber", "milk"]
const FOODS: Array[String] = ["milk", "food"]
const TITLES: Dictionary = {"wood": "Holz", "stone": "Stein", "food": "Nahrung", "water": "Wasser", "fiber": "Fasern", "milk": "Milch"}
const DEFINITIONS: Dictionary = {
	"wood": {"unit": "unit", "nutrition": 0.0, "hydration": 0.0, "label_key": "resource.wood", "icon_key": "resource.wood", "color": "b9854d"},
	"stone": {"unit": "unit", "nutrition": 0.0, "hydration": 0.0, "label_key": "resource.stone", "icon_key": "resource.stone", "color": "bac8cf"},
	"food": {"unit": "portion", "nutrition": 25.0, "hydration": 0.0, "label_key": "resource.food", "icon_key": "hunger_drain", "color": "c27b4e"},
	"water": {"unit": "unit", "nutrition": 0.0, "hydration": 30.0, "label_key": "resource.water", "icon_key": "resource.water", "color": "60bde8", "consumed_key": "drinks"},
	"fiber": {"unit": "unit", "nutrition": 0.0, "hydration": 0.0, "label_key": "resource.fiber", "icon_key": "resource.fiber", "color": "b8bf67"},
	"milk": {"unit": "litre", "nutrition": 25.0, "hydration": 0.0, "label_key": "resource.milk", "icon_key": "resource.milk", "color": "f4f0dd", "received_key": "milk_received", "consumed_key": "milk_meals"},
}

static func definition(identity: String) -> Dictionary:
	var result: Dictionary = DEFINITIONS.get(identity, {}).duplicate(true)
	if not result.is_empty():
		result.merge({"resource_id": identity, "revision": REVISION, "capacity": 48})
	return result

static func uses_batches(identity: String) -> bool:
	return DEFINITIONS.get(identity, {}).has("received_key")

static func total(economy: Dictionary, identity: String, counter: String) -> int:
	var key: String = str(DEFINITIONS.get(identity, {}).get(counter + "_key", ""))
	return int(economy.get(key, 0)) if not key.is_empty() else 0

static func add(economy: Dictionary, identity: String, counter: String, amount: int) -> void:
	var key: String = str(DEFINITIONS[identity].get(counter + "_key", ""))
	if not key.is_empty(): economy[key] += amount
