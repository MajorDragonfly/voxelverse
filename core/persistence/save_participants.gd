extends RefCounted
## Fixed save participants. No runtime registration, writer, or second state owner.
## Body participants travel inside GameState's single campaign snapshot.
const Registry = preload("res://core/campaign/body_registry.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Progression = preload("res://autoload/progression_service.gd")
const Designs = preload("res://core/persistence/design_store.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Animals = preload("res://world/domestication/campaign_animal_state.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")
const Exploration = preload("res://core/map/exploration_atlas.gd")
const FaunaCatalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const VillageSimulation = preload("res://world/tribe/village_simulation.gd")
const Population = preload("res://world/surface/campaign_population_state.gd")
const RegionStore = preload("res://core/persistence/region_store.gd")
const Ecology = preload("res://world/surface/campaign_ecology_state.gd")
const LegacyPopulation = preload("res://world/fauna/legacy_population_state.gd")
const Foraging = preload("res://world/resources/plants/foraging_state.gd")
const Drinking = preload("res://creatures/ai/drinking_state.gd")
const Onboarding = preload("res://core/onboarding_progress.gd")

# Order also defines import order: designs, then GameState, then progression,
# then pending runtime state. Hosts are notified only by the central service.
const SECTIONS: Array = [
	{"id": "metadata", "fields": ["schema", "saved_unix_time", "slot_name", "migration_report", "slot_preview", "slot_origin"], "archive_fields": ["slot_history"], "schema": Registry.SAVE_SCHEMA},
	{"id": "designs", "fields": ["design_files"], "schema": 0},
	{"id": "onboarding", "fields": ["onboarding"], "schema": Onboarding.SCHEMA},
	{"id": "game_state", "fields": ["game_state"], "schema": Registry.STATE_SCHEMA},
	{"id": "progression", "fields": ["progression"], "schema": Progression.SAVE_SCHEMA},
	{"id": "regions", "fields": ["regions_by_body"], "legacy_fields": ["regions_by_world"], "schema": 0},
	{"id": "player", "fields": ["player"], "schema": 0},
]
const BODY_SECTIONS: Array = [
	{"id": "village_simulation", "schema": 1},
	{"id": "visit", "schema": 1},
	{"id": "home_group", "schema": Home.SCHEMA},
	{"id": "legacy_population", "schema": 1},
	{"id": "wildlife_foraging", "schema": Foraging.SCHEMA},
	{"id": "wildlife_drinking", "schema": Drinking.SCHEMA},
	{"id": "surface_ecology", "schema": 1},
	{"id": "fauna_catalog", "schema": FaunaCatalog.ROLE_SCHEMA},
	{"id": "surface_population", "schema": Population.PAGED_SCHEMA},
	{"id": Animals.FIELD, "schema": Animals.SCHEMA},
	{"id": "exploration_atlas", "schema": Exploration.SCHEMA},
	{"id": "legacy_exploration_atlas", "schema": Exploration.SCHEMA},
	{"id": "tribe", "schema": Tribe.SCHEMA},
	{"id": "tribal_neighbor", "schema": Neighbor.SCHEMA},
]

static func registration_problem(service: Node) -> String:
	var fields: Dictionary = {}
	for section: Dictionary in SECTIONS:
		for operation in ["snapshot", "restore"]:
			var method: String = "_" + operation + "_" + section.id
			if not service.has_method(method): return "Missing save participant hook: " + method
		for field in section.fields + section.get("legacy_fields", []) + section.get("archive_fields", []):
			if fields.has(field): return "Duplicate save participant field: " + str(field)
			fields[field] = section.id
	return ""

static func unknown_section(data: Dictionary) -> String:
	for field in data:
		var known: bool = false
		for section: Dictionary in SECTIONS:
			if field in section.fields or field in section.get("legacy_fields", []) or field in section.get("archive_fields", []):
				known = true
				break
		if not known: return str(field) if not str(field).is_empty() else "<empty>"
	return ""

static func snapshot(service: Node, files: Dictionary) -> Dictionary:
	var problem: String = registration_problem(service)
	if not problem.is_empty(): return {"ok": false, "error": problem}
	var result: Dictionary = {}
	for section: Dictionary in SECTIONS:
		var value: Dictionary = service.call("_snapshot_" + section.id, files)
		if value.size() != section.fields.size(): return {"ok": false, "error": "Incomplete snapshot participant: " + section.id}
		for field in section.fields:
			if not value.has(field): return {"ok": false, "error": "Missing snapshot field: " + str(field)}
		result.merge(value)
	return {"ok": true, "data": result, "error": ""}

static func restore(service: Node, data: Dictionary) -> void:
	# The service checks registration and validates/migrates before any import.
	for section: Dictionary in SECTIONS:
		service.call("_restore_" + section.id, data)

static func validate_sections(data: Dictionary) -> String:
	var unknown: String = unknown_section(data)
	if not unknown.is_empty(): return "Unregistered save section: " + unknown
	for field in ["game_state", "progression", "player"]:
		if not data.get(field) is Dictionary: return "Invalid save section: " + field
	for section: Dictionary in SECTIONS:
		var problem: String = _validate_section(section.id, data)
		if not problem.is_empty(): return problem
	return ""

static func _validate_section(id: String, data: Dictionary) -> String:
	var schema: int = int(data.get("schema", 0))
	match id:
		"progression":
			var problem: String = Progression.validate_state(data.progression)
			if not problem.is_empty(): return problem
			if schema >= 4 and int(data.progression.get("schema", 0)) < 3: return "Schema 4 requires complete behavior progression."
			if schema >= 5 and int(data.progression.get("schema", 0)) < 4: return "Schema 5 requires persistent creature encounters."
		"player":
			var runtime: Variant = data.player.get("behavior_runtime", {})
			if not runtime is Dictionary: return "Invalid player behavior state."
			for key in runtime:
				var value: Variant = runtime[key]
				if key not in ["stamina", "recovery_delay"] or not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > (100.0 if key == "stamina" else 0.8): return "Invalid player stamina state."
		"game_state":
			if int(data.game_state.get("world_seed", 0)) <= 0 or int(data.game_state.get("phase", -1)) not in range(6): return "Invalid world seed or phase."
		"regions":
			if not data.get(Registry.regions_field(data), {}) is Dictionary: return "Invalid region state."
			if schema >= Registry.SAVE_SCHEMA and (not data.has("regions_by_body") or data.has("regions_by_world")): return "Invalid body-scoped region storage."
		"designs":
			if schema < 3: return ""
			if not data.get("design_files") is Dictionary: return "Missing design snapshot."
			for path in data.design_files:
				if not Designs.is_managed(str(path)) or not data.design_files[path] is String: return "Invalid design snapshot path/content."
		"metadata", "onboarding":
			# Preserve optional metadata/onboarding defaults from supported old saves.
			pass
		_: return "Missing save participant validator: " + id
	return ""

static func unsupported_sections(data: Dictionary) -> bool:
	# An unowned field must never be discarded by an older backup or snapshot.
	if not unknown_section(data).is_empty(): return true
	for section: Dictionary in SECTIONS:
		match str(section.id):
			"progression":
				if Progression.has_unsupported_contract(data.get("progression", {})): return true
			"designs":
				if data.get("design_files") is Dictionary and Designs.has_unsupported_blueprints(data.design_files): return true
			"metadata", "game_state", "regions", "player", "onboarding":
				# Envelope versions stay central; onboarding preserves future UI data.
				pass
			_: return true
	return false

static func validate_body(body: Dictionary, campaign: Dictionary, tribal: Dictionary) -> String:
	var unknown: String = unknown_body_section(body)
	if not unknown.is_empty(): return "Unregistered body save section: " + unknown
	for section: Dictionary in BODY_SECTIONS:
		if not body.has(section.id): continue
		var problem: String = _validate_body_section(section.id, body, campaign, tribal)
		if not problem.is_empty(): return problem
	return ""

static func unknown_body_section(body: Dictionary) -> String:
	for field in body:
		# Surface context belongs to the central identity/location envelope. Other
		# versioned body extensions need their own registered contract guard.
		if field == "surface_context" or not body[field] is Dictionary or not body[field].has("schema"): continue
		var known: bool = false
		for section: Dictionary in BODY_SECTIONS:
			if field == section.id:
				known = true
				break
		if not known: return str(field) if not str(field).is_empty() else "<empty>"
	return ""

static func _validate_body_section(id: String, body: Dictionary, campaign: Dictionary, tribal: Dictionary) -> String:
	match id:
		"village_simulation": return VillageSimulation.validate(body[id], body, float(campaign.get("elapsed_seconds", 0)))
		"visit":
			var visit: Variant = body[id]
			if not visit is Dictionary or visit.get("schema") != 1 or not visit.get("player") is Dictionary or not Surface.number(visit.get("system_seed"), 1, 2147483647) or not Surface.number(visit.get("planet_index"), 0, 1000000): return "Invalid body visit checkpoint."
			if body.surface_mode != Surface.Cube.MODE or not Surface.player_problem(visit.player, body).is_empty(): return "Visit checkpoint refers to another surface."
		"home_group": return Home.validate(body[id], str(body.id), str(campaign.player_species_id))
		"legacy_population": return LegacyPopulation.validate(body[id], str(body.id))
		"wildlife_foraging": return Foraging.validate(body[id], str(body.id))
		"wildlife_drinking": return Drinking.validate(body[id], str(body.id))
		"surface_ecology":
			if body.surface_mode != Surface.Cube.MODE: return "Radiale Ökologie ohne Kugelkontext."
			return Ecology.validate(body[id], body)
		"fauna_catalog": return FaunaCatalog.validate(body[id], Surface.descriptor(body) if body.surface_mode == Surface.Cube.MODE else body)
		"surface_population":
			if body.surface_mode != Surface.Cube.MODE: return "Kugelbestand benötigt einen Kugelkontext."
			var problem: String = Population.validate(body[id], Surface.descriptor(body))
			if not problem.is_empty(): return problem
			if body[id].schema == 2:
				var storage := RegionStore.new()
				if not storage.open(body[id].storage): return storage.last_error
		Animals.FIELD: return Animals.validate_body(body, campaign)
		"exploration_atlas":
			var problem: String = Exploration.validate(body[id], str(body.get("id", "")))
			if not problem.is_empty(): return problem
			if body[id].mode != body.surface_mode: return "Map and body surface modes differ."
		"legacy_exploration_atlas":
			# Read-only migration archive: existing version guard, no normalization.
			pass
		"tribe": return Tribe.validate(body[id], body, campaign)
		"tribal_neighbor":
			if int(tribal.get("schema", 0)) < 3: return "Nachbarlager benötigt Stammesfortschrittformat 3."
			return Neighbor.validate(body[id], body.get("tribe", {}), campaign)
		_: return "Missing body participant validator: " + id
	return ""

static func unsupported_body(body: Dictionary) -> bool:
	if not unknown_body_section(body).is_empty(): return true
	for section: Dictionary in BODY_SECTIONS:
		if _unsupported_body_section(section.id, body): return true
	return false

static func _unsupported_body_section(id: String, body: Dictionary) -> bool:
	var value: Variant = body.get(id)
	match id:
		"village_simulation", "visit", "legacy_population", "wildlife_foraging", "wildlife_drinking", "surface_ecology":
			return value is Dictionary and value.get("schema") != 1
		"home_group":
			return value is Dictionary and ((value.get("schema") != 1 and value.get("schema") != Home.SCHEMA) or (value.get("schema") == Home.SCHEMA and value.get("surface_mode") != Home.Cube.MODE))
		"surface_population":
			if not value is Dictionary: return false
			if value.get("schema") != 1 and value.get("schema") != 2: return true
			if value.get("storage") is Dictionary and (value.storage.get("schema") != 1 or value.storage.get("format") != RegionStore.FORMAT): return true
			if value.get("schema") == 2 and value.get("storage") is Dictionary:
				var storage := RegionStore.new()
				storage.open(value.storage)
				if storage.unsupported: return true
		Animals.FIELD: return Animals.unsupported(body)
		"exploration_atlas", "legacy_exploration_atlas": return Exploration.newer(value)
		"tribal_neighbor": return Neighbor.has_unsupported_contract(value)
		"fauna_catalog": return body.has(id) and FaunaCatalog.has_unsupported(value)
		"tribe":
			return value is Dictionary and (Tribe.Economy.has_unsupported_contract(value.get("economy")) or int(value.get("schema", 0)) > Tribe.SCHEMA or (value.get("schema") == Tribe.SCHEMA and not value.get("anchor") is Dictionary))
		_: return true
	return false

static func migrate_bodies(campaign: Dictionary, report: Array[String]) -> void:
	# Other participants use their existing import/read adapters, or retain their
	# supported old representation. Never normalize during inspection/validation.
	for body: Dictionary in campaign.get("bodies", {}).values():
		for section: Dictionary in BODY_SECTIONS:
			if section.id == "tribe" and body.has("tribe") and Tribe.upgrade(body.tribe):
				report.append("Tribe -> %d; residents, orders, cargo, stock and economy retained. Existing huts and paid construction keep their sites; new shelters, residents and husbandry develop in play." % Tribe.SCHEMA)
