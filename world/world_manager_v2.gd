extends "res://world/world_manager.gd"

@export_category("Staged Generation")
@export_range(1, 4, 1)
var chunks_generated_per_frame: int = 1

@export_range(0, 2, 1)
var unload_hysteresis_chunks: int = 1

var _chunk_generation_queue: Array[Vector2i] = []
var _queued_chunks: Dictionary = {}
var _required_chunks: Dictionary = {}


func _process(delta: float) -> void:
	super._process(delta)
	_process_chunk_generation_queue()


func _refresh_loaded_chunks() -> void:
	_required_chunks.clear()
	var coordinates_to_queue: Array[Vector2i] = []

	for offset_z in range(-render_distance, render_distance + 1):
		for offset_x in range(-render_distance, render_distance + 1):
			var coordinates := current_player_chunk + Vector2i(offset_x, offset_z)
			_required_chunks[coordinates] = true

			if loaded_chunks.has(coordinates) or _queued_chunks.has(coordinates):
				continue

			coordinates_to_queue.append(coordinates)

	coordinates_to_queue.sort_custom(_is_chunk_nearer_to_player)

	# The center chunk is generated immediately so the player always receives
	# collision before surrounding scenery is streamed over later frames.
	if not loaded_chunks.has(current_player_chunk):
		_create_chunk(current_player_chunk)
		_queued_chunks.erase(current_player_chunk)
		coordinates_to_queue.erase(current_player_chunk)

	for coordinates in coordinates_to_queue:
		_chunk_generation_queue.append(coordinates)
		_queued_chunks[coordinates] = true

	_remove_distant_chunks()
	_prune_generation_queue()


func _process_chunk_generation_queue() -> void:
	var generation_budget: int = chunks_generated_per_frame

	while generation_budget > 0 and not _chunk_generation_queue.is_empty():
		var coordinates: Vector2i = _chunk_generation_queue.pop_front()
		_queued_chunks.erase(coordinates)

		if _required_chunks.has(coordinates) and not loaded_chunks.has(coordinates):
			_create_chunk(coordinates)
			generation_budget -= 1


func _remove_distant_chunks() -> void:
	var chunks_to_remove: Array[Vector2i] = []
	var keep_distance: int = render_distance + unload_hysteresis_chunks

	for coordinates_value in loaded_chunks.keys():
		var coordinates: Vector2i = coordinates_value
		var delta: Vector2i = coordinates - current_player_chunk

		if absi(delta.x) > keep_distance or absi(delta.y) > keep_distance:
			chunks_to_remove.append(coordinates)

	for coordinates in chunks_to_remove:
		_remove_chunk(coordinates)


func _prune_generation_queue() -> void:
	var retained_queue: Array[Vector2i] = []
	var retained_lookup: Dictionary = {}

	for coordinates in _chunk_generation_queue:
		if not _required_chunks.has(coordinates):
			continue
		if loaded_chunks.has(coordinates):
			continue
		if retained_lookup.has(coordinates):
			continue

		retained_queue.append(coordinates)
		retained_lookup[coordinates] = true

	_chunk_generation_queue = retained_queue
	_queued_chunks = retained_lookup


func _is_chunk_nearer_to_player(a: Vector2i, b: Vector2i) -> bool:
	var distance_a: int = (a - current_player_chunk).length_squared()
	var distance_b: int = (b - current_player_chunk).length_squared()
	return distance_a < distance_b
