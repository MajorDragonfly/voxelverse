extends SceneTree
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const Policy = preload("res://world/domestication/d1_taming_policy.gd")
var failures: Array[String] = []
var checks: int = 0
var stored: Dictionary = {}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for group: String in D1.GROUPS:
		stored["species_" + group] = D1.suitability(group)
	var before: String = JSON.stringify(stored)
	var adapter = Policy.new(func(id: String) -> Variant: return stored.get(id, {}), {"roots": "plant", "meat": "meat"})
	for group: String in D1.GROUPS:
		var plant: Dictionary = adapter.for_species("species_" + group, "roots")
		_expect(plant["eligible"] and plant["food_allowed"] and plant["food_units"] == 1, "D1 role did not accept its actual food: " + group)
		_expect(plant["trust_gain"] > 0.0 and plant["trust_gain"] <= 25.0, "Invalid D1 learning gain")
		_expect(not adapter.for_species("species_" + group, "meat")["food_allowed"], "Plant eater accepted meat")
	_expect(not adapter.for_species("unknown_species", "roots")["eligible"], "Unknown species inferred from role/name")
	_expect(not adapter.for_species("species_milk", "milk")["food_allowed"], "Unknown inventory resource accepted")
	_expect(adapter.for_species("species_companion", "roots")["trust_gain"] > adapter.for_species("species_work", "roots")["trust_gain"], "D1 trainability ignored")
	_expect(JSON.stringify(stored) == before, "D2 rewrote D1 species data")
	stored["species_companion"]["schema"] = 2
	_expect(not adapter.for_species("species_companion", "roots")["eligible"], "Unreviewed D1 version accepted")
	stored["species_milk"]["tameable"] = false
	_expect(not adapter.for_species("species_milk", "roots")["eligible"], "Untameable species accepted")
	stored["species_work"]["anatomy"]["back_clear"] = false
	_expect(not adapter.for_species("species_work", "roots")["eligible"], "Invalid D1 anatomy accepted")
	var missing = Policy.new()
	_expect(not missing.for_species("species_companion", "roots")["eligible"], "Missing D1 lookup accepted")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	print("D2_D1_ADAPTER_PASS" if failures.is_empty() else "D2_D1_ADAPTER_FAIL")
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
