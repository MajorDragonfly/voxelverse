extends Node
## Shared ecology equations, bounded active regions; distant records are frozen.
const Model = preload("res://world/surface/campaign_population_state.gd")
const Simulation = preload("res://world/simulation/region_background_simulation_v7.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
var population: Node
var clock: float = 0.0
var pending: Array = []

func _ready() -> void: add_to_group(&"campaign_surface_ecology")

func _process(delta: float) -> void:
	var dt: float = get_node("/root/GameState").simulation_delta(delta)
	if dt <= 0 or not get_parent().world_initialized or not population.storage_error.is_empty(): return
	clock += dt
	if clock >= 4.0 and pending.is_empty():
		clock = fmod(clock, 4.0)
		pending = Model.Cells.nearby(population.descriptor, population.player.location()).keys()
	# Bounded CPU work, no catch-up burst after loading or travel.
	for i in range(mini(2, pending.size())):
		var region: Dictionary = population.storage.region(pending.pop_front(), false)
		if region.is_empty(): continue
		for value: Dictionary in region.get("ecology", {}).values():
			Simulation.advance_state(value, 0.25)
			value.last_touched_tick += 1

func record_at(point: Vector3) -> Dictionary:
	var place: Dictionary = Space.encode(self, point)
	var region: Dictionary = population.storage.region(Model.cell(population.descriptor, place).id)
	if region.is_empty(): return {}
	if not region.has("ecology"): region.ecology = {}
	if region.ecology.is_empty():
		var sample: Dictionary = Space.sample(self, point)
		var species: Array = []
		for animal: Dictionary in region.objects.values():
			species.append({"slot": species.size(), "species_seed": animal.species_seed, "role": animal.role, "population": 1.0, "carrying_capacity": 3.0})
			if species.size() >= 16: break
		region.ecology.current = {"plant_biomass": sample.get("moisture", 0.5), "water_availability": sample.get("moisture", 0.5), "carcass_biomass": 0.0, "species": species, "last_touched_tick": 0}
	return region.ecology.values()[0]

func died(point: Vector3, seed_value: int, food: float) -> void:
	var data: Dictionary = record_at(point)
	if data.is_empty(): return
	for species: Dictionary in data.species:
		if species.species_seed == seed_value: species.population = maxf(0.0, species.population - 1.0); break
	data.carcass_biomass = minf(1.0, data.carcass_biomass + clampf(food / 160.0, 0.02, 0.35))

func consumed_plant(point: Vector3, amount: float) -> void:
	var data: Dictionary = record_at(point)
	if not data.is_empty(): data.plant_biomass = maxf(0.0, data.plant_biomass - amount / 160.0)
