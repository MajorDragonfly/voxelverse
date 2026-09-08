extends "res://world/visuals/terrain/terrain_chunk_visuals_v7.gd"

const WaterMeshBuilder = preload(
	"res://world/visuals/terrain/water_mesh_builder_v7.gd"
)


func _apply_water_material(
	chunk: Node,
	water_mesh: MeshInstance3D
) -> void:
	WaterMeshBuilder.build(chunk, water_mesh, get_water_settings())


func get_water_settings() -> Dictionary:
	return {
		"subdivisions": water_subdivisions,
		"foam_distance": foam_distance,
		"depth_fade_distance": depth_fade_distance,
		"deep_color": deep_water_color,
		"shallow_color": shallow_water_color,
		"foam_color": foam_color,
		"wave_height": wave_height,
		"wave_speed": wave_speed,
		"wave_scale": wave_scale,
		"secondary_wave_height": secondary_wave_height,
		"secondary_wave_speed": secondary_wave_speed,
		"secondary_wave_scale": secondary_wave_scale,
		"water_roughness": water_roughness,
		"water_specular": water_specular,
		"refraction_strength": refraction_strength,
	}
