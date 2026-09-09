extends Node

signal part_unlocked(part_id: String, reason: String)
signal species_discovered(species_key: String, species_name: String)
signal region_discovered(region_key: String)
signal discovery_points_changed(points: int)
signal behavior_changed
signal behavior_rewarded(receipt: Dictionary)
signal behavior_node_purchased(node_id: String)
signal research_changed

const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")
const DiscoveryRecords = preload("res://core/discovery/discovery_records.gd")
const DiscoveryPlanetCatalog = preload("res://world/generation/planet_catalog_v7.gd")
const Research = preload("res://core/discovery/research_goals.gd")

const GameEvent = preload("res://core/campaign/game_event.gd")
const Behavior = preload("res://core/progression/behavior_progression.gd")
const BehaviorRules = preload("res://core/progression/behavior_catalog.gd")
const Encounters = preload("res://core/progression/creature_encounters.gd")

const Tribal = preload("res://core/progression/tribal_progression.gd")
const Civilization = preload("res://core/progression/civilization_contract.gd")
const SAVE_SCHEMA: int = 6
const SPECIES_DISCOVERY_POINTS: int = 3
const REGION_DISCOVERY_POINTS: int = 1

var discovery_points: int = 0
var unlocked_parts: Dictionary = {}
var discovered_species: Dictionary = {}
var discovered_regions: Dictionary = {}
var _behavior := Behavior.new()
var _tribal := Tribal.new()
var _last_tribal_tick: int = -1
var _behavior_purchase_active: bool = false
var _encounters := Encounters.new()
var _encounter_commit_active: bool = false
var _research: Dictionary = Research.defaults()
var _research_change_active: bool = false


func _ready() -> void:
	_ensure_starter_parts()


func reset_for_new_game() -> void:
	discovery_points = 0
	unlocked_parts.clear()
	discovered_species.clear()
	discovered_regions.clear()
	_behavior.reset()
	_tribal.reset()
	_encounters.entries.clear()
	_research = Research.defaults()
	_ensure_starter_parts()
	discovery_points_changed.emit(discovery_points)
	behavior_changed.emit()
	research_changed.emit()


func is_part_unlocked(part_id: String) -> bool:
	if part_id.is_empty():
		return false
	return unlocked_parts.has(part_id)


func unlock_part(part_id: String, reason: String = "Discovery") -> bool:
	if part_id.is_empty() or PartLibrary.get_part(part_id).is_empty():
		return false
	if unlocked_parts.has(part_id):
		return false
	unlocked_parts[part_id] = {
		"reason": reason,
		"order": unlocked_parts.size(),
	}
	part_unlocked.emit(part_id, reason)
	return true


func get_unlocked_part_ids() -> Array[String]:
	var result: Array[String] = []
	for key in unlocked_parts.keys():
		result.append(str(key))
	result.sort()
	return result


func get_unlocked_count() -> int:
	return unlocked_parts.size()


func merge_unlocked_parts(part_ids: Array) -> void:
	for value in part_ids:
		unlock_part(str(value), "Migrated creature save")
	_ensure_starter_parts()


