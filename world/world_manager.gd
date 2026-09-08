class_name WorldManager
extends Node3D

const Horizon = preload("res://world/visuals/terrain/landscape_horizon.gd")
const WaterBuilder = preload("res://world/visuals/terrain/water_mesh_builder_v7.gd")

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
var _initial_player_physics: bool = true
var _priority_timer: float = 0.0
var _travel := Vector2.ZERO
var shared_water_bounds := Rect2()

@onready var player: Node3D = get_node_or_null(player_path) as Node3D


func _ready() -> void:
	process_priority = -10000
	add_to_group(&"world_manager")
	if player == null:
		push_error("WorldManager could not find Player at path: %s" % player_path)
		set_process(false)
		return
	# Freeze before the restore frames: a slow first rendered frame must not
	# move the default spawn enough to be mistaken for a restored save.
	_initial_player_physics = player.is_physics_processing()
	player.set_physics_process(false)
	set_process(false)
	call_deferred("_initialize_streaming")


func _initialize_streaming() -> void:
	# Give SaveGameService two idle frames to restore a persisted player before
	# selecting a new scenic spawn and before expensive terrain is generated.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or player == null or not is_instance_valid(player):
		return
	print("Surface streaming seed: ", WorldGenerator.get_world_seed())
	_maybe_choose_adventure_spawn()
	if not _read_chunk_dimensions():
		return
	current_player_chunk = _world_position_to_chunk(player.global_position)
	_create_chunk(current_player_chunk)
	var spawn_chunk: Node = loaded_chunks.get(current_player_chunk)
	if spawn_chunk != null and not bool(spawn_chunk.get("generation_complete")):
		await spawn_chunk.terrain_ready
	if not is_inside_tree() or not is_instance_valid(player):
		return
	var ground: float = WorldGenerator.get_visual_terrain_height(player.global_position.x, player.global_position.z)
	if player.global_position.y < ground + 0.65:
		player.global_position.y = ground + 2.2
	player.set_physics_process(_initial_player_physics)
	_plan_streaming()
	world_initialized = true
	var horizon := Horizon.new()
	horizon.name = "LandscapeHorizon"
	add_child(horizon)
	_stream_build_timer = chunk_build_interval
	set_process(true)


func _process(delta: float) -> void:
	if not world_initialized:
		return
	var new_player_chunk: Vector2i = _world_position_to_chunk(player.global_position)
	_priority_timer -= delta
	if new_player_chunk != current_player_chunk or _priority_timer <= 0.0:
		current_player_chunk = new_player_chunk
		_priority_timer = 0.15
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


func set_shared_water_bounds(bounds: Rect2) -> void:
	shared_water_bounds = bounds
	for chunk: Node3D in loaded_chunks.values():
		WaterBuilder.set_shared_coverage(chunk, bounds)


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
	_travel = Vector2.ZERO
	if player is CharacterBody3D:
		_travel = Vector2(player.velocity.x, player.velocity.z)

	var candidates: Array[Vector2i] = []
	for offset_z in range(-render_distance, render_distance + 1):
		for offset_x in range(-render_distance, render_distance + 1):
			var coordinates := current_player_chunk + Vector2i(offset_x, offset_z)
			_stream_required_chunks[coordinates] = true
			if not loaded_chunks.has(coordinates):
				candidates.append(coordinates)
	# One extra strip in the direction of travel, while retaining the complete
	# surrounding square. Turning reprioritizes within 150 ms, before crossing.
	if _travel.length_squared() > 0.1 and render_distance > 0:
		var direction := Vector2i(signi(roundi(_travel.x)), signi(roundi(_travel.y)))
		var future := current_player_chunk + direction
		for z in range(-render_distance, render_distance + 1):
			for x in range(-render_distance, render_distance + 1):
				var key := future + Vector2i(x, z)
				if not _stream_required_chunks.has(key):
					_stream_required_chunks[key] = true
					if not loaded_chunks.has(key):
						candidates.append(key)
	candidates.sort_custom(_is_chunk_higher_priority)
	_stream_pending_chunks = candidates
	var active: Array = loaded_chunks.keys()
	active.sort_custom(_is_chunk_higher_priority)
	for index in range(active.size()):
		var chunk: Node = loaded_chunks[active[index]]
		chunk.process_priority = -9000 + index
		chunk.get_node("ProceduralEcosystemV6").process_priority = -8000 + index
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
	var score_a: float = _chunk_priority(a)
	var score_b: float = _chunk_priority(b)
	if not is_equal_approx(score_a, score_b):
		return score_a < score_b
	return a.y < b.y if a.y != b.y else a.x < b.x


func _chunk_priority(coordinates: Vector2i) -> float:
	var point := Vector2(player.global_position.x, player.global_position.z)
	var center := Vector2(coordinates.x * chunk_width, coordinates.y * chunk_depth)
	var edge: Vector2 = (center - point).abs() - Vector2(chunk_width, chunk_depth) * 0.5
	var distance: float = Vector2(maxf(edge.x, 0.0), maxf(edge.y, 0.0)).length()
	# Immediate collision neighbours take precedence over any distant lookahead.
	if distance < 12.0:
		return distance - 1000.0
	var predicted: Vector2 = point + _travel.limit_length(10.0) * 3.0
	return distance * 0.35 + center.distance_to(predicted) * 0.65


func _unload_distant_chunks() -> void:
	var keep_distance: int = render_distance + maxi(unload_hysteresis, 0)
	var chunks_to_remove: Array[Vector2i] = []
	for coordinates_value in loaded_chunks.keys():
		var coordinates: Vector2i = coordinates_value
		var delta: Vector2i = coordinates - current_player_chunk
		var distance: int = maxi(absi(delta.x), absi(delta.y))
		var chunk: Node3D = loaded_chunks[coordinates]
		chunk.terrain_retiring = distance > keep_distance and not _stream_required_chunks.has(coordinates)
		if chunk.terrain_retiring and chunk.terrain_presence <= 0.0:
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
	# Store coverage before generation/visual callbacks, even for synchronous
	# chunks. Local meshes remain available for surface teardown and teleports.
	WaterBuilder.set_shared_coverage(chunk, shared_water_bounds)
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
