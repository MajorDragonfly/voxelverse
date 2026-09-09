extends RefCounted
## Read-only D1/D2 boundary. The host retains all animal identity and movement.
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const D2 = preload("res://world/domestication/animal_state.gd")
var registry: Callable
var species: Callable
var actor: Callable

func read(data: Dictionary, campaign_id: String, identity: String) -> Dictionary:
	if not registry.is_valid() or not species.is_valid() or not actor.is_valid():
		return {"error": "Das Tier ist zurzeit nicht verfügbar."}
	var book: Variant = registry.call()
	if not D2.validate(book).is_empty() or book["campaign_id"] != campaign_id or book["body_id"] != data["body_id"]:
		return {"error": "Das Tierregister gehört nicht zu diesem Dorf."}
	var animal: Dictionary = book["animals"].get(identity, {})
	if animal.is_empty() or animal["status"] != "tamed" or animal["owner_faction_id"] != data["faction_id"] or animal["species_id"] == data["species_id"]:
		return {"error": "Wähle ein lebendes, gezähmtes Milchtier deines Stammes."}
	var traits: Variant = species.call(animal["species_id"])
	if not D1.validate(traits).is_empty() or "milk" not in traits["roles"] or "plant" not in traits["diet"]:
		return {"error": "Dieses Tier eignet sich nicht für die Milchhaltung mit Pflanzenfutter."}
	var body: Variant = actor.call(identity)
	if not body is Node3D or not is_instance_valid(body) or not body.is_inside_tree() or not body.is_visible_in_tree() or body.global_position.distance_to(preload("res://world/surface/gameplay_space.gd").resolve(body, animal["position"])) > 0.5:
		return {"error": "Das Tier muss in der geladenen Dorfumgebung sein."}
	return {"error": "", "animal": animal.duplicate(true), "actor": body,
		"recipe": {"milk_yield": float(traits["milk_yield"]), "milk_interval": float(traits["milk_interval"]), "water_need": float(traits["water_need"])}}

func candidates(data: Dictionary, campaign_id: String) -> Array[String]:
	var result: Array[String] = []
	if not registry.is_valid():
		return result
	var book: Variant = registry.call()
	if not D2.validate(book).is_empty():
		return result
	for identity: String in book["animals"]:
		if read(data, campaign_id, identity)["error"] == "":
			result.append(identity)
	return result
