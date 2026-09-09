extends RefCounted
## Deliberately synthetic D2 test input. Never used by the species catalogue.
const State = preload("res://world/domestication/animal_state.gd")
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const Policy = preload("res://world/domestication/d1_taming_policy.gd")
const CAMPAIGN: String = "d2_fixture_campaign"
const BODY: String = "d2_fixture_body"
const FACTION: String = "d2_fixture_tribe"
const SPECIES: String = "d2_fixture_player_species"
const ACTOR: String = "d2_fixture_handler"
const ANIMAL: String = "d2_fixture_animal_01"
const FOREIGN: String = "d2_fixture_foreign_species"
const HOME: Vector3 = Vector3(-7.0, 0.0, 0.0)

static func create() -> Dictionary:
	var registry: Dictionary = State.empty_registry(CAMPAIGN, BODY)
	registry["animals"][ANIMAL] = State.individual(ANIMAL, FOREIGN, BODY,
		{"id": "d2_fixture_box_quadruped", "revision": 1}, Vector3(2.0, 0.0, 1.0))
	return {"schema": 1, "scope": "d2_lab_only", "registry": registry, "stock": {"roots": 12, "meat": 4},
		"phase": 1, "capacity": 1, "handler_position": [0.0, 0.0, 2.0], "friendship": false}

static func policy(species_id: String, food: String) -> Dictionary:
	# D1's own example suitability; no second catalogue or generated campaign ID.
	return Policy.evaluate(D1.suitability("companion") if species_id == FOREIGN else {},
		{"roots": "plant", "meat": "meat"}.get(food, ""))

static func context(snapshot: Dictionary) -> Dictionary:
	return {"campaign_id": CAMPAIGN, "body_id": BODY, "phase": snapshot["phase"], "capacity": snapshot["capacity"],
		"faction_id": FACTION, "player_species_id": SPECIES, "actor_id": ACTOR, "actor_alive": true,
		"actor_position": State.vector(snapshot["handler_position"]), "home": HOME,
		"line_of_sight": true, "threatened": false, "paused": false, "stock": snapshot["stock"].duplicate()}

static func validate(value: Variant) -> String:
	if not value is Dictionary or not State.integer(value.get("schema"), 1, 1) or value.get("scope") != "d2_lab_only":
		return "Nicht unterstützter D2-Prüfstand."
	var error: String = State.validate(value.get("registry"))
	if not error.is_empty(): return error
	if value["registry"]["campaign_id"] != CAMPAIGN or value["registry"]["body_id"] != BODY:
		return "Prüfstand gehört zu einer anderen Welt."
	if not value["registry"]["animals"].has(ANIMAL):
		return "Das konkrete Prüftier fehlt."
	if not State.integer(value.get("phase"), 0, 1) or not State.integer(value.get("capacity"), 1, State.MAX_ANIMALS) or not State.point(value.get("handler_position")) or not value.get("friendship") is bool:
		return "Ungültige Prüfszeneneinstellungen."
	if not value.get("stock") is Dictionary or value["stock"].keys().size() != 2:
		return "Ungültiger Futterbestand."
	for food in ["roots", "meat"]:
		if not State.integer(value["stock"].get(food), 0, 1000000000): return "Ungültiger Futterbestand."
	return ""
