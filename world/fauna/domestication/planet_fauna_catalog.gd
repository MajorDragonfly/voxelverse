extends RefCounted
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
const Generator = preload("res://world/fauna/domestication/domestic_species_generator.gd")
const BodyEvidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Recovery = preload("res://world/fauna/domestication/domestic_habitat_recovery.gd")
const Surface = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const REPLACEMENT_SECONDS: float = 300.0

static func eligible(body: Dictionary) -> bool:
	# Legacy campaign bodies predate kind/life flags and are inhabited planets.
	# New surface adapters must opt in explicitly, and supply their own habitats.
	return str(body.get("kind", "planet")) in ["planet", "moon"] and bool(body.get("inhabited", body.get("surface_mode") == "legacy_plane_v9")) and body.get("surface_mode") == "legacy_plane_v9"

static func ensure(state: Node) -> Dictionary:
	var body: Dictionary = state.get_current_body_record()
	if body.has("fauna_catalog"):
		var context: Dictionary = preload("res://core/campaign/surface_context.gd").descriptor(body) if body.get("surface_mode") == Surface.Cube.MODE else body
		return body["fauna_catalog"] if validate(body["fauna_catalog"], context).is_empty() else {}
	if not eligible(body):
		return {}
	var used: Dictionary = {}
	for entry in state.get_node("/root/ProgressionService").discovered_species.values():
		if entry.get("body_id") == body["id"]:
			used[int(entry.get("species_seed", 0))] = true
	for entry in state.get_node("/root/ProgressionService").export_state().get("creature_encounters", {}).get("entries", {}).values():
		if entry is Dictionary and entry.get("body_id") == body["id"] and entry.get("habitat") is Dictionary:
			used[int(entry["habitat"]["species_seed"])] = true
	var catalog: Dictionary = create(body, used)
	body["fauna_catalog"] = catalog
	state.get_node("/root/SaveGameService").schedule_autosave()
	return catalog

## Shared pure creation; callers must preserve an existing catalog verbatim.
static func create(body: Dictionary, used_seeds: Dictionary = {}) -> Dictionary:
	var used: Dictionary = used_seeds.duplicate()
	var catalog := {"schema": Contract.SCHEMA, "generator_version": Contract.GENERATOR_VERSION,
		"body_id": body["id"], "seed": body["seed"], "species": [], "habitats": [], "habitat_status": "pending"}
	for group in Contract.GROUPS:
		var seed_value: int = 4_000_000_000_000 + int((str(int(body["seed"])) + ":" + str(body["id"]) + ":" + Contract.GENERATOR_VERSION + ":" + group).sha256_text().left(10).hex_to_int())
		while used.has(seed_value):
			seed_value += 1
		used[seed_value] = true
		catalog["species"].append(Generator.create(body, group, seed_value))
	return catalog

static func create_surface(body: Dictionary, anchor: Dictionary, used_seeds: Dictionary = {}) -> Dictionary:
	if not Surface.eligible(body) or not Surface.location(anchor, str(body.id)): return {}
	var catalog: Dictionary = create(body, used_seeds)
	catalog.schema = Surface.SCHEMA
	catalog.surface = {"schema": 1, "mode": Surface.Cube.MODE, "generation": body.surface_generation,
		"radius": body.radius, "terrain_revision": body.terrain_revision, "anchor": Surface.canonical(anchor)}
	return catalog

static func species_for(catalog: Dictionary, species_id: String) -> Dictionary:
	for entry: Dictionary in catalog.get("species", []):
		if entry["id"] == species_id:
			return entry.duplicate(true)
	return {}

static func object_id(state: Node, habitat: Dictionary) -> String:
	return state.campaign.object_id(str(habitat["region_id"]), "habitat:" + cell_key(habitat))

static func cell_key(habitat: Dictionary) -> String:
	return "d1:" + str(habitat["key"]) + ":" + str(int(habitat["generation"]))

