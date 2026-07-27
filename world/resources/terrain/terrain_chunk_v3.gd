extends "res://world/resources/terrain/terrain_chunk_v2.gd"

# Runtime V3 owns environmental dressing through a compact MultiMesh ecosystem.
# Legacy tree, berry-bush and grazer placement is disabled here to avoid duplicate
# populations, excessive nodes and prototype gameplay objects in every chunk.

func _get_tree_spawn_probability(_biome: int) -> float:
	return 0.0


func _get_bush_spawn_probability(_biome: int) -> float:
	return 0.0


func _get_grazer_spawn_probability(_biome: int) -> float:
	return 0.0