func register_species_discovery(
	species_seed: int,
	blueprint: Dictionary,
	world_seed: int = 0
) -> Dictionary:
	if world_seed <= 0:
		world_seed = _get_world_seed()
	var species_key: String = species_discovery_key(species_seed, world_seed)
	if species_key.is_empty(): return {"is_new": false, "species_key": "", "points_awarded": 0, "unlocked_part": ""}
	if discovered_species.has(species_key):
		_record_journal_observation(discovered_species[species_key], blueprint, world_seed)
		return {
			"is_new": false,
			"species_key": species_key,
			"unlocked_part": "",
			"points_awarded": 0,
		}

	var species_data: Dictionary = blueprint.get("species", {})
	var species_name: String = str(
		species_data.get("display_name", blueprint.get("name", "Unknown Species"))
	)
	discovered_species[species_key] = {
		"species_seed": species_seed,
		"world_seed": world_seed,
		"name": species_name,
		"role": str(species_data.get("ecological_role", "unknown")),
		"scan": {"version": 1, "complete": false},
	}
	_annotate_discovery(discovered_species[species_key], false)
	_record_journal_observation(discovered_species[species_key], blueprint, world_seed)
	_emit_discovery_event(str(discovered_species[species_key].get("id", species_key)))
	_add_discovery_points(SPECIES_DISCOVERY_POINTS)
	var unlocked_part: String = _unlock_species_part(species_seed, blueprint)
	if not unlocked_part.is_empty():
		unlocked_parts[unlocked_part]["species_key"] = species_key
		discovered_species[species_key]["unlocked_part"] = unlocked_part
	species_discovered.emit(species_key, species_name)
	return {
		"is_new": true,
		"species_key": species_key,
		"species_name": species_name,
		"unlocked_part": unlocked_part,
		"points_awarded": SPECIES_DISCOVERY_POINTS,
	}


func has_species_scan(species_seed: int, world_seed: int = 0) -> bool:
	if world_seed <= 0:
		world_seed = _get_world_seed()
	var entry: Dictionary = _as_dictionary(discovered_species.get(species_discovery_key(species_seed, world_seed), {}))
	var scan: Dictionary = _as_dictionary(entry.get("scan", {}))
	return int(scan.get("version", 0)) == 1 and bool(scan.get("complete", false))


func register_species_scan(species_seed: int, blueprint: Dictionary, world_seed: int = 0) -> Dictionary:
	if species_seed <= 0 or blueprint.is_empty():
		return {}
	if world_seed <= 0:
		world_seed = _get_world_seed()
	var result: Dictionary = register_species_discovery(species_seed, blueprint, world_seed)
	if str(result.get("species_key", "")).is_empty(): return {}
	var entry: Dictionary = discovered_species[result.species_key]
	if not has_species_scan(species_seed, world_seed):
		entry["scan"] = {"version": 1, "complete": true}
		var saves := get_node_or_null("/root/SaveGameService")
		if saves != null:
			saves.schedule_autosave(0.2)
	return result


func register_region_discovery(
	coordinates: Vector2i,
	world_seed: int = 0
) -> bool:
	if world_seed <= 0:
		world_seed = _get_world_seed()
	var body: Dictionary = _discovery_body(world_seed)
	if body.is_empty(): return false
	var region_key: String = get_node("/root/GameState").campaign.region_id(body.id, coordinates)
	var legacy_key: String = "%d:%d:%d" % [world_seed, coordinates.x, coordinates.y]
	if discovered_regions.get(legacy_key, {}).get("body_id") == body.id: region_key = legacy_key
	if discovered_regions.has(region_key):
		return false
	discovered_regions[region_key] = {
		"world_seed": world_seed,
		"x": coordinates.x,
		"z": coordinates.y,
	}
	_annotate_discovery(discovered_regions[region_key], true)
	_emit_discovery_event(str(discovered_regions[region_key].get("id", region_key)))
	_add_discovery_points(REGION_DISCOVERY_POINTS)
	region_discovered.emit(region_key)
	return true


func export_state() -> Dictionary:
	return {
		"schema": SAVE_SCHEMA,
		"discovery_points": discovery_points,
		"unlocked_parts": unlocked_parts.duplicate(true),
		"discovered_species": discovered_species.duplicate(true),
		"discovered_regions": discovered_regions.duplicate(true),
		"behavior": _behavior.export_state(),
		"tribal": _tribal.export_state(),
		"creature_encounters": _encounters.export_state(),
		"research": _research.duplicate(true),
	}


