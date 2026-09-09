extends RefCounted
## Freeze provenance while a legacy representative still has its full body.
const Home = preload("res://world/home_group/home_group_state.gd")
const Values = preload("res://world/fauna/domestication/domestication_contract.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const LIMIT: int = 32768

static func capture(actor: Node3D) -> void:
	var state: Node = actor.get_node("/root/GameState")
	var body: Dictionary = state.get_current_body_record()
	if body.surface_mode != "legacy_plane_v9": return
	if not body.has("legacy_population"): body.legacy_population = {"schema": 1, "body_id": body.id, "animals": {}}
	var ledger: Dictionary = body.legacy_population
	if ledger.get("schema") != 1: return
	var identity: Dictionary = actor.get_campaign_identity()
	var id: String = identity.object_id
	if not ledger.animals.has(id) and ledger.animals.size() >= LIMIT: return
	ledger.animals[id] = {"id": id, "identity": identity.duplicate(true), "location": Home.vector_array(actor.global_position),
		"home": Home.vector_array(actor._anchor if actor._anchor_ready else actor.global_position),
		"species_seed": actor.species_seed, "individual_seed": actor.individual_seed, "role": actor.ecological_role,
		"blueprint": Values.encode(actor.blueprint)}

static func validate(value: Variant, body_id: String) -> String:
	if not value is Dictionary or value.get("schema") != 1 or value.get("body_id") != body_id or not value.get("animals") is Dictionary or value.animals.size() > LIMIT: return "Ungültiges Herkunftsinventar."
	for id in value.animals:
		var entry: Variant = value.animals[id]
		if not entry is Dictionary or entry.get("id") != id or not entry.get("identity") is Dictionary or entry.identity.get("object_id") != id or entry.identity.get("body_id") != body_id: return "Ungültige Individuenherkunft."
		if not Home.valid_position(entry.get("location")) or not Home.valid_position(entry.get("home")): return "Ungültiger Herkunftsort."
		if not Values.integer(entry.get("species_seed"), 1, 9007199254740991) or not Values.integer(entry.get("individual_seed"), 0, 2147483647) or not entry.get("blueprint") is Dictionary or not Catalog.snapshot_value(entry.blueprint): return "Ungültiger Herkunftskörper."
		if entry.get("role") not in ["grazer", "forager", "predator", "scavenger", "climber", "swimmer"]: return "Ungültige Herkunftsrolle."
	return ""
