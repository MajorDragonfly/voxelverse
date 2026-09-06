extends Node

signal part_unlocked(part_id: String, reason: String)
signal species_discovered(species_key: String, species_name: String)
signal region_discovered(region_key: String)
signal discovery_points_changed(points: int)

const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")

const SAVE_SCHEMA: int = 1
const SPECIES_DISCOVERY_POINTS: int = 3
const REGION_DISCOVERY_POINTS: int = 1

var discovery_points: int = 0
var unlocked_parts: Dictionary = {}
var discovered_species: Dictionary = {}
var discovered_regions: Dictionary = {}


func _ready() -> void:
	_ensure_starter_parts()


func reset_for_new_game() -> void:
	discovery_points = 0
	unlocked_parts.clear()
	discovered_species.clear()
	discovered_regions.clear()
	_ensure_starter_parts()
	discovery_points_changed.emit(discovery_points)


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
	_add_discovery_points(SPECIES_DISCOVERY_POINTS)
	var unlocked_part: String = _unlock_species_part(species_seed, blueprint)
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
	}


func import_state(data: Dictionary) -> void:
	discovery_points = maxi(int(data.get("discovery_points", 0)), 0)
	unlocked_parts = _as_dictionary(data.get("unlocked_parts", {}))
	discovered_species = _as_dictionary(data.get("discovered_species", {}))
	discovered_regions = _as_dictionary(data.get("discovered_regions", {}))
	_remove_invalid_part_unlocks()
	_ensure_starter_parts()
	discovery_points_changed.emit(discovery_points)


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
