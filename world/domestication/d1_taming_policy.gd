extends RefCounted
## Consumes the reviewed D1 v1 suitability object through a read-only resolver.
## The resolver must return the exact existing species' domestication data,
## never infer a new species from an ecological role or a display name.
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
var resolve_species: Callable
var food_classes: Dictionary

func _init(resolver: Callable = Callable(), host_food_classes: Dictionary = {}) -> void:
	resolve_species = resolver
	food_classes = host_food_classes.duplicate()

func for_species(species_id: String, food_resource: String) -> Dictionary:
	if not resolve_species.is_valid():
		return {"eligible": false, "reason": "d1_unavailable"}
	return evaluate(resolve_species.call(species_id), food_classes.get(food_resource, ""))

static func evaluate(suitability: Variant, food_class: String) -> Dictionary:
	var error: String = D1.validate(suitability)
	if not error.is_empty():
		return {"eligible": false, "reason": error}
	# D2 balance, not D1 fields: one real inventory unit per completed offer.
	# D1's learning ability controls gain; the fixture companion earns 25.
	return {"eligible": suitability["tameable"], "food_allowed": food_class in suitability["diet"],
		"food_units": 1, "trust_gain": 25.0 * clampf(float(suitability["trainability"]) / 0.9, 0.1, 1.0)}
