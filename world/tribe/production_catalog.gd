extends RefCounted
## D1/D2 remain authoritative for suitability, ownership and live attendance.
## The recipe view adapts saved D3 parameters without resetting clocks/fractions.
const CARE_SECONDS: float = 300.0
const MILK: String = "husbandry.milk"
const EGGS: String = "husbandry.eggs"
const RECIPES: Dictionary = {
	MILK: {"revision": 1, "resource_id": "milk", "role": "milk", "diet": "plant",
		"care_seconds": CARE_SECONDS, "conditions": ["tamed", "same_faction", "foreign_species", "pen_attendance", "food", "water", "simulation_time"],
		"yield_field": "milk_yield", "interval_field": "milk_interval"},
	EGGS: {"revision": 1, "resource_id": "eggs", "role": "eggs", "diet": "plant",
		"care_seconds": CARE_SECONDS, "conditions": ["tamed", "same_faction", "foreign_species", "pen_attendance", "food", "water", "simulation_time"],
		"yield_field": "egg_yield", "interval_field": "egg_interval"},
}

static func definition(identity: String) -> Dictionary:
	return RECIPES.get(identity, {}).duplicate(true)

static func from_milk(parameters: Dictionary) -> Dictionary:
	return from_parameters(MILK, parameters)

static func from_parameters(identity: String, parameters: Dictionary) -> Dictionary:
	var recipe: Dictionary = definition(identity)
	if recipe.is_empty(): return {}
	recipe.merge({"recipe_id": identity, "yield": parameters[recipe.yield_field],
		"interval": parameters[recipe.interval_field], "inputs": {"food": 1.0, "water": parameters.water_need}})
	return recipe

static func produced(cycles: int, recipe: Dictionary) -> int:
	# No epsilon: sub-unit output survives across cycles and JSON restarts.
	return floori(float(cycles) * float(recipe["yield"]))
