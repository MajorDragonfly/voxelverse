extends Node3D

const WILDLIFE_SCENE: PackedScene = preload(
	"res://creatures/wildlife/procedural_wildlife_v7.tscn"
)
const DomesticFauna = preload("res://world/fauna/domestication/domestic_fauna_runtime.gd")
var domestic_fauna := DomesticFauna.new()

const HABITAT_SIZE: float = 12.0

# Visible animals are only representatives of compact regional populations.
# Their species and ecological roles come from RegionBackgroundSimulationV7.

@export_range(1, 24, 1) var target_population: int = 9
@export_range(1, 32, 1) var maximum_population: int = 14
@export_range(0.2, 5.0, 0.1) var spawn_interval: float = 0.80
@export_range(4.0, 60.0, 1.0) var minimum_spawn_radius: float = 14.0
@export_range(8.0, 90.0, 1.0) var maximum_spawn_radius: float = 31.0
@export_range(20.0, 180.0, 1.0) var despawn_radius: float = 82.0
@export_range(1, 24, 1) var spawn_attempts: int = 14
@export_range(64.0, 1024.0, 16.0) var species_region_size: float = 256.0

var _player: Node3D
var _simulation: Node
var _spawn_timer: float = 0.0
var _spawn_serial: int = 0
var _active_fauna: Array[Node3D] = []


func _ready() -> void:
	get_node("/root/SaveGameService").game_loaded.connect(func(_path: String) -> void: domestic_fauna.reset(self))
	call_deferred("_bind_runtime_services")


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_bind_runtime_services()
		return
	if _simulation == null or not is_instance_valid(_simulation):
		_bind_runtime_services()
	domestic_fauna.update(self)
	_prune_fauna()
	_enforce_population_limit()
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_interval
	if domestic_fauna.try_spawn(self):
		return
	if _active_fauna.size() < mini(target_population, maximum_population):
		_spawn_one_creature()


func _bind_runtime_services() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_simulation = get_tree().get_first_node_in_group(
		&"region_background_simulation"
	)


func _spawn_one_creature() -> void:
	if not DomesticFauna.Catalog.eligible(get_node("/root/GameState").get_current_body()):
		return
	var random := RandomNumberGenerator.new()
	random.seed = (
		WorldGenerator.get_world_seed()
		+ _spawn_serial * 73_856_093
		+ 1_475_921_941
	)
	_spawn_serial += 1

	for attempt in range(spawn_attempts):
		var angle: float = random.randf_range(0.0, TAU)
		var radius: float = random.randf_range(
			minimum_spawn_radius,
			maximum_spawn_radius
		)
		var world_x: float = _player.global_position.x + cos(angle) * radius
		var world_z: float = _player.global_position.z + sin(angle) * radius
		# Candidate order may vary, but each habitat has stable placement and ID.
		# It must not inherit a new individual from the transient spawn serial.
		var habitat := Vector2i(floori(world_x / HABITAT_SIZE), floori(world_z / HABITAT_SIZE))
		var cell_key: String = "%d:%d" % [habitat.x, habitat.y]
		var slot_random := RandomNumberGenerator.new()
		slot_random.seed = int((str(WorldGenerator.get_world_seed()) + ":" + cell_key).sha256_text().left(8).hex_to_int())
		world_x = (float(habitat.x) + slot_random.randf_range(0.3, 0.7)) * HABITAT_SIZE
		world_z = (float(habitat.y) + slot_random.randf_range(0.3, 0.7)) * HABITAT_SIZE
		if Vector2(world_x - _player.global_position.x, world_z - _player.global_position.z).length() < minimum_spawn_radius:
			continue
		var height: float = WorldGenerator.get_terrain_height(world_x, world_z)
		if height <= WorldGenerator.get_water_level(world_x, world_z) + 0.45:
			continue
		if WorldGenerator.get_terrain_slope(world_x, world_z, 0.75) > 0.50:
			continue
		var biome: int = WorldGenerator.get_biome(world_x, world_z, height)
		if biome in [
			WorldGenerator.Biome.OCEAN,
			WorldGenerator.Biome.COAST,
			WorldGenerator.Biome.SNOW,
			WorldGenerator.Biome.ALPINE,
		]:
			continue

		var region_coordinates := Vector2i(
			floori(world_x / species_region_size),
			floori(world_z / species_region_size)
		)
		var state := get_node("/root/GameState")
		var body_id: String = state.get_current_body()["id"]
		var region_id: String = state.campaign.region_id(body_id, region_coordinates)
		var object_id: String = state.campaign.object_id(region_id, "habitat:" + cell_key)
		if _has_active_identity(object_id):
			continue
		var saved: Dictionary = get_node("/root/ProgressionService").get_saved_creature_encounter(object_id)
		if saved.get("dead", false) and float(saved.get("carcass_food", 0.0)) <= 0.0:
			continue
		var species_entry: Dictionary
		if saved.has("habitat"):
			species_entry = saved["habitat"].duplicate(true)
			species_entry["population"] = 1.0
		else:
			species_entry = _choose_species_entry(region_coordinates, slot_random.randf(),
				WorldGenerator.get_biome_composition(world_x, world_z, height).get("fauna_weights", {}))
		if species_entry.is_empty():
			continue
		var population: float = float(species_entry.get("population", 0.0))
		if population < 0.25:
			continue
		var species_seed: int = int(species_entry.get("species_seed", 1))
		var role: String = str(species_entry.get("role", "forager"))
		if not _role_matches_biome(role, biome):
			continue
		var individual_seed: int = int(saved["habitat"]["individual_seed"]) if saved.has("habitat") else int(slot_random.randi() % 2147483647)

		var creature := WILDLIFE_SCENE.instantiate() as Node3D
		if creature == null:
			return
		if creature.has_method("configure"):
			creature.call(
				"configure",
				species_seed,
				individual_seed,
				region_coordinates,
				role,
				cell_key
			)
		creature.set_meta("region_coordinates", region_coordinates)
		creature.set_meta("species_seed", species_seed)
		creature.set_meta("ecological_role", role)
		add_child(creature)
		creature.global_position = Vector3(
			world_x,
			WorldGenerator.get_visual_terrain_height(world_x, world_z) + 0.9,
			world_z
		)
		_active_fauna.append(creature)
		return


