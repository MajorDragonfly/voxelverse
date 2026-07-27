extends Node3D

# Fauna is streamed independently from terrain decoration. A fixed active
# population follows the player across the procedural world, preventing both an
# empty landscape and the old per-chunk population explosion.

const GRAZER_SCENE: PackedScene = preload(
	"res://creatures/animals/grazer/grazer.tscn"
)

@export_range(1, 40, 1)
var target_population: int = 10

@export_range(1, 60, 1)
var maximum_population: int = 14

@export_range(0.1, 5.0, 0.1)
var spawn_interval: float = 0.65

@export_range(4.0, 80.0, 1.0)
var minimum_spawn_radius: float = 20.0

@export_range(8.0, 140.0, 1.0)
var maximum_spawn_radius: float = 56.0

@export_range(20.0, 220.0, 1.0)
var despawn_radius: float = 94.0

@export_range(1, 32, 1)
var spawn_attempts: int = 14

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
		_spawn_one_grazer()


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D


func _spawn_one_grazer() -> void:
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
		if WorldGenerator.get_terrain_slope(world_x, world_z, 0.75) > 0.48:
			continue

		var biome: int = WorldGenerator.get_biome(world_x, world_z, height)
		if biome in [
			WorldGenerator.Biome.OCEAN,
			WorldGenerator.Biome.COAST,
			WorldGenerator.Biome.SNOW,
			WorldGenerator.Biome.ALPINE,
		]:
			continue

		var grazer := GRAZER_SCENE.instantiate() as Node3D
		if grazer == null:
			return

		# The old food props were deliberately removed. Keep founder animals
		# stable until the new ecology/food-chain layer replaces that prototype.
		grazer.set("hunger_loss_per_second", 0.03)
		grazer.set("thirst_loss_per_second", 0.04)
		grazer.set("maximum_grazer_population", maximum_population)
		grazer.set("snap_to_terrain", true)
		grazer.global_position = Vector3(
			world_x,
			WorldGenerator.get_visual_terrain_height(world_x, world_z) + 1.2,
			world_z
		)
		grazer.add_to_group(&"streamed_fauna")
		add_child(grazer)
		_active_fauna.append(grazer)
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
