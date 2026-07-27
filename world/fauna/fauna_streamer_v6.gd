extends Node3D

const WILDLIFE_SCENE: PackedScene = preload(
	"res://creatures/wildlife/procedural_wildlife_v6.tscn"
)

# A region owns a small deterministic species catalogue. Individuals stream in
# around the player, while species identity remains stable for the world seed.

@export_range(1, 24, 1) var target_population: int = 8
@export_range(1, 32, 1) var maximum_population: int = 12
@export_range(0.2, 5.0, 0.1) var spawn_interval: float = 0.85
@export_range(4.0, 60.0, 1.0) var minimum_spawn_radius: float = 14.0
@export_range(8.0, 80.0, 1.0) var maximum_spawn_radius: float = 28.0
@export_range(20.0, 160.0, 1.0) var despawn_radius: float = 76.0
@export_range(1, 24, 1) var spawn_attempts: int = 12
@export_range(64.0, 1024.0, 16.0) var species_region_size: float = 256.0

var _player: Node3D
var _spawn_timer: float = 0.0
var _spawn_serial: int = 0
var _active_fauna: Array[Node3D] = []


func _ready() -> void:
	call_deferred("_bind_player")


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_bind_player()
		return
	_prune_fauna()
	_enforce_population_limit()
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_interval
	if _active_fauna.size() < target_population:
		_spawn_one_creature()


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D


func _spawn_one_creature() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = (
		WorldGenerator.get_world_seed()
		+ _spawn_serial * 73_856_093
		+ 1_475_921_941
	)
	_spawn_serial += 1

	for _attempt in range(spawn_attempts):
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

		var region_x: int = floori(world_x / species_region_size)
		var region_z: int = floori(world_z / species_region_size)
		var species_count: int = 6
		if WorldGenerator.has_method("get_planet_profile"):
			var planet_profile: Dictionary = WorldGenerator.get_planet_profile()
			species_count = clampi(
				int(planet_profile.get("fauna_species_count", 6)),
				3,
				10
			)
		var species_slot: int = posmod(_spawn_serial + _attempt, species_count)
		var species_seed: int
		if WorldGenerator.has_method("get_species_seed"):
			species_seed = int(
				WorldGenerator.call(
					"get_species_seed",
					region_x,
					region_z,
					species_slot
				)
			)
		else:
			species_seed = absi(
				WorldGenerator.get_world_seed()
				+ region_x * 73_856_093
				+ region_z * 19_349_663
				+ species_slot * 83_492_791
			)
		var individual_seed: int = absi(
			species_seed + _spawn_serial * 32_452_843
		)

		var creature := WILDLIFE_SCENE.instantiate() as Node3D
		if creature == null:
			return
		if creature.has_method("configure"):
			creature.call("configure", species_seed, individual_seed)
		add_child(creature)
		creature.global_position = Vector3(
			world_x,
			WorldGenerator.get_visual_terrain_height(world_x, world_z) + 0.9,
			world_z
		)
		_active_fauna.append(creature)
		return


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
