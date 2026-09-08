extends "res://world/simulation/region_background_simulation_v7.gd"
class_name RegionEcologySimulation

const PERSISTENCE_SCHEMA: int = 1

var _last_discovered_region: Vector2i = Vector2i(2_147_483_647, 2_147_483_647)


func _process(delta: float) -> void:
	var game_state := get_node_or_null("/root/GameState")
	var simulation_delta: float = float(game_state.call("simulation_delta", delta)) if game_state != null else delta
	if simulation_delta <= 0.0:
		return
	super._process(simulation_delta)
	_register_current_region_discovery()


func export_state() -> Dictionary:
	var serialized_regions: Dictionary = {}
	for coordinates_value in _region_states.keys():
		var coordinates: Vector2i = coordinates_value
		var state: Dictionary = _region_states.get(coordinates, {})
		serialized_regions[_coordinates_key(coordinates)] = {
			"x": coordinates.x,
			"z": coordinates.y,
			"plant_biomass": float(state.get("plant_biomass", 0.5)),
			"water_availability": float(state.get("water_availability", 0.5)),
			"carcass_biomass": float(state.get("carcass_biomass", 0.0)),
			"species": _serialize_species(state.get("species", [])),
			"last_touched_tick": int(state.get("last_touched_tick", 0)),
		}
	return {
		"schema": PERSISTENCE_SCHEMA,
		"world_seed": _get_runtime_world_seed(),
		"simulation_tick": _simulation_tick,
		"regions": serialized_regions,
	}


func import_state(data: Dictionary) -> void:
	var runtime_world_seed: int = _get_runtime_world_seed()
	var saved_world_seed: int = int(data.get("world_seed", runtime_world_seed))
	if saved_world_seed != runtime_world_seed:
		return
	var regions_value: Variant = data.get("regions", {})
	if not (regions_value is Dictionary):
		return
	_region_states.clear()
	var serialized_regions: Dictionary = regions_value
	for key in serialized_regions.keys():
		var state_value: Variant = serialized_regions[key]
		if not (state_value is Dictionary):
			continue
		var source: Dictionary = state_value
		var coordinates := Vector2i(
			int(source.get("x", 0)),
			int(source.get("z", 0))
		)
		_region_states[coordinates] = {
			"coordinates": coordinates,
			"plant_biomass": clampf(float(source.get("plant_biomass", 0.5)), 0.0, 1.0),
			"water_availability": clampf(float(source.get("water_availability", 0.5)), 0.0, 1.0),
			"carcass_biomass": clampf(float(source.get("carcass_biomass", 0.0)), 0.0, 1.0),
			"species": _deserialize_species(source.get("species", [])),
			"last_touched_tick": int(source.get("last_touched_tick", 0)),
		}
	_simulation_tick = maxi(int(data.get("simulation_tick", 0)), 0)
	if _player != null and is_instance_valid(_player):
		_ensure_active_regions()


func get_runtime_summary(world_position: Vector3) -> Dictionary:
	var coordinates: Vector2i = get_region_coordinates(world_position)
	var state: Dictionary = get_region_state(coordinates)
	var total_population: float = 0.0
	var predator_population: float = 0.0
	for entry_value in state.get("species", []):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var population: float = maxf(float(entry.get("population", 0.0)), 0.0)
		total_population += population
		if str(entry.get("role", "")) == "predator":
			predator_population += population
	return {
		"coordinates": coordinates,
		"plant_biomass": float(state.get("plant_biomass", 0.0)),
		"water_availability": float(state.get("water_availability", 0.0)),
		"carcass_biomass": float(state.get("carcass_biomass", 0.0)),
		"total_population": total_population,
		"predator_population": predator_population,
		"species_count": state.get("species", []).size(),
	}


func register_carcass_addition(
	coordinates: Vector2i,
	amount: float
) -> void:
	if amount <= 0.0:
		return
	_ensure_region(coordinates)
	var state: Dictionary = _region_states.get(coordinates, {})
	state["carcass_biomass"] = clampf(
		float(state.get("carcass_biomass", 0.0)) + amount,
		0.0,
		1.0
	)
	state["last_touched_tick"] = _simulation_tick
	_region_states[coordinates] = state


func register_carcass_consumption(
	coordinates: Vector2i,
	amount: float
) -> void:
	if amount <= 0.0:
		return
	_ensure_region(coordinates)
	var state: Dictionary = _region_states.get(coordinates, {})
	state["carcass_biomass"] = maxf(
		float(state.get("carcass_biomass", 0.0)) - amount,
		0.0
	)
	state["last_touched_tick"] = _simulation_tick
	_region_states[coordinates] = state


func _register_current_region_discovery() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var coordinates: Vector2i = get_region_coordinates(_player.global_position)
	if coordinates == _last_discovered_region:
		return
	_last_discovered_region = coordinates
	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null and progression.has_method("register_region_discovery"):
		progression.call(
			"register_region_discovery",
			coordinates,
			_get_runtime_world_seed()
		)


func _get_runtime_world_seed() -> int:
	var generator := get_node_or_null("/root/WorldGenerator")
	if generator != null:
		if generator.has_method("get_world_seed"):
			return int(generator.call("get_world_seed"))
		if generator.has_method("get_seed_override"):
			return int(generator.call("get_seed_override"))
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("get_world_seed"):
		return int(game_state.call("get_world_seed"))
	return 1


func _serialize_species(entries_value: Variant) -> Array:
	var result: Array = []
	if not (entries_value is Array):
		return result
	for entry_value in entries_value:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		result.append({
			"slot": int(entry.get("slot", 0)),
			"species_seed": int(entry.get("species_seed", 1)),
			"role": str(entry.get("role", "forager")),
			"population": maxf(float(entry.get("population", 0.0)), 0.0),
			"carrying_capacity": maxf(float(entry.get("carrying_capacity", 1.0)), 1.0),
		})
	return result


func _deserialize_species(entries_value: Variant) -> Array:
	if not (entries_value is Array):
		return []
	return _serialize_species(entries_value)


func _coordinates_key(coordinates: Vector2i) -> String:
	return "%d,%d" % [coordinates.x, coordinates.y]
