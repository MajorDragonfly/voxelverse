extends Node3D

const WILDLIFE_SCENE: PackedScene = preload(
	"res://creatures/wildlife/procedural_wildlife_v7.tscn"
)

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
	call_deferred("_bind_runtime_services")


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_bind_runtime_services()
		return
	if _simulation == null or not is_instance_valid(_simulation):
		_bind_runtime_services()
	_prune_fauna()
	_enforce_population_limit()
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_interval
	if _active_fauna.size() < target_population:
		_spawn_one_creature()


func _bind_runtime_services() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_simulation = get_tree().get_first_node_in_group(
		&"region_background_simulation"
	)


func _spawn_one_creature() -> void:
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
		var height: float = WorldGenerator.get_terrain_height(world_x, world_z)
		if height <= WorldGenerator.get_sea_level() + 0.45:
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
		var species_entry: Dictionary = _choose_species_entry(
			region_coordinates,
			random.randf()
		)
		if species_entry.is_empty():
			continue
		var population: float = float(species_entry.get("population", 0.0))
		if population < 0.25:
			continue
		var species_seed: int = int(species_entry.get("species_seed", 1))
		var role: String = str(species_entry.get("role", "forager"))
		if not _role_matches_biome(role, biome):
			continue
		var individual_seed: int = absi(
			species_seed
			+ _spawn_serial * 32_452_843
			+ attempt * 97_409
		)

		var creature := WILDLIFE_SCENE.instantiate() as Node3D
		if creature == null:
			return
		if creature.has_method("configure"):
			creature.call(
				"configure",
				species_seed,
				individual_seed,
				region_coordinates,
				role
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


func _choose_species_entry(
	region_coordinates: Vector2i,
	selection_value: float
) -> Dictionary:
	if _simulation != null and _simulation.has_method("choose_species"):
		var selected_value: Variant = _simulation.call(
			"choose_species",
			region_coordinates,
			selection_value
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
		if fauna == null or not is_instance_valid(fauna):
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
