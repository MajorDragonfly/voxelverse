extends "res://world/visuals/terrain/terrain_chunk_visuals.gd"

@export_category("Layered Terrain V7")
@export_range(0.03125, 0.50, 0.03125) var micro_tile_size: float = 0.125
@export_range(8.0, 128.0, 1.0) var near_detail_end: float = 44.0
@export_range(16.0, 192.0, 1.0) var mid_detail_end: float = 82.0
@export_range(0.0, 0.35, 0.01) var micro_detail_strength: float = 0.13
@export_range(0.0, 0.20, 0.01) var mid_detail_strength: float = 0.055

@export_category("Water V7")
@export var foam_color: Color = Color(0.70, 0.90, 0.92, 1.0)
@export_range(0.05, 4.0, 0.05) var foam_distance: float = 0.90
@export_range(0.25, 12.0, 0.25) var depth_fade_distance: float = 4.5
@export_range(0.0, 0.20, 0.005) var refraction_strength: float = 0.025


func _apply_terrain_material(terrain_mesh: MeshInstance3D) -> void:
	super._apply_terrain_material(terrain_mesh)
	var material := terrain_mesh.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(&"micro_tile_size", micro_tile_size)
	material.set_shader_parameter(&"near_detail_end", near_detail_end)
	material.set_shader_parameter(&"mid_detail_end", maxf(mid_detail_end, near_detail_end + 1.0))
	material.set_shader_parameter(
		&"micro_detail_strength",
		micro_detail_strength
	)
	material.set_shader_parameter(&"mid_detail_strength", mid_detail_strength)


func _apply_water_material(
	chunk: Node,
	water_mesh: MeshInstance3D
) -> void:
	super._apply_water_material(chunk, water_mesh)
	var material := water_mesh.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(&"foam_color", foam_color)
	material.set_shader_parameter(&"foam_distance", foam_distance)
	material.set_shader_parameter(&"depth_fade_distance", depth_fade_distance)
	material.set_shader_parameter(&"refraction_strength", refraction_strength)
