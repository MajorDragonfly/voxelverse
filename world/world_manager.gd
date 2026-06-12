class_name WorldManager
extends Node3D


const TERRAIN_CHUNK_SCENE: PackedScene = preload(
	"res://world/resources/terrain/terrain_chunk.tscn"
)


@export_category("World Generation")
@export_range(0, 4, 1) var initial_chunk_radius: int = 1

var loaded_chunks: Dictionary = {}


func _ready() -> void:
	generate_initial_world()


func generate_initial_world() -> void:
	for chunk_z in range(
		-initial_chunk_radius,
		initial_chunk_radius + 1
	):
		for chunk_x in range(
			-initial_chunk_radius,
			initial_chunk_radius + 1
		):
			var coordinates := Vector2i(
				chunk_x,
				chunk_z
			)

			_create_chunk(coordinates)


func _create_chunk(coordinates: Vector2i) -> void:
	if loaded_chunks.has(coordinates):
		return

	var chunk := (
		TERRAIN_CHUNK_SCENE.instantiate()
		as TerrainChunk
	)

	if chunk == null:
		push_error(
			"TerrainChunk scene could not be instantiated."
		)
		return

	chunk.chunk_coordinates = coordinates
	chunk.name = "TerrainChunk_%d_%d" % [
		coordinates.x,
		coordinates.y,
	]

	add_child(chunk)

	loaded_chunks[coordinates] = chunk