static func has_unsupported(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not Contract.integer(value.get("schema"), 1, Surface.MIGRATED_SCHEMA) or value.get("generator_version") != Contract.GENERATOR_VERSION:
		return true
	if value.get("schema", 0) >= Surface.SCHEMA and Surface.unsupported(value): return true
	if value.has("habitat_recovery") and Recovery.unsupported(value["habitat_recovery"]): return true
	if not value.get("species") is Array: return false
	for entry in value.get("species", []):
		if entry is Dictionary and BodyEvidence.unsupported(entry): return true
		if entry is Dictionary and entry.get("domestication") is Dictionary and not Contract.integer(entry["domestication"].get("schema"), 1, 1):
			return true
	return false

static func validate(value: Variant, body: Dictionary) -> String:
	if not value is Dictionary or has_unsupported(value):
		return "Unsupported fauna catalog version."
	if value.get("body_id") != body.get("id") or not Contract.integer(value.get("seed"), int(body.get("seed", -1)), int(body.get("seed", -1))):
		return "Fauna catalog belongs to another body."
	if not value.get("species") is Array or value["species"].size() != 3 or not value.get("habitats") is Array or value["habitats"].size() > 24:
		return "Invalid fauna catalog collections."
	var groups: Array = []
	var identities: Array = []
	for entry in value["species"]:
		if not entry is Dictionary or entry.get("group") not in Contract.GROUPS or entry.get("group") in groups or entry.get("id") in identities:
			return "Missing or duplicate mandatory species."
		if entry.get("body_id") != body["id"] or not Contract.integer(entry.get("species_seed"), 1, 9007199254740991) or entry.get("id") != Ids.scoped("species", body["id"], str(int(entry["species_seed"]))):
			return "Invalid domestic species identity."
		var problem: String = Contract.validate(entry.get("domestication"))
		if not problem.is_empty(): return problem
		if entry["domestication"]["roles"] != Contract.suitability(entry["group"])["roles"]:
			return "Mandatory group and roles disagree."
		if not snapshot_value(entry.get("blueprint")):
			return "Invalid domestic blueprint encoding."
		if not entry.get("blueprint") is Dictionary or not entry["blueprint"].get("species") is Dictionary or not entry["blueprint"].get("body") is Dictionary or not entry["blueprint"].get("parts") is Array:
			return "Missing frozen domestic body."
		if JSON.stringify(entry["blueprint"]["species"].get("domestication")) != JSON.stringify(entry["domestication"]) or entry["blueprint"]["species"].get("id") != entry["id"]:
			return "Domestic blueprint does not match species."
		if not Contract.number(entry.get("visual_scale"), 0.4, 1.2) or entry.get("role") not in ["grazer", "forager"]:
			return "Invalid domestic runtime profile."
		var legs: int = 0
		for part in entry["blueprint"]["parts"]:
			if not part is Dictionary: return "Invalid domestic body part."
			if part.get("category") == "legs" and part.get("end_part_id") in ["feet_pads", "feet_hooves"]:
				legs += 2 if part.get("mirrored", false) else 1
		if legs < 4: return "Domestic species lacks support feet."
		problem = BodyEvidence.validate(entry)
		if not problem.is_empty(): return problem
		groups.append(entry["group"])
		identities.append(entry["id"])
	if value["schema"] >= Surface.SCHEMA:
		if value["schema"] == Surface.MIGRATED_SCHEMA:
			var archive: Variant = value.get("migration_source")
			if not archive is Dictionary or archive.get("schema") != 1 or not archive.get("catalog") is Dictionary or archive.catalog.get("schema") != 1 or archive.catalog.has("migration_source"): return "Invalid migrated catalog archive."
			var old_body: Dictionary = {"id": body.id, "seed": body.seed, "surface_mode": "legacy_plane_v9"}
			var original_problem: String = validate(archive.catalog, old_body)
			if not original_problem.is_empty(): return original_problem
			for entry: Dictionary in value.species:
				var old_entry: Dictionary = species_for(archive.catalog, entry.id)
				if old_entry.is_empty() or BodyEvidence.fingerprint(entry) != BodyEvidence.fingerprint(old_entry): return "Migrated species body was replaced."
		return Surface.validate(value, body, identities)
	var keys: Array = []
	var represented: Array = []
	for habitat in value["habitats"]:
		if not habitat is Dictionary or habitat.get("species_id") not in identities or not habitat.get("key") is String or habitat["key"].is_empty() or habitat["key"] in keys:
			return "Invalid domestic habitat identity."
		if habitat.get("travel_mode") not in ["walk", "swim_walk"] or habitat.get("food") != "plant" or habitat.get("water_supply") not in ["nearby_freshwater", "requires_transport"] or not Contract.number(habitat.get("freshwater_distance"), -1, 1e9):
			return "Invalid domestic habitat resources."
		if not vector(habitat.get("position")) or not habitat.get("path") is Array or habitat["path"].size() < 2 or habitat["path"].size() > 4096:
			return "Missing reachable domestic habitat."
		for point in habitat["path"]:
			if not vector(point): return "Invalid domestic route."
		if habitat.has("spawn_position") and not vector(habitat["spawn_position"]): return "Invalid domestic spawn position."
		var p: Array = habitat["position"]
		var region: Vector2i = Vector2i(floori(float(p[0]) / 256.0), floori(float(p[2]) / 256.0))
		if habitat.get("region_id") != Ids.scoped("region", body["id"], "legacy:%d:%d" % [region.x, region.y]) or not Contract.integer(habitat.get("generation"), 0, 1000000000) or not Contract.number(habitat.get("replacement_at"), 0, 1e15):
			return "Invalid domestic habitat lifecycle."
		keys.append(habitat["key"])
		if habitat["species_id"] not in represented: represented.append(habitat["species_id"])
	if value.get("habitat_status") not in ["pending", "ready", "unavailable"] or (value["habitat_status"] == "ready" and represented.size() != 3):
		return "Mandatory habitats are incomplete."
	if value.has("habitat_recovery"):
		return Recovery.validate(value["habitat_recovery"], value)
	return ""

static func vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and Contract.number(value[0], -1e9, 1e9) and Contract.number(value[1], -1e6, 1e6) and Contract.number(value[2], -1e9, 1e9)

static func snapshot_value(value: Variant, depth: int = 0) -> bool:
	if depth > 24: return false
	if value is Dictionary:
		if value.has("$vector3"):
			return value.size() == 1 and vector(value["$vector3"])
		for key in value:
			if not key is String or not snapshot_value(value[key], depth + 1): return false
		return true
	if value is Array:
		for item in value:
			if not snapshot_value(item, depth + 1): return false
		return true
	return value is String or value is bool or value == null or Contract.number(value, -9007199254740991.0, 9007199254740991.0)
