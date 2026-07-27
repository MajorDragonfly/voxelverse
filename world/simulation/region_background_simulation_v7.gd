extends Node
class_name RegionBackgroundSimulationV7

# Region simulation is independent from rendered chunks. It stores compact
# populations and resource values, so ecology can continue while no terrain or
# wildlife Nodes are loaded for that region.

@export_range(0.5, 30.0, 0.5) var tick_interval: float = 4.0
@export_range(0.05, 4.0, 0.05) var simulated_hours_per_tick: float = 0.25
@export_range(64.0, 1024.0, 16.0) var region_size: float = 256.0
@export_range(1, 5, 1) var active_region_radius: int = 2
@export_range(16, 256, 8) var maximum_cached_regions: int = 96

const ROLES: Array[String] = [
	"forager",
	"grazer",
	"scavenger",
	"predator",
	"climber",
	"swimmer",
]

var _player: Node3D
var _tick_timer: float = 0.0
var _region_states: Dictionary = {}
var _simulation_tick: int = 0


func _ready() -> void:
	add_to_group(&"region_background_simulation")
	call_deferred("_bind_player")


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_bind_player()
		return
	_ensure_active_regions()
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = tick_interval
	_simulation_tick += 1
	for coordinates_value in _region_states.keys():
		var coordinates: Vector2i = coordinates_value
		_simulate_region(coordinates, simulated_hours_per_tick)
	_trim_cache()


func get_region_coordinates(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / region_size),
		floori(world_position.z / region_size)
	)


func get_region_state(coordinates: Vector2i) -> Dictionary:
	_ensure_region(coordinates)
	return _region_states.get(coordinates, {}).duplicate(true)


func get_species_entries(coordinates: Vector2i) -> Array:
	_ensure_region(coordinates)
	var state: Dictionary = _region_states.get(coordinates, {})
	return state.get("species", []).duplicate(true)


func choose_species(
	coordinates: Vector2i,
	selection_value: float
) -> Dictionary:
	var entries: Array = get_species_entries(coordinates)
	if entries.is_empty():
		return {}
	var total_population: float = 0.0
	for entry_value in entries:
		if entry_value is Dictionary:
			total_population += maxf(
				float(entry_value.get("population", 0.0)),
				0.0
			)
	if total_population <= 0.001:
		return entries[0].duplicate(true)
	var target: float = clampf(selection_value, 0.0, 0.99999)
	target *= total_population
	var accumulated: float = 0.0
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		accumulated += maxf(float(entry.get("population", 0.0)), 0.0)
		if target <= accumulated:
			return entry.duplicate(true)
	return entries.back().duplicate(true)


func register_wildlife_loss(
	coordinates: Vector2i,
	species_seed: int,
	amount: float = 1.0
) -> void:
	_ensure_region(coordinates)
	var state: Dictionary = _region_states.get(coordinates, {})
	var entries: Array = state.get("species", [])
	for index in range(entries.size()):
		if not (entries[index] is Dictionary):
			continue
		var entry: Dictionary = entries[index]
		if int(entry.get("species_seed", 0)) != species_seed:
			continue
		entry["population"] = maxf(
			float(entry.get("population", 0.0)) - amount,
			0.0
		)
		entries[index] = entry
		break
	state["species"] = entries
	_region_states[coordinates] = state


func register_plant_consumption(
	coordinates: Vector2i,
	amount: float
) -> void:
	_ensure_region(coordinates)
	var state: Dictionary = _region_states.get(coordinates, {})
	state["plant_biomass"] = clampf(
		float(state.get("plant_biomass", 0.5)) - amount,
		0.0,
		1.0
	)
	_region_states[coordinates] = state


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D


func _ensure_active_regions() -> void:
	var center: Vector2i = get_region_coordinates(_player.global_position)
	for offset_z in range(-active_region_radius, active_region_radius + 1):
		for offset_x in range(-active_region_radius, active_region_radius + 1):
			_ensure_region(center + Vector2i(offset_x, offset_z))