func _has_active_identity(object_id: String) -> bool:
	# A saved individual has one state owner, even before D2 actors restore.
	if not preload("res://world/domestication/campaign_animal_state.gd").lookup(get_node("/root/GameState"), object_id).is_empty():
		return true
	for creature in _active_fauna:
		if is_instance_valid(creature) and creature.get_campaign_identity().get("object_id") == object_id:
			return true
	return false


func _choose_species_entry(
	region_coordinates: Vector2i,
	selection_value: float,
	role_weights: Dictionary = {}
) -> Dictionary:
	if _simulation != null and _simulation.has_method("choose_species"):
		var selected_value: Variant = _simulation.call(
			"choose_species",
			region_coordinates,
			selection_value,
			role_weights
		)
		if selected_value is Dictionary:
			return selected_value

	var species_count: int = 6
	if WorldGenerator.has_method("get_planet_profile"):
		var planet_profile: Dictionary = WorldGenerator.get_planet_profile()
		species_count = clampi(
			int(planet_profile.get("fauna_species_count", 6)),
			3,
			10
		)
	var slot: int = clampi(
		floori(selection_value * float(species_count)),
		0,
		species_count - 1
	)
	var species_seed: int = absi(
		WorldGenerator.get_world_seed()
		+ region_coordinates.x * 73_856_093
		+ region_coordinates.y * 19_349_663
		+ slot * 83_492_791
	)
	if WorldGenerator.has_method("get_species_seed"):
		species_seed = int(
			WorldGenerator.call(
				"get_species_seed",
				region_coordinates.x,
				region_coordinates.y,
				slot
			)
		)
	var roles: Array[String] = [
		"forager",
		"grazer",
		"scavenger",
		"predator",
		"climber",
		"swimmer",
	]
	return {
		"species_seed": species_seed,
		"role": roles[posmod(species_seed, roles.size())],
		"population": 10.0,
	}


func _role_matches_biome(role: String, biome: int) -> bool:
	if role == "swimmer":
		return biome in [
			WorldGenerator.Biome.WETLAND,
			WorldGenerator.Biome.SWAMP,
			WorldGenerator.Biome.RIVER,
			WorldGenerator.Biome.LAKE,
		]
	if role == "climber":
		return biome not in [
			WorldGenerator.Biome.OCEAN,
			WorldGenerator.Biome.LAKE,
		]
	return true


func _prune_fauna() -> void:
	var retained: Array[Node3D] = []
	for fauna in _active_fauna:
		if fauna == null or not is_instance_valid(fauna) or fauna.is_queued_for_deletion():
			continue
		if fauna.global_position.distance_to(_player.global_position) > despawn_radius:
			fauna.queue_free()
			continue
		retained.append(fauna)
	_active_fauna = retained


func _enforce_population_limit() -> void:
	if _active_fauna.size() <= maximum_population:
		return
	_active_fauna.sort_custom(_is_farther_from_player)
	while _active_fauna.size() > maximum_population:
		var fauna: Node3D = _active_fauna.pop_front()
		if is_instance_valid(fauna):
			fauna.queue_free()


func _is_farther_from_player(a: Node3D, b: Node3D) -> bool:
	if _player == null:
		return false
	return (
		a.global_position.distance_squared_to(_player.global_position)
		> b.global_position.distance_squared_to(_player.global_position)
	)
