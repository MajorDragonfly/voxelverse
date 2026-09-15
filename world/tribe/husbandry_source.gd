extends RefCounted
## Read-only D1/D2 boundary. The host retains all animal identity and movement.
const Production = preload("res://world/tribe/production_catalog.gd")
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const D2 = preload("res://world/domestication/animal_state.gd")
var registry: Callable
var species: Callable
var actor: Callable

func read(data: Dictionary, campaign_id: String, identity: String, recipe_id: String = Production.MILK) -> Dictionary:
	if not registry.is_valid() or not species.is_valid() or not actor.is_valid():
		return {"error": "Das Tier ist zurzeit nicht verfügbar."}
	var book: Variant = registry.call()
	if not D2.validate(book).is_empty() or book["campaign_id"] != campaign_id or book["body_id"] != data["body_id"]:
		return {"error": "Das Tierregister gehört nicht zu diesem Dorf."}
	var animal: Dictionary = book["animals"].get(identity, {})
	if animal.is_empty() or animal["status"] != "tamed" or animal["owner_faction_id"] != data["faction_id"] or animal["species_id"] == data["species_id"]:
		return {"error": "Wähle ein lebendes, gezähmtes Nutztier deines Stammes."}
	var traits: Variant = species.call(animal["species_id"])
	var recipe: Dictionary = Production.definition(recipe_id)
	if recipe.is_empty() or not D1.validate(traits).is_empty() or recipe.role not in traits["roles"] or recipe.diet not in traits["diet"]:
		return {"error": "Dieses Tier eignet sich nicht für diesen Haltungsplatz mit Pflanzenfutter."}
	var body: Variant = actor.call(identity)
	if not body is Node3D or not is_instance_valid(body) or not body.is_inside_tree() or not body.is_visible_in_tree() or body.global_position.distance_to(preload("res://world/surface/gameplay_space.gd").resolve(body, animal["position"])) > 0.5:
		return {"error": "Das Tier muss in der geladenen Dorfumgebung sein."}
	var parameters: Dictionary = {recipe.yield_field: float(traits[recipe.yield_field]), recipe.interval_field: float(traits[recipe.interval_field]), "water_need": float(traits.water_need)}
	if recipe_id != Production.MILK: parameters.merge({"recipe_id": recipe_id, "recipe_revision": recipe.revision})
	return {"error": "", "animal": animal.duplicate(true), "actor": body, "recipe": parameters}

func candidates(data: Dictionary, campaign_id: String, recipe_id: String = Production.MILK) -> Array[String]:
	var result: Array[String] = []
	if not registry.is_valid():
		return result
	var book: Variant = registry.call()
	if not D2.validate(book).is_empty():
		return result
	for identity: String in book["animals"]:
		if read(data, campaign_id, identity, recipe_id)["error"] == "":
			result.append(identity)
	return result
