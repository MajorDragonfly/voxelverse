class_name WorldManager
extends Node3D


# Alle Chunks verwenden jetzt dieselbe visuelle Szene.
#
# Diese Szene enthält:
# - TerrainMesh
# - TerrainCollision
# - WaterMesh
# - Objects
# - Visuals
# - ScenicDressing
const TERRAIN_CHUNK_SCENE: PackedScene = preload(
	"res://world/visuals/terrain/terrain_chunk.tscn"
)


@export_category("World Streaming")

@export_range(0, 4, 1)
var render_distance: int = 1

@export
var player_path: NodePath = NodePath(
	"../Player"
)


var loaded_chunks: Dictionary = {}

var current_player_chunk: Vector2i = (
	Vector2i.ZERO
)

var chunk_width: float = 64.0
var chunk_depth: float = 64.0

var world_initialized: bool = false


@onready var player: Node3D = (
	get_node_or_null(
		player_path
	) as Node3D
)


func _ready() -> void:
	if player == null:
		push_error(
			"WorldManager could not find the Player at path: %s"
			% player_path
		)

		set_process(false)
		return

	if not _read_chunk_dimensions():
		set_process(false)
		return

	current_player_chunk = (
		_world_position_to_chunk(
			player.global_position
		)
	)

	_refresh_loaded_chunks()

	world_initialized = true

	print(
		"World initialized around chunk: ",
		current_player_chunk
	)


func _process(
	_delta: float
) -> void:
	if not world_initialized:
		return

	var new_player_chunk := (
		_world_position_to_chunk(
			player.global_position
		)
	)

	if (
		new_player_chunk
		== current_player_chunk
	):
		return

	current_player_chunk = new_player_chunk

	print(
		"Player entered chunk: ",
		current_player_chunk
	)

	_refresh_loaded_chunks()


func _read_chunk_dimensions() -> bool:
	var reference_chunk := (
		TERRAIN_CHUNK_SCENE.instantiate()
	)

	if reference_chunk == null:
		push_error(
			"Could not instantiate TerrainChunk scene."
		)

		return false

	if (
		not reference_chunk.has_method(
			"get_chunk_width"
		)
		or not reference_chunk.has_method(
			"get_chunk_depth"
		)
	):
		push_error(
			"TerrainChunk does not contain the required size methods."
		)

		reference_chunk.free()
		return false

	chunk_width = float(
		reference_chunk.call(
			"get_chunk_width"
		)
	)

	chunk_depth = float(
		reference_chunk.call(
			"get_chunk_depth"
		)
	)

	reference_chunk.free()

	return true


func _world_position_to_chunk(
	world_position: Vector3
) -> Vector2i:
	var chunk_x := int(
		floor(
			(
				world_position.x
				+ chunk_width * 0.5
			)
			/ chunk_width
		)
	)

	var chunk_z := int(
		floor(
			(
				world_position.z
				+ chunk_depth * 0.5
			)
			/ chunk_depth
		)
	)

	return Vector2i(
		chunk_x,
		chunk_z
	)


func _refresh_loaded_chunks() -> void:
	var required_chunks: Dictionary = {}

	for offset_z in range(
		-render_distance,
		render_distance + 1
	):
		for offset_x in range(
			-render_distance,
			render_distance + 1
		):
			var coordinates := (
				current_player_chunk
				+ Vector2i(
					offset_x,
					offset_z
				)
			)

			required_chunks[
				coordinates
			] = true

			_create_chunk(
				coordinates
			)

	var chunks_to_remove: Array[Vector2i] = []

	for coordinates: Vector2i in loaded_chunks.keys():
		if not required_chunks.has(
			coordinates
		):
			chunks_to_remove.append(
				coordinates
			)

	for coordinates: Vector2i in chunks_to_remove:
		_remove_chunk(
			coordinates
		)


func _create_chunk(
	coordinates: Vector2i
) -> void:
	if loaded_chunks.has(
		coordinates
	):
		return

	var chunk := (
		TERRAIN_CHUNK_SCENE.instantiate()
	)

	if chunk == null:
		push_error(
			"TerrainChunk scene could not be instantiated."
		)

		return

	# Die Koordinaten müssen vor add_child()
	# gesetzt werden, weil der Chunk sie bereits
	# in seiner _ready()-Funktion benötigt.
	chunk.set(
		"chunk_coordinates",
		coordinates
	)

	chunk.name = (
		"TerrainChunk_%d_%d"
		% [
			coordinates.x,
			coordinates.y
		]
	)

	add_child(
		chunk
	)

	loaded_chunks[
		coordinates
	] = chunk


func _remove_chunk(
	coordinates: Vector2i
) -> void:
	if not loaded_chunks.has(
		coordinates
	):
		return

	var chunk = loaded_chunks.get(
		coordinates
	)

	if is_instance_valid(
		chunk
	):
		chunk.queue_free()

	loaded_chunks.erase(
		coordinates
	)
