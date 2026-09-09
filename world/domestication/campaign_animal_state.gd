extends RefCounted
## Optional body.domesticated_animals; lives in the ONE campaign snapshot.
const State = preload("res://world/domestication/animal_state.gd")
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const SCHEMA: int = 1
const FIELD: String = "domesticated_animals"
const CAPACITY: int = 6

static func create(campaign: Dictionary, body: Dictionary) -> Dictionary:
	var registry: Dictionary = State.empty_registry(campaign["id"], body["id"])
	if body.surface_mode == State.Home.Cube.MODE: registry.schema = State.SCHEMA
	return {"schema": SCHEMA, "registry": registry, "sources": {}}

static func lookup(state: Node, object_id: String) -> Dictionary:
	var body: Dictionary = state.get_current_body_record()
	return body.get(FIELD, {}).get("registry", {}).get("animals", {}).get(object_id, {})

static func source_from(actor: Node3D) -> Dictionary:
	var identity: Dictionary = actor.get_campaign_identity().duplicate(true)
	return {"identity": identity, "blueprint": D1.encode(actor.blueprint),
		"visual_scale": float(actor._preview.scale.x), "maximum_health": float(actor.maximum_health),
		"speed": float(actor._move_speed), "species_seed": int(actor.species_seed),
		"individual_seed": int(actor.individual_seed), "role": str(actor.ecological_role),
		"name": str(actor.get_display_name()), "fear_until": 0.0,
		"heading": float(actor._visual_root.rotation.y), "preview_offset": State.point_array(actor._preview.position)}

static func validate_body(body: Dictionary, campaign: Dictionary) -> String:
	if not body.has(FIELD): return ""
	var data: Variant = body[FIELD]
	if not data is Dictionary or not State.integer(data.get("schema"), SCHEMA, SCHEMA):
		return "Nicht unterstützter Tierhaltungsstand."
	var error: String = State.validate(data.get("registry"))
	if not error.is_empty(): return error
	var registry: Dictionary = data["registry"]
	if registry["campaign_id"] != campaign.get("id") or registry["body_id"] != body.get("id"):
		return "Tierhaltung gehört zu einer anderen Kampagne oder Welt."
	if not data.get("sources") is Dictionary or data["sources"].size() != registry["animals"].size():
		return "Gespeicherter Tierkörper fehlt."
	if registry["animals"].is_empty(): return ""
	var tribe: Variant = body.get("tribe")
	if not tribe is Dictionary or tribe.get("body_id") != body["id"]:
		return "Tierhaltung benötigt den zugehörigen Stamm."
	var members: Array = []
	for member: Dictionary in tribe.get("members", []): members.append(member["id"])
	for id: String in registry["animals"]:
		var animal: Dictionary = registry["animals"][id]
		if id in members or animal["species_id"] == campaign.get("player_species_id"):
			return "Bürger und eigene Spezies dürfen keine gehaltenen Fremdtiere werden."
		if animal["owner_faction_id"] not in ["", tribe["faction_id"]] or animal["claim_faction_id"] not in ["", tribe["faction_id"]]:
			return "Tierbesitz gehört nicht zum örtlichen Stamm."
		if animal["handler_id"] != "" and animal["handler_id"] not in members:
			return "Tierauftrag verweist auf keinen Stammesbewohner."
		if not animal["pending"].is_empty() and animal["pending"]["actor_id"] not in members:
			return "Zähmversuch verweist auf keinen Stammesbewohner."
		var source: Variant = data["sources"].get(id)
		if not source is Dictionary or not source.get("identity") is Dictionary:
			return "Ungültige Herkunft des Tiers."
		for key in ["object_id", "species_id", "body_id"]:
			if source["identity"].get(key) != animal[key]: return "Tieridentität und Körperherkunft widersprechen sich."
		if not State.identity(source.get("name")) or not State.number(source.get("visual_scale"), 0.1, 2.0) or not State.number(source.get("maximum_health"), 1.0, 10000.0) or not State.number(source.get("speed"), 0.1, 20.0) or not State.number(source.get("fear_until"), 0, 1e15):
			return "Ungültiges Laufzeitprofil des Tiers."
		if not State.number(source.get("heading"), -1e6, 1e6) or not State.point(source.get("preview_offset")):
			return "Ungültiger Körperrahmen des Tiers."
		if not State.integer(source.get("species_seed"), 1, 9007199254740991) or not State.integer(source.get("individual_seed"), 0, 2147483647) or source.get("role") not in ["grazer", "forager", "climber", "predator", "scavenger", "swimmer"]:
			return "Ungültige Tierherkunft."
		var blueprint: Variant = source.get("blueprint")
		if not snapshot_value(blueprint) or not blueprint is Dictionary or not blueprint.get("species") is Dictionary or not blueprint.get("parts") is Array or not blueprint.get("body") is Dictionary:
			return "Ungültiger gespeicherter Körperentwurf."
		if blueprint.get("design_id") != animal["design_ref"]["id"]:
			return "Körperentwurfsreferenz stimmt nicht überein."
		var reference: Variant = source["identity"].get("design_ref")
		if not reference is Dictionary or reference.get("design_id") != animal["design_ref"]["id"] or reference.get("revision") != animal["design_ref"]["revision"]:
			return "Ursprünglicher Körperbezug wurde verändert."
		if blueprint["species"].get("id") != animal["species_id"]:
			return "Gespeicherter Körper gehört zu einer anderen Tierart."
		if not D1.validate(blueprint["species"].get("domestication")).is_empty():
			return "Tierkörper benötigt geprüfte D1-Eignung."
	return ""

static func unsupported(body: Dictionary) -> bool:
	if not body.get(FIELD) is Dictionary: return false
	var value: Dictionary = body[FIELD]
	if value.get("registry") is Dictionary and value.registry.get("schema") == State.SCHEMA and body.get("surface_mode") != State.Home.Cube.MODE: return true
	return not State.integer(value.get("schema"), 1, SCHEMA) or (value.get("registry") is Dictionary and not State.integer(value["registry"].get("schema"), 1, State.SCHEMA))

static func snapshot_value(value: Variant, depth: int = 0) -> bool:
	if depth > 32: return false
	if value is Dictionary:
		if value.has("$vector3"):
			return value.size() == 1 and State.point(value["$vector3"])
		for key in value:
			if not key is String or not snapshot_value(value[key], depth + 1): return false
		return true
	if value is Array:
		for item in value:
			if not snapshot_value(item, depth + 1): return false
		return true
	return value == null or value is String or value is bool or ((value is float or value is int) and is_finite(float(value)))
