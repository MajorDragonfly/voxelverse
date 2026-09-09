extends Node

signal part_unlocked(part_id: String, reason: String)
signal species_discovered(species_key: String, species_name: String)
signal region_discovered(region_key: String)
signal discovery_points_changed(points: int)
signal behavior_changed
signal behavior_rewarded(receipt: Dictionary)
signal behavior_node_purchased(node_id: String)

const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")
const DiscoveryRecords = preload("res://core/discovery/discovery_records.gd")
const DiscoveryPlanetCatalog = preload("res://world/generation/planet_catalog_v7.gd")

const GameEvent = preload("res://core/campaign/game_event.gd")
const Behavior = preload("res://core/progression/behavior_progression.gd")
const BehaviorRules = preload("res://core/progression/behavior_catalog.gd")

const SAVE_SCHEMA: int = 3
const SPECIES_DISCOVERY_POINTS: int = 3
const REGION_DISCOVERY_POINTS: int = 1

var discovery_points: int = 0
var unlocked_parts: Dictionary = {}
var discovered_species: Dictionary = {}
var discovered_regions: Dictionary = {}
var _behavior := Behavior.new()
var _behavior_purchase_active: bool = false


func _ready() -> void:
	_ensure_starter_parts()


func reset_for_new_game() -> void:
	discovery_points = 0
	unlocked_parts.clear()
	discovered_species.clear()
	discovered_regions.clear()
	_behavior.reset()
	_ensure_starter_parts()
	discovery_points_changed.emit(discovery_points)
	behavior_changed.emit()


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
	var species_key: String = "%d:%d" % [world_seed, species_seed]
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


func register_region_discovery(
	coordinates: Vector2i,
	world_seed: int = 0
) -> bool:
	if world_seed <= 0:
		world_seed = _get_world_seed()
	var region_key: String = "%d:%d:%d" % [
		world_seed,
		coordinates.x,
		coordinates.y,
	]
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
	}


func import_state(data: Dictionary) -> bool:
	if not validate_state(data).is_empty():
		return false
	if data.has("behavior"):
		_behavior.import_state(data["behavior"])
	else:
		# Discovery-only saves migrate without inventing past behavior rewards.
		_behavior.reset()
	discovery_points = maxi(int(data.get("discovery_points", 0)), 0)
	unlocked_parts = _as_dictionary(data.get("unlocked_parts", {}))
	discovered_species = _as_dictionary(data.get("discovered_species", {}))
	discovered_regions = _as_dictionary(data.get("discovered_regions", {}))
	for entry in discovered_species.values():
		_annotate_discovery(entry, false)
	for entry in discovered_regions.values():
		_annotate_discovery(entry, true)
	# Retain unlock IDs for unavailable parts so restored content is not lost.
	_ensure_starter_parts()
	discovery_points_changed.emit(discovery_points)
	behavior_changed.emit()
	return true


static func validate_state(data: Dictionary) -> String:
	if not BehaviorRules.is_integer(data.get("schema", 1), 1, SAVE_SCHEMA):
		return "Unsupported progression schema."
	if data.has("behavior"):
		return Behavior.validate_state(data["behavior"])
	if int(data.get("schema", 1)) >= SAVE_SCHEMA:
		return "Missing behavior progression."
	return ""


static func has_unsupported_contract(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return BehaviorRules.is_newer_version(data.get("schema", 1), SAVE_SCHEMA) or Behavior.has_unsupported_contract(data.get("behavior", {}))


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
	return _behavior.wallet(phase)


func get_behavior_nodes(phase: int) -> Array[Dictionary]:
	var state := get_node_or_null("/root/GameState")
	return _behavior.nodes_for_phase(phase, int(state.get("current_phase")) if state != null else 0)


func get_behavior_effect(effect_id: String, phase: int, body_value: float = 1.0, technology_bonus: float = 0.0) -> Dictionary:
	return _behavior.calculate_effect(effect_id, phase, body_value, technology_bonus)


func purchase_behavior_node(node_id: String) -> Dictionary:
	if _behavior_purchase_active:
		return {"ok": false, "reason": "purchase_in_progress"}
	var state := get_node_or_null("/root/GameState")
	var saves := get_node_or_null("/root/SaveGameService")
	if state == null or saves == null:
		return {"ok": false, "reason": "missing_campaign_services"}
	var before: Dictionary = _behavior.export_state()
	var result: Dictionary = _behavior.purchase(node_id, int(state.get("current_phase")))
	if not result["ok"]:
		return result
	_behavior_purchase_active = true
	var saved: bool = bool(saves.call("save_now"))
	if not saved:
		_behavior.import_state(before)
	_behavior_purchase_active = false
	if not saved:
		return {"ok": false, "reason": "save_failed"}
	behavior_changed.emit()
	behavior_node_purchased.emit(node_id)
	return result


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


func _annotate_discovery(entry: Dictionary, is_region: bool) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var campaign = state.get("campaign")
	var body: Dictionary = campaign.body_for_seed(int(entry.get("world_seed", 1)), int(state.call("get_system_seed")))
	entry["body_id"] = body["id"]
	if not entry.has("id"):
		entry["id"] = campaign.region_id(body["id"], Vector2i(int(entry.get("x", 0)), int(entry.get("z", 0)))) if is_region else campaign.species_id(body["id"], int(entry.get("species_seed", 1)))


func _emit_discovery_event(target_id: String) -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		var event = state.get("campaign").next_event(GameEvent.Kind.DISCOVERY, target_id, int(state.get("current_phase")), "discovered")
		state.call("record_campaign_event", event)