func import_state(data: Dictionary) -> bool:
	if not validate_state(data).is_empty():
		return false
	var imported_species: Dictionary = _as_dictionary(data.get("discovered_species", {}))
	var imported_regions: Dictionary = _as_dictionary(data.get("discovered_regions", {}))
	for entry: Dictionary in imported_species.values():
		if not _annotate_discovery(entry, false): return false
		if not entry.has("scan"): entry.scan = {"version": 1, "complete": true, "legacy": true}
	for entry: Dictionary in imported_regions.values():
		if not _annotate_discovery(entry, true): return false
	_tribal.import_state(data.get("tribal", Tribal.defaults()))
	_encounters.entries.clear()
	if data.has("creature_encounters"):
		_encounters.import_state(data["creature_encounters"])
	if data.has("behavior"):
		_behavior.import_state(data["behavior"])
	else:
		# Discovery-only saves migrate without inventing past behavior rewards.
		_behavior.reset()
	discovery_points = maxi(int(data.get("discovery_points", 0)), 0)
	unlocked_parts = _as_dictionary(data.get("unlocked_parts", {}))
	discovered_species = imported_species
	discovered_regions = imported_regions
	_research = _as_dictionary(data.get("research", Research.defaults()))
	_research["version"] = Research.VERSION
	# Retain unlock IDs for unavailable parts so restored content is not lost.
	_ensure_starter_parts()
	discovery_points_changed.emit(discovery_points)
	behavior_changed.emit()
	research_changed.emit()
	return true


static func validate_state(data: Dictionary) -> String:
	if not BehaviorRules.is_integer(data.get("schema", 1), 1, SAVE_SCHEMA):
		return "Unsupported progression schema."
	if data.has("tribal"):
		var problem: String = Tribal.validate(data["tribal"])
		if not problem.is_empty():
			return problem
	elif int(data.get("schema", 1)) >= 5:
		return "Missing tribal progression."
	if data.has("research"):
		var problem: String = Research.validate(data["research"])
		if not problem.is_empty():
			return problem
	if data.has("behavior"):
		var problem: String = Behavior.validate_state(data["behavior"])
		if not problem.is_empty():
			return problem
	elif int(data.get("schema", 1)) >= 3:
		return "Missing behavior progression."
	if data.has("creature_encounters"):
		return Encounters.validate_state(data["creature_encounters"])
	if int(data.get("schema", 1)) >= 4:
		return "Missing creature encounters."
	return ""