func _ensure_region(coordinates: Vector2i) -> void:
	if _region_states.has(coordinates):
		var existing: Dictionary = _region_states[coordinates]
		existing["last_touched_tick"] = _simulation_tick
		_region_states[coordinates] = existing
		return
	var random := RandomNumberGenerator.new()
	random.seed = (
		WorldGenerator.get_world_seed()
		+ coordinates.x * 73_856_093
		+ coordinates.y * 19_349_663
		+ 2_147_483
	)
	var species_count: int = 6
	if WorldGenerator.has_method("get_planet_profile"):
		var planet_profile: Dictionary = WorldGenerator.get_planet_profile()
		species_count = clampi(
			int(planet_profile.get("fauna_species_count", 6)),
			3,
			10
		)
	var species_entries: Array = []
	for slot in range(species_count):
		var species_seed: int = absi(
			WorldGenerator.get_world_seed()
			+ coordinates.x * 73_856_093
			+ coordinates.y * 19_349_663
			+ slot * 83_492_791
		)
		if WorldGenerator.has_method("get_species_seed"):
			species_seed = int(
				WorldGenerator.call(
					"get_species_seed",
					coordinates.x,
					coordinates.y,
					slot
				)
			)
		var role: String = ROLES[posmod(species_seed, ROLES.size())]
		var starting_population: float = random.randf_range(8.0, 34.0)
		if role == "predator":
			starting_population *= 0.34
		elif role == "scavenger":
			starting_population *= 0.62
		species_entries.append({
			"slot": slot,
			"species_seed": species_seed,
			"role": role,
			"population": starting_population,
			"carrying_capacity": starting_population * random.randf_range(1.4, 2.5),
		})
	_region_states[coordinates] = {
		"coordinates": coordinates,
		"plant_biomass": random.randf_range(0.45, 0.95),
		"water_availability": random.randf_range(0.35, 1.0),
		"carcass_biomass": random.randf_range(0.0, 0.18),
		"species": species_entries,
		"last_touched_tick": _simulation_tick,
	}


func _simulate_region(
	coordinates: Vector2i,
	hours: float
) -> void:
	var state: Dictionary = _region_states.get(coordinates, {})
	if state.is_empty():
		return
	var plant_biomass: float = clampf(
		float(state.get("plant_biomass", 0.5)),
		0.0,
		1.0
	)
	var water: float = clampf(
		float(state.get("water_availability", 0.5)),
		0.0,
		1.0
	)
	var carcass: float = clampf(
		float(state.get("carcass_biomass", 0.0)),
		0.0,
		1.0
	)
	plant_biomass = clampf(
		plant_biomass + (0.018 + water * 0.020) * hours,
		0.0,
		1.0
	)
	carcass = maxf(carcass - 0.016 * hours, 0.0)

	var entries: Array = state.get("species", [])
	var prey_population: float = 0.0
	var predator_population: float = 0.0
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var role: String = str(entry.get("role", "forager"))
		var population: float = maxf(float(entry.get("population", 0.0)), 0.0)
		if role == "predator":
			predator_population += population
		else:
			prey_population += population

	for index in range(entries.size()):
		if not (entries[index] is Dictionary):
			continue
		var entry: Dictionary = entries[index]
		var role: String = str(entry.get("role", "forager"))
		var population: float = maxf(float(entry.get("population", 0.0)), 0.0)
		var capacity: float = maxf(
			float(entry.get("carrying_capacity", 20.0)),
			1.0
		)
		var resource_factor: float = plant_biomass
		var growth_rate: float = 0.020
		var loss_rate: float = 0.004
		match role:
			"predator":
				resource_factor = clampf(prey_population / maxf(predator_population * 8.0, 1.0), 0.0, 1.0)
				growth_rate = 0.012
			"scavenger":
				resource_factor = clampf(carcass * 3.0 + prey_population / 180.0, 0.0, 1.0)
				growth_rate = 0.014
			"swimmer":
				resource_factor = water
			"climber":
				resource_factor = clampf(plant_biomass * 0.72 + 0.20, 0.0, 1.0)
		var density_pressure: float = population / capacity
		var change: float = population * (
			growth_rate * resource_factor * (1.0 - density_pressure)
			- loss_rate * (1.0 - resource_factor)
		) * hours
		if role != "predator":
			var predation: float = minf(
				population,
				predator_population * 0.0018 * hours
			)
			change -= predation
			carcass = clampf(carcass + predation * 0.0015, 0.0, 1.0)
		if role in ["grazer", "forager", "climber"]:
			plant_biomass = maxf(
				plant_biomass - population * 0.000012 * hours,
				0.0
			)
		entry["population"] = clampf(population + change, 0.0, capacity * 1.25)
		entries[index] = entry

	state["plant_biomass"] = plant_biomass
	state["carcass_biomass"] = carcass
	state["species"] = entries
	_region_states[coordinates] = state


func _trim_cache() -> void:
	if _region_states.size() <= maximum_cached_regions:
		return
	var entries: Array = []
	for coordinates_value in _region_states.keys():
		var coordinates: Vector2i = coordinates_value
		var state: Dictionary = _region_states[coordinates]
		entries.append({
			"coordinates": coordinates,
			"last_touched_tick": int(state.get("last_touched_tick", 0)),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("last_touched_tick", 0)) < int(b.get("last_touched_tick", 0))
	)
	while _region_states.size() > maximum_cached_regions and not entries.is_empty():
		var oldest: Dictionary = entries.pop_front()
		_region_states.erase(oldest.get("coordinates", Vector2i.ZERO))
