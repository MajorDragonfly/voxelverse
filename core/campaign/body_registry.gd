extends RefCounted
## Stable identities own state; generator seeds are only scoped lookup inputs.
## This adapter is pure: reads never create bodies or import a campaign.
const Ids = preload("res://core/campaign/campaign_ids.gd")
const CAMPAIGN_SCHEMA: int = 3
const STATE_SCHEMA: int = 4
const SAVE_SCHEMA: int = 9

static func context_key(system_id: String, seed_value: int) -> String:
	return JSON.stringify([system_id, seed_value])

static func system_identity(campaign_id: String, system_seed: int) -> String:
	return Ids.scoped("system", campaign_id, str(system_seed))

static func by_id(campaign: Dictionary, body_id: String) -> Dictionary:
	if body_id.is_empty(): return {}
	var bodies: Dictionary = campaign.get("bodies", {})
	if int(campaign.get("schema", 0)) >= CAMPAIGN_SCHEMA:
		var body: Dictionary = bodies.get(body_id, {})
		return body if body.get("id") == body_id else {}
	var found: Dictionary = {}
	for body: Dictionary in bodies.values():
		if body.get("id") != body_id: continue
		if not found.is_empty(): return {}
		found = body
	return found

static func by_seed(campaign: Dictionary, seed_value: int, system_id: String) -> Dictionary:
	if system_id.is_empty(): return {}
	if int(campaign.get("schema", 0)) >= CAMPAIGN_SCHEMA:
		var id: String = campaign.get("body_lookup", {}).get(context_key(system_id, seed_value), "")
		var body: Dictionary = by_id(campaign, id)
		return body if body.get("system_id") == system_id and body.get("seed") == seed_value else {}
	var found: Dictionary = {}
	for body: Dictionary in campaign.get("bodies", {}).values():
		if body.get("system_id") != system_id or body.get("seed") != seed_value: continue
		if not found.is_empty(): return {}
		found = body
	return found

static func active(state: Dictionary) -> Dictionary:
	var campaign: Dictionary = state.get("campaign", {})
	var system_id: String = str(state.get("system_id", system_identity(str(campaign.get("id", "")), int(state.get("system_seed", state.get("world_seed", 0))))))
	var body: Dictionary = by_id(campaign, str(state.get("body_id", ""))) if state.has("body_id") else by_seed(campaign, int(state.get("world_seed", 0)), system_id)
	# Old slot copies preserve opaque body/system IDs while changing campaign ID.
	# Their explicit body reference is authoritative; never rederive those IDs.
	if int(state.get("schema", 0)) < STATE_SCHEMA and state.has("body_id") and not state.has("system_id"):
		system_id = str(body.get("system_id", ""))
	return body if body.get("seed") == state.get("world_seed") and body.get("system_id") == system_id else {}

static func validate(campaign: Dictionary) -> String:
	if campaign.get("schema") != 1 and campaign.get("schema") != 2 and campaign.get("schema") != CAMPAIGN_SCHEMA: return "Unbekannte Version des Körperregisters."
	if not campaign.get("bodies") is Dictionary: return "Körperregister fehlt."
	var identities: Dictionary = {}
	var lookup: Dictionary = {}
	for key in campaign.bodies:
		var body: Variant = campaign.bodies[key]
		if not body is Dictionary or not body.get("id") is String or body.id.is_empty() or not body.get("system_id") is String or body.system_id.is_empty(): return "Ungültige Körper- oder Systemidentität."
		var seed_value: Variant = body.get("seed")
		if not (seed_value is int or seed_value is float) or not is_finite(float(seed_value)) or float(seed_value) != floor(float(seed_value)) or seed_value < 1 or seed_value > 2147483647: return "Ungültiger Generatorseed im Körperregister."
		if identities.has(body.id): return "Mehrdeutige alte Körper-ID; Quelle bleibt geschützt."
		var address: String = context_key(body.system_id, int(seed_value))
		if lookup.has(address): return "Mehrdeutige Körperzuordnung innerhalb desselben Systems."
		if key != (body.id if campaign.schema == CAMPAIGN_SCHEMA else str(int(seed_value))): return "Körperschlüssel stimmt nicht mit der gespeicherten Version überein."
		identities[body.id] = true
		lookup[address] = body.id
	if campaign.schema == CAMPAIGN_SCHEMA and (not campaign.get("body_lookup") is Dictionary or campaign.body_lookup != lookup): return "Körperindex stimmt nicht mit seinen Identitäten überein."
	return ""