static func has_unsupported_contract(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return Tribal.has_unsupported_contract(data.get("tribal", {})) or BehaviorRules.is_newer_version(data.get("schema", 1), SAVE_SCHEMA) or Behavior.has_unsupported_contract(data.get("behavior", {})) or Encounters.has_unsupported_contract(data.get("creature_encounters", {})) or Research.has_unsupported_contract(data.get("research", {}))


func get_research_settings() -> Dictionary:
	return _research.duplicate(true)


func get_pinned_research() -> Dictionary:
	return Research.pinned({"discovered_species": discovered_species, "discovered_regions": discovered_regions,
		"unlocked_parts": unlocked_parts}, _research)


func set_research_pin(id: String) -> Dictionary:
	if not id.is_empty() and not Research.is_goal(id):
		if not id.begins_with("part:") or not _research["wished_parts"].has(id.trim_prefix("part:")):
			return {"ok": false, "reason": "invalid_goal"}
	var next: Dictionary = _research.duplicate(true)
	next["pinned"] = id
	return _commit_research(next)


func set_part_wished(part_id: String, wished: bool) -> Dictionary:
	var next: Dictionary = _research.duplicate(true)
	var wishes: Array = next["wished_parts"]
	if wished and not wishes.has(part_id):
		if PartLibrary.get_part(part_id).is_empty() or is_part_unlocked(part_id):
			return {"ok": false, "reason": "part_unavailable"}
		if wishes.size() >= Research.MAX_WISHES:
			return {"ok": false, "reason": "wishlist_full"}
		wishes.append(part_id)
	elif not wished:
		wishes.erase(part_id)
		if next["pinned"] == "part:" + part_id:
			next["pinned"] = ""
	return _commit_research(next)


func _commit_research(next: Dictionary) -> Dictionary:
	if is_behavior_transaction_active():
		return {"ok": false, "reason": "save_in_progress"}
	if next == _research:
		return {"ok": true, "changed": false}
	var saves := get_node_or_null("/root/SaveGameService")
	if saves == null:
		return {"ok": false, "reason": "save_failed"}
	var before: Dictionary = _research
	_research_change_active = true
	_research = next
	var saved: bool = bool(saves.call("save_now"))
	if not saved:
		_research = before
	_research_change_active = false
	if not saved:
		return {"ok": false, "reason": "save_failed"}
	research_changed.emit()
	return {"ok": true, "changed": true}


func apply_campaign_event(event: GameEvent) -> Dictionary:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return {"ok": false, "reason": "missing_campaign"}
	var campaign = state.get("campaign")
	var recent: Array = campaign.data["recent_events"]
	if recent.is_empty() or recent.back() != event.to_dict():
		return {"ok": false, "reason": "event_not_accepted"}
	var receipt: Dictionary = _behavior.apply_event(event, campaign.data["id"],
		campaign.data["player_object_id"], int(state.get("current_phase")))
	if receipt["ok"]:
		# Both the campaign cursor and the complete reward ledger are now updated.
		var saves := get_node_or_null("/root/SaveGameService")
		if saves != null:
			saves.call("schedule_autosave")
		behavior_changed.emit()
		behavior_rewarded.emit(receipt.duplicate(true))
	return receipt


func get_behavior_wallet(phase: int) -> Dictionary:
	return _tribal.wallet() if phase == 1 else _behavior.wallet(phase)


func get_behavior_nodes(phase: int) -> Array[Dictionary]:
	var state := get_node_or_null("/root/GameState")
	var current: int = int(state.get("current_phase")) if state != null else 0
	return _tribal.nodes(current) if phase == 1 else _behavior.nodes_for_phase(phase, current)


func get_behavior_effect(effect_id: String, phase: int, body_value: float = 1.0, technology_bonus: float = 0.0) -> Dictionary:
	var result: Dictionary = _behavior.calculate_effect(effect_id, phase, body_value, technology_bonus)
	var bonus: float = _tribal.effect_bonus(effect_id, phase)
	if result.get("ok", false) and bonus > 0.0:
		result["unclamped_value"] += bonus
		result["value"] = clampf(float(result["unclamped_value"]), 0.5, 2.0)
		result["contributions"].append({"node_id": "tribe.social", "amount": bonus, "legacy": false})
	return result


func get_phase_progression_preview(phase: int) -> Dictionary:
	var result: Dictionary = preload("res://core/progression/phase_progression_plan.gd").phase(phase)
	if result.is_empty():
		return result
	result["wallet"] = get_behavior_wallet(phase)
	result["legacy"] = {}
	for effect_id in ["group_cooperation", "group_defense"]:
		result["legacy"][effect_id] = get_behavior_effect(effect_id, phase)
	return result


func get_development_path() -> Dictionary:
	var state := get_node("/root/GameState")
	# The existing body record is read directly: opening this view must not create
	# campaign bodies, home groups, members, point entries or transition snapshots.
	var controller := get_tree().get_first_node_in_group(&"home_group_controller")
	var runtime_available: bool = controller != null and controller.has_method("can_use_panel") and bool(controller.call("can_use_panel"))
	var result: Dictionary = preload("res://core/progression/development_path.gd").describe(
		state.campaign.data, str(state.active_body_id), int(state.current_phase), runtime_available)
	result["legacy"] = get_phase_progression_preview(1)["legacy"]
	var tribe := get_tree().get_first_node_in_group(&"tribe_controller")
	if tribe != null:
		var blockers: Array = tribe.blockers() if int(state.current_phase) == 0 else []
		result["transition"] = {"implemented": true, "available": int(state.current_phase) == 0 and blockers.is_empty(),
			"message": "Dein Stamm ist aktiv. Du führst die Gruppe und baust euer Dorf." if int(state.current_phase) == 1 else str(blockers[0]) if not blockers.is_empty() else "Deine Gruppe ist bereit. Öffne in der Welt Stammeszeitalter … und bestätige dort den Wechsel. Sichere Arbeitsplätze werden vor der Bestätigung geprüft."}
		result["stages"][2]["status"] = "Aktuelle Phase" if int(state.current_phase) == 1 else "Spielbarer Einstieg · bewusster Wechsel"
	result["tribal_goals"] = _tribal.goals()
	result["tribal_wallet"] = _tribal.wallet()
	result["epochs"] = []
	for target: int in [2, 3]:
		result["epochs"].append(Civilization.describe(state.campaign.data, str(state.active_body_id), int(state.current_phase), target, get_tribal_economy_progress()))
	result["factions"] = "Unter Dorf → Nachbarn findest du eine Fraktion deiner Spezies mit eigenem Lager. Gemeinsame Hilfslieferungen verbessern eure Beziehung. Fremde Wildarten bleiben Tiere; Zähmung macht sie nicht zu Bürgern."
	return result


## Called only by the live village controller around an arrived resident's work.
## Update synchronously before any autosave/observer; both states share a snapshot.
func record_tribal_work(before: Dictionary, actor_id: String, producer: Node) -> void:
	var state := get_node("/root/GameState")
	var controller := get_tree().get_first_node_in_group(&"tribe_controller")
	if controller == null or producer != controller or int(state.current_phase) != 1 or not controller.is_active() or is_behavior_transaction_active():
		return
	var result: Dictionary = _tribal.observe(before, controller.village(), actor_id, controller.body(), state.campaign.data, int(state.current_phase))
	_publish_tribal_result(result)


func record_tribal_tick(delta: float, producer: Node) -> void:
	var state := get_node("/root/GameState")
	var controller := get_tree().get_first_node_in_group(&"tribe_controller")
	var frame: int = Engine.get_physics_frames()
	if producer != controller or controller == null or not controller.is_active() or is_behavior_transaction_active() or frame == _last_tribal_tick:
		return
	_last_tribal_tick = frame
	var result: Dictionary = _tribal.observe_supply(controller.village(), controller.body(), state.campaign.data, int(state.current_phase), delta)
	# Regular snapshots already include the live clock. Rescheduling each frame
	# would keep postponing the autosave forever while the village is healthy.
	if not result["rewards"].is_empty():
		_publish_tribal_result(result)

func record_far_work(before: Dictionary, actor_id: String, body: Dictionary, delta: float, producer: Node) -> void:
	var state: Node = get_node("/root/GameState")
	if producer != state or state.active_body_id == body.get("id") or body.get("village_simulation", {}).get("owner") != "far" or is_behavior_transaction_active(): return
	if actor_id == body.get("tribal_neighbor", {}).get("id"):
		_publish_tribal_result(_tribal.observe_neighbor(before, body.tribal_neighbor, body.tribe, state.campaign.data, int(state.current_phase)))
		return
	var result: Dictionary = _tribal.observe_supply(body.tribe, body, state.campaign.data, int(state.current_phase), delta) if actor_id.is_empty() else _tribal.observe(before, body.tribe, actor_id, body, state.campaign.data, int(state.current_phase))
	# Supply clocks are already saved by the normal checkpoint cadence.
	# Rescheduling them every far slice would postpone autosave indefinitely.
	if not actor_id.is_empty() or not result.rewards.is_empty(): _publish_tribal_result(result)


func get_tribal_economy_progress() -> Dictionary:
	var state := get_node("/root/GameState")
	var village: Dictionary = state.get_current_body_record().get("tribe", {})
	return _tribal.economy_progress(village)

func record_neighbor_help(before: Dictionary, producer: Node) -> void:
	var state := get_node("/root/GameState")
	var controller := get_tree().get_first_node_in_group(&"tribe_controller")
	if controller == null or controller != producer or not controller.is_active() or is_behavior_transaction_active():
		return
	_publish_tribal_result(_tribal.observe_neighbor(before, controller.body().get("tribal_neighbor", {}), controller.village(), state.campaign.data, int(state.current_phase)))


func _publish_tribal_result(result: Dictionary) -> void:
	if not result["changed"]:
		return
	get_node("/root/SaveGameService").schedule_autosave(1.0)
	if not result["rewards"].is_empty():
		behavior_changed.emit()
		for receipt: Dictionary in result["rewards"]:
			behavior_rewarded.emit(receipt.duplicate(true))


func purchase_behavior_node(node_id: String) -> Dictionary:
	if is_behavior_transaction_active() or _research_change_active:
		return {"ok": false, "reason": "purchase_in_progress"}
	var state := get_node_or_null("/root/GameState")
	var saves := get_node_or_null("/root/SaveGameService")
	if state == null or saves == null:
		return {"ok": false, "reason": "missing_campaign_services"}
	var model: RefCounted = _tribal if Tribal.NODES.has(node_id) else _behavior
	var before: Dictionary = model.export_state()
	var result: Dictionary = model.purchase(node_id, int(state.get("current_phase")))
	if not result["ok"]:
		return result
	_behavior_purchase_active = true
	var saved: bool = bool(saves.call("save_now"))
	if not saved:
		model.import_state(before)
	_behavior_purchase_active = false
	if not saved:
		return {"ok": false, "reason": "save_failed"}
	behavior_changed.emit()
	behavior_node_purchased.emit(node_id)
	return result


func is_behavior_transaction_active() -> bool:
	return _behavior_purchase_active or _encounter_commit_active or _research_change_active


func get_creature_encounter(identity: Dictionary, role: String, individual_seed: int) -> Dictionary:
	var saved: Dictionary = get_saved_creature_encounter(str(identity.get("object_id", "")))
	if not saved.is_empty(): return saved
	return _encounters.get_entry(identity, role, individual_seed)


func get_saved_creature_encounter(object_id: String) -> Dictionary:
	var population: Node = get_tree().get_first_node_in_group(&"campaign_surface_population")
	if population != null:
		var entry: Dictionary = population.saved_encounter(object_id)
		if not entry.is_empty(): return entry
	return _encounters.entries.get(object_id, {}).duplicate(true)

func _put_encounter(entry: Dictionary) -> bool:
	if not Encounters.validate_entry(entry).is_empty(): return false
	var population: Node = get_tree().get_first_node_in_group(&"campaign_surface_population")
	if population != null and not population.storage.record(str(entry.object_id)).is_empty(): return population.store_encounter(str(entry.object_id), entry)
	return _encounters.put(entry)


## Phase-1 compatibility for the existing fauna lifecycle. Health only:
## never grant behavior rewards or change friendship, species or ownership.
func store_fauna_health(identity: String, ratio: float, dead: bool, food: float) -> bool:
	var state := get_node("/root/GameState")
	if int(state.current_phase) != 1 or is_behavior_transaction_active() or not is_finite(ratio) or ratio < 0 or ratio > 1 or not is_finite(food) or food < 0 or food > 1000 or dead != (ratio == 0.0):
		return false
	var entry: Dictionary = get_saved_creature_encounter(identity)
	if entry.is_empty():
		var population: Node = get_tree().get_first_node_in_group(&"campaign_surface_population")
		if population != null:
			var record: Dictionary = population.storage.record(identity)
			if not record.is_empty(): entry = _encounters.get_entry(record.identity, record.role, int(record.individual_seed))
	if entry.is_empty() or entry.get("body_id") != state.get_current_body_record()["id"]:
		return false
	entry["health_ratio"] = ratio
	entry["dead"] = dead
	entry["carcass_food"] = food
	if not _put_encounter(entry): return false
	get_node("/root/SaveGameService").schedule_autosave()
	return true


## Partial trust/health changes schedule a snapshot; completed actions commit now.
func store_creature_encounter(entry: Dictionary, immediate: bool = false, outcome: String = "", context: Dictionary = {}) -> Dictionary:
	if is_behavior_transaction_active():
		return {"ok": false, "reason": "transaction_in_progress"}
	var state := get_node("/root/GameState")
	var saves := get_node("/root/SaveGameService")
	if int(state.current_phase) != 0 or entry.get("body_id") != state.get_current_body_record()["id"]:
		return {"ok": false, "reason": "wrong_phase_or_body"}
	var key: String = str(entry.get("object_id", ""))
	var before_entry: Dictionary = get_saved_creature_encounter(key)
	if not _put_encounter(entry):
		return {"ok": false, "reason": "invalid_or_full_encounter"}
	if not immediate and outcome.is_empty():
		saves.schedule_autosave()
		return {"ok": true, "saved": false}
	var campaign = state.campaign
	var before_campaign: Dictionary = campaign.export_state()
	var before_behavior: Dictionary = _behavior.export_state()
	var receipt: Dictionary = {"ok": false, "reason": "no_reward"}
	var event: GameEvent
	if not outcome.is_empty():
		event = campaign.next_event(GameEvent.Kind.CONFLICT_RESULT if outcome == "won" else GameEvent.Kind.INTERACTION,
			entry["object_id"], 0, outcome)
		event.encounter_id = "creature:" + str(entry["object_id"])
		event.behavior_context = context.duplicate(true)
		if not campaign.accept_event(event, 0):
			_restore_encounter_entry(key, before_entry)
			return {"ok": false, "reason": "invalid_event"}
		receipt = _behavior.apply_event(event, campaign.data["id"], campaign.data["player_object_id"], 0)
	# No reward/relationship observer is notified until the joint snapshot exists.
	_encounter_commit_active = true
	var saved: bool = saves.save_now()
	if not saved:
		_restore_encounter_entry(key, before_entry)
		_behavior.import_state(before_behavior)
		campaign.import_state(before_campaign)
	_encounter_commit_active = false
	if not saved:
		return {"ok": false, "reason": "save_failed"}
	if event != null:
		behavior_changed.emit()
		if receipt.get("ok", false):
			behavior_rewarded.emit(receipt.duplicate(true))
		state.campaign_event.emit(event.to_dict())
	return {"ok": true, "saved": true, "reward": receipt}


func _restore_encounter_entry(key: String, before: Dictionary) -> void:
	var population: Node = get_tree().get_first_node_in_group(&"campaign_surface_population")
	if population != null and not population.storage.record(key).is_empty():
		population.store_encounter(key, before)
		return
	if before.is_empty():
		_encounters.entries.erase(key)
	else:
		_encounters.entries[key] = before


func get_discovered_species_count() -> int:
	return discovered_species.size()


func get_discovered_region_count() -> int:
	return discovered_regions.size()


func _ensure_starter_parts() -> void:
	var starter_categories: Array[String] = [
		PartLibrary.CATEGORY_BODY,
		PartLibrary.CATEGORY_MOUTH,
		PartLibrary.CATEGORY_EYES,
		PartLibrary.CATEGORY_LEGS,
		PartLibrary.CATEGORY_ARMS,
		PartLibrary.CATEGORY_TAIL,
		PartLibrary.CATEGORY_HORNS,
		PartLibrary.CATEGORY_PLATES,
		PartLibrary.CATEGORY_SPIKES,
		PartLibrary.CATEGORY_DECOR,
		PartLibrary.CATEGORY_PAINT,
	]
	for category_id in starter_categories:
		var starter_id: String = PartLibrary.get_first_part_id_for_category(category_id)
		if not starter_id.is_empty() and not unlocked_parts.has(starter_id):
			unlocked_parts[starter_id] = {
				"reason": "Starter part",
				"order": unlocked_parts.size(),
			}


func _unlock_species_part(species_seed: int, blueprint: Dictionary) -> String:
	var candidates: Array[String] = []
	var body: Dictionary = blueprint.get("body", {})
	_append_candidate(candidates, str(body.get("part_id", "")))
	var parts: Array = blueprint.get("parts", [])
	for placement_value in parts:
		if placement_value is Dictionary:
			_append_candidate(candidates, str(placement_value.get("part_id", "")))
	var paint: Dictionary = blueprint.get("paint", {})
	_append_candidate(candidates, str(paint.get("part_id", "")))
	candidates.sort()
	var locked: Array[String] = []
	for part_id in candidates:
		if not is_part_unlocked(part_id):
			locked.append(part_id)
	if locked.is_empty():
		return ""
	var selected: String = locked[posmod(species_seed, locked.size())]
	unlock_part(selected, "Species discovery")
	return selected


func _append_candidate(candidates: Array[String], part_id: String) -> void:
	if part_id.is_empty() or candidates.has(part_id):
		return
	if PartLibrary.get_part(part_id).is_empty():
		return
	candidates.append(part_id)


func _record_journal_observation(entry: Dictionary, blueprint: Dictionary, world_seed: int) -> void:
	# Additive metadata: old discoveries get their first real observation on revisit.
	# Never regenerate an old species from a seed with a newer creature generator.
	if entry.has("journal") or blueprint.is_empty():
		return
	var location: String = "Welt %d" % world_seed
	var state := get_node_or_null("/root/GameState")
	if state != null and int(state.call("get_world_seed")) == world_seed:
		var system: Dictionary = DiscoveryPlanetCatalog.create_system(int(state.call("get_system_seed")))
		var planet: Dictionary = DiscoveryPlanetCatalog.get_planet(system, int(state.call("get_current_planet_index")))
		if int(planet.get("effective_seed", -1)) == world_seed:
			location = str(planet.get("name", location))
	entry["journal"] = DiscoveryRecords.observation(blueprint, location)
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		saves.call("schedule_autosave")


func _add_discovery_points(amount: int) -> void:
	discovery_points = maxi(discovery_points + amount, 0)
	discovery_points_changed.emit(discovery_points)


func _remove_invalid_part_unlocks() -> void:
	for key in unlocked_parts.keys():
		if PartLibrary.get_part(str(key)).is_empty():
			unlocked_parts.erase(key)


func _get_world_seed() -> int:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("get_world_seed"):
		return int(game_state.call("get_world_seed"))
	return 1


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _discovery_body(world_seed: int, body_id: String = "") -> Dictionary:
	var state := get_node_or_null("/root/GameState")
	if state == null: return {}
	if not body_id.is_empty(): return state.campaign.body_record(body_id)
	if int(state.world_seed) == world_seed: return state.get_current_body_record()
	return state.campaign.body_record(state.campaign.find_body_id(world_seed, state.active_system_id))


func species_discovery_key(species_seed: int, world_seed: int = 0) -> String:
	if world_seed <= 0: world_seed = _get_world_seed()
	var body: Dictionary = _discovery_body(world_seed)
	if body.is_empty(): return ""
	var legacy_key: String = "%d:%d" % [world_seed, species_seed]
	# Preserve old book keys and unlock references, but only for their owner.
	if discovered_species.get(legacy_key, {}).get("body_id") == body.id: return legacy_key
	return get_node("/root/GameState").campaign.species_id(body.id, species_seed)


func _annotate_discovery(entry: Dictionary, is_region: bool) -> bool:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return false
	var campaign = state.get("campaign")
	var body: Dictionary = _discovery_body(int(entry.get("world_seed", 1)), str(entry.get("body_id", "")))
	if body.is_empty() or body.seed != entry.get("world_seed"): return false
	entry["body_id"] = body["id"]
	if not entry.has("id"):
		entry["id"] = campaign.region_id(body["id"], Vector2i(int(entry.get("x", 0)), int(entry.get("z", 0)))) if is_region else campaign.species_id(body["id"], int(entry.get("species_seed", 1)))
	return true


func _emit_discovery_event(target_id: String) -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		var event = state.get("campaign").next_event(GameEvent.Kind.DISCOVERY, target_id, int(state.get("current_phase")), "discovered")
		state.call("record_campaign_event", event)
