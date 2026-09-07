class_name WorldManager
extends Node3D

const AuthoredAssets = preload("res://world/visuals/scenery/authored_environment_assets.gd")

const TERRAIN_CHUNK_SCENE: PackedScene = preload(
	"res://world/visuals/terrain/terrain_chunk.tscn"
)
const AdventureSpawnSelector = preload(
	"res://world/generation/adventure_spawn_selector.gd"
)

@export_category("World Streaming")
@export_range(0, 6, 1) var render_distance: int = 2
@export_range(1, 4, 1) var chunk_create_budget_per_tick: int = 1
@export_range(0.02, 0.50, 0.01) var chunk_build_interval: float = 0.11
@export_range(0, 3, 1) var unload_hysteresis: int = 1
@export_range(1, 4, 1) var maximum_concurrent_terrain_jobs: int = 2
@export var player_path: NodePath = NodePath("../Player")

@export_category("Adventure Spawn")
@export var choose_scenic_spawn_for_default_start: bool = true
@export_range(60.0, 400.0, 10.0) var scenic_spawn_search_radius: float = 220.0

var loaded_chunks: Dictionary = {}
var current_player_chunk: Vector2i = Vector2i.ZERO
var chunk_width: float = 64.0
var chunk_depth: float = 64.0
var world_initialized: bool = false

var _stream_required_chunks: Dictionary = {}
var _stream_pending_chunks: Array[Vector2i] = []
var _stream_build_timer: float = 0.0

@onready var player: Node3D = get_node_or_null(player_path) as Node3D


func _ready() -> void:
	add_to_group(&"world_manager")
	if player == null:
		push_error("WorldManager could not find Player at path: %s" % player_path)
		set_process(false)
		return
	set_process(false)
	call_deferred("_initialize_streaming")


func _initialize_streaming() -> void:
	# Give SaveGameService two idle frames to restore a persisted player before
	# selecting a new scenic spawn and before expensive terrain is generated.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or player == null or not is_instance_valid(player):
		return
	_maybe_choose_adventure_spawn()
	if not _read_chunk_dimensions():
		return
	current_player_chunk = _world_position_to_chunk(player.global_position)
	var physics_was_enabled: bool = player.is_physics_processing()
	player.set_physics_process(false)
	_create_chunk(current_player_chunk)
	var spawn_chunk: Node = loaded_chunks.get(current_player_chunk)
	if spawn_chunk != null and not bool(spawn_chunk.get("generation_complete")):
		await spawn_chunk.terrain_ready
	if not is_inside_tree() or not is_instance_valid(player):
		return
	var ground: float = WorldGenerator.get_visual_terrain_height(player.global_position.x, player.global_position.z)
	if player.global_position.y < ground + 0.65:
		player.global_position.y = ground + 2.2
	player.set_physics_process(physics_was_enabled)
	_plan_streaming()
	world_initialized = true
	_stream_build_timer = chunk_build_interval
	set_process(true)


func _process(delta: float) -> void:
	if not world_initialized:
		return
	var new_player_chunk: Vector2i = _world_position_to_chunk(player.global_position)
	if new_player_chunk != current_player_chunk:
		current_player_chunk = new_player_chunk
		_plan_streaming()
	_stream_build_timer -= delta
	if _stream_build_timer <= 0.0:
		_stream_build_timer = maxf(chunk_build_interval, 0.02)
		_drain_chunk_queue()


func get_loaded_chunk_count() -> int:
	return loaded_chunks.size()


func get_pending_chunk_count() -> int:
	return _stream_pending_chunks.size()


func get_current_player_chunk() -> Vector2i:
	return current_player_chunk


func refresh_streaming() -> void:
	if world_initialized:
		_plan_streaming()


func _maybe_choose_adventure_spawn() -> void:
	if not choose_scenic_spawn_for_default_start:
		return
	var default_start := Vector3(0.0, 3.0, 0.0)
	if player.global_position.distance_to(default_start) > 0.75:
		return
	var generator := get_node_or_null("/root/WorldGenerator")
	if generator == null:
		return
	var spawn_position: Vector3
	if generator.has_method("get_scenic_spawn"):
		spawn_position = generator.call("get_scenic_spawn", scenic_spawn_search_radius)
	else:
		spawn_position = AdventureSpawnSelector.find_spawn(generator, Vector2.ZERO, scenic_spawn_search_radius)
	player.global_position = spawn_position


func _read_chunk_dimensions() -> bool:
	var reference_chunk := TERRAIN_CHUNK_SCENE.instantiate()
	if reference_chunk == null:
		push_error("Could not instantiate TerrainChunk scene.")
		return false
	if (
		not reference_chunk.has_method("get_chunk_width")
		or not reference_chunk.has_method("get_chunk_depth")
	):
		push_error("TerrainChunk does not contain required size methods.")
		reference_chunk.free()
		return false
	chunk_width = float(reference_chunk.call("get_chunk_width"))
	chunk_depth = float(reference_chunk.call("get_chunk_depth"))
	reference_chunk.free()
	return true


