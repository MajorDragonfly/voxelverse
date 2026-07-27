extends "res://world/visuals/terrain/terrain_chunk_visuals_v7.gd"

const WaterMeshBuilder = preload(
	"res://world/visuals/terrain/water_mesh_builder_v7.gd"
)


func _apply_water_material(
	chunk: Node,
	water_mesh: MeshInstance3D
) -> void:
	WaterMeshBuilder.build(chunk, water_mesh, {
		"subdivisions": water_subdivisions,
		"foam_distance": foam_distance,
		"depth_fade_distance": depth_fade_distance,
	})