static func ambiguous(campaign: Dictionary) -> bool:
	if not campaign.get("bodies") is Dictionary: return false
	var ids: Dictionary = {}
	var contexts: Dictionary = {}
	for record in campaign.bodies.values():
		if not record is Dictionary: continue
		var id: String = str(record.get("id", ""))
		var context: String = context_key(str(record.get("system_id", "")), int(record.get("seed", 0)))
		if not id.is_empty() and (ids.has(id) or contexts.has(context)): return true
		ids[id] = true
		contexts[context] = true
	return false

static func upgrade_campaign(source: Dictionary) -> Dictionary:
	var problem: String = validate(source)
	if not problem.is_empty(): return {"ok": false, "error": problem}
	var result: Dictionary = source.duplicate(true)
	result.schema = CAMPAIGN_SCHEMA
	result.bodies = {}
	result.body_lookup = {}
	for body: Dictionary in source.bodies.values():
		result.bodies[body.id] = body.duplicate(true)
		result.body_lookup[context_key(body.system_id, int(body.seed))] = body.id
	if not result.has("surface_policy"): result.surface_policy = "legacy_plane_v9"
	if not result.has("surface_migration"): result.surface_migration = {}
	return {"ok": true, "data": result, "error": ""}

static func regions_field(save: Dictionary) -> String:
	return "regions_by_body" if int(save.get("schema", 0)) >= SAVE_SCHEMA else "regions_by_world"

static func upgrade_save(source: Dictionary) -> Dictionary:
	# The caller validates all module contracts and archives the source before
	# committing. Unknown/ambiguous identity data never falls back to guessing.
	var converted: Dictionary = upgrade_campaign(source.get("game_state", {}).get("campaign", {}))
	if not converted.ok: return converted
	var old_state: Dictionary = source.game_state
	var body: Dictionary = active(old_state)
	if body.is_empty(): return {"ok": false, "error": "Aktiver Körper ist nicht eindeutig dem gespeicherten System zugeordnet."}
	var records: Variant = source.get(regions_field(source), {})
	if not records is Dictionary: return {"ok": false, "error": "Ungültiger regionaler Speicher."}
	var regions: Dictionary = {}
	for key in records:
		var record: Variant = records[key]
		if not record is Dictionary: return {"ok": false, "error": "Ungültiger regionaler Datensatz."}
		var owner: Dictionary = by_id(converted.data, str(key)) if int(source.schema) >= SAVE_SCHEMA else by_id(converted.data, str(record.get("body_id", "")))
		if owner.is_empty() and int(source.schema) < SAVE_SCHEMA:
			for candidate: Dictionary in converted.data.bodies.values():
				if str(int(candidate.seed)) != str(key): continue
				if not owner.is_empty(): return {"ok": false, "error": "Alte Regionen mit gleichem Weltseed sind keinem eindeutigen Körper zugeordnet."}
				owner = candidate
		if owner.is_empty() or regions.has(owner.id) or (record.has("body_id") and record.body_id != owner.id) or (record.has("world_seed") and record.world_seed != owner.seed): return {"ok": false, "error": "Regionen besitzen eine widersprüchliche Körperzuordnung."}
		if int(source.schema) < SAVE_SCHEMA and str(int(owner.seed)) != str(key): return {"ok": false, "error": "Alter Regionsschlüssel widerspricht seinem Körper."}
		regions[owner.id] = record.duplicate(true)
	var result: Dictionary = source.duplicate(true)
	result.schema = SAVE_SCHEMA
	result.game_state.schema = STATE_SCHEMA
	result.game_state.campaign = converted.data
	result.game_state.body_id = body.id
	result.game_state.system_id = body.system_id
	result.regions_by_body = regions
	result.erase("regions_by_world")
	return {"ok": true, "data": result, "error": ""}