func _world_position_to_chunk(world_position: Vector3) -> Vector2i:
	var chunk_x: int = floori((world_position.x + chunk_width * 0.5) / chunk_width)
	var chunk_z: int = floori((world_position.z + chunk_depth * 0.5) / chunk_depth)
	return Vector2i(chunk_x, chunk_z)


func _plan_streaming() -> void:
	_stream_required_chunks.clear()
	var candidates: Array[Vector2i] = []
	for offset_z in range(-render_distance, render_distance + 1):
		for offset_x in range(-render_distance, render_distance + 1):
			var coordinates := current_player_chunk + Vector2i(offset_x, offset_z)
			_stream_required_chunks[coordinates] = true
			if not loaded_chunks.has(coordinates):
				candidates.append(coordinates)
	candidates.sort_custom(_is_chunk_higher_priority)
	_stream_pending_chunks = candidates
	_unload_distant_chunks()


func _drain_chunk_queue() -> void:
	var remaining_budget: int = maxi(chunk_create_budget_per_tick, 1)
	var running_jobs: int = 0
	for chunk: Node in loaded_chunks.values():
		if not bool(chunk.get("generation_complete")):
			running_jobs += 1
	remaining_budget = mini(remaining_budget, maxi(maximum_concurrent_terrain_jobs - running_jobs, 0))
	while remaining_budget > 0 and not _stream_pending_chunks.is_empty():
		var coordinates: Vector2i = _stream_pending_chunks.pop_front()
		if _stream_required_chunks.has(coordinates) and not loaded_chunks.has(coordinates):
			_create_chunk(coordinates)
			remaining_budget -= 1


func _is_chunk_higher_priority(a: Vector2i, b: Vector2i) -> bool:
	var delta_a: Vector2i = a - current_player_chunk
	var delta_b: Vector2i = b - current_player_chunk
	var chebyshev_a: int = maxi(absi(delta_a.x), absi(delta_a.y))
	var chebyshev_b: int = maxi(absi(delta_b.x), absi(delta_b.y))
	if chebyshev_a != chebyshev_b:
		return chebyshev_a < chebyshev_b
	var velocity_3d: Vector3 = Vector3.ZERO
	if player is CharacterBody3D:
		velocity_3d = (player as CharacterBody3D).velocity
	var travel := Vector2(velocity_3d.x, velocity_3d.z)
	if travel.length_squared() > 0.10:
		travel = travel.normalized()
		var direction_a := Vector2(delta_a.x, delta_a.y)
		var direction_b := Vector2(delta_b.x, delta_b.y)
		var score_a: float = 0.0
		var score_b: float = 0.0
		if direction_a.length_squared() > 0.0:
			score_a = direction_a.normalized().dot(travel)
		if direction_b.length_squared() > 0.0:
			score_b = direction_b.normalized().dot(travel)
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
	var manhattan_a: int = absi(delta_a.x) + absi(delta_a.y)
	var manhattan_b: int = absi(delta_b.x) + absi(delta_b.y)
	return manhattan_a < manhattan_b


func _unload_distant_chunks() -> void:
	var keep_distance: int = render_distance + maxi(unload_hysteresis, 0)
	var chunks_to_remove: Array[Vector2i] = []
	for coordinates_value in loaded_chunks.keys():
		var coordinates: Vector2i = coordinates_value
		var delta: Vector2i = coordinates - current_player_chunk
		var distance: int = maxi(absi(delta.x), absi(delta.y))
		if distance > keep_distance:
			chunks_to_remove.append(coordinates)
	for coordinates in chunks_to_remove:
		_remove_chunk(coordinates)


func _create_chunk(coordinates: Vector2i) -> void:
	if loaded_chunks.has(coordinates):
		return
	var chunk := TERRAIN_CHUNK_SCENE.instantiate()
	if chunk == null:
		push_error("TerrainChunk scene could not be instantiated.")
		return
	chunk.set("chunk_coordinates", coordinates)
	chunk.name = "TerrainChunk_%d_%d" % [coordinates.x, coordinates.y]
	add_child(chunk)
	loaded_chunks[coordinates] = chunk


func _remove_chunk(coordinates: Vector2i) -> void:
	if not loaded_chunks.has(coordinates):
		return
	var chunk: Variant = loaded_chunks.get(coordinates)
	if is_instance_valid(chunk):
		chunk.queue_free()
	loaded_chunks.erase(coordinates)


func _exit_tree() -> void:
	AuthoredAssets.finish_pending_loads()
