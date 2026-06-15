extends Node


const TERRAIN_SHADER: Shader = preload(
	"res://world/visuals/terrain/terrain_surface.gdshader"
)

const OCEAN_SHADER: Shader = preload(
	"res://world/visuals/terrain/ocean_surface.gdshader"
)

const GRASS_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/grass_01.png"
)

const DIRT_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/dirt_01.png"
)

const SAND_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/sand_01.png"
)

const STONE_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/stone_01.png"
)


@export_category("Visual Systems")

@export
var enable_terrain_shader: bool = true

@export
var enable_water_shader: bool = true


@export_category("Terrain Pixel Material")

@export_range(
	2,
	8,
	1
)
var terrain_palette_steps: int = 4

@export_range(
	0.05,
	4.0,
	0.05
)
var top_texture_scale: float = 0.50

@export_range(
	0.05,
	4.0,
	0.05
)
var side_texture_scale: float = 0.50

@export_range(
	0.20,
	1.00,
	0.01
)
var texture_darkness: float = 0.58

@export_range(
	0.80,
	1.50,
	0.01
)
var texture_brightness: float = 1.22


@export_category("Planet Compatibility")

@export
var spherical_planet: bool = false

@export
var planet_center: Vector3 = Vector3.ZERO

@export_range(
	100.0,
	1_000_000.0,
	100.0
)
var planet_radius: float = 10_000.0


@export_category("Terrain")

@export
var rock_color: Color = Color(
	0.36,
	0.27,
	0.20,
	1.0
)

@export
var rock_strata_color: Color = Color(
	0.50,
	0.35,
	0.23,
	1.0
)

@export
var wet_ground_color: Color = Color(
	0.10,
	0.17,
	0.13,
	1.0
)

@export
var snow_color: Color = Color(
	0.72,
	0.78,
	0.79,
	1.0
)

@export_range(
	0.0,
	1.0,
	0.01
)
var rock_slope_start: float = 0.28

@export_range(
	0.0,
	1.0,
	0.01
)
var rock_slope_end: float = 0.62

@export_range(
	0.0,
	1.0,
	0.01
)
var macro_color_strength: float = 0.16

@export_range(
	0.0,
	1.0,
	0.01
)
var strata_strength: float = 0.18

@export_range(
	-20.0,
	100.0,
	0.1
)
var snow_start_altitude: float = 4.8

@export_range(
	-20.0,
	100.0,
	0.1
)
var snow_end_altitude: float = 6.5


@export_category("Water")

@export_range(
	4,
	64,
	1
)
var water_subdivisions: int = 32

@export
var deep_water_color: Color = Color(
	0.015,
	0.14,
	0.25,
	0.82
)

@export
var shallow_water_color: Color = Color(
	0.035,
	0.36,
	0.46,
	0.68
)

@export
var water_reflection_tint: Color = Color(
	0.55,
	0.78,
	0.88,
	1.0
)

@export_range(
	0.0,
	0.5,
	0.01
)
var wave_height: float = 0.12

@export_range(
	0.0,
	3.0,
	0.05
)
var wave_speed: float = 0.70

@export_range(
	0.01,
	1.0,
	0.01
)
var wave_scale: float = 0.14

@export_range(
	0.0,
	0.25,
	0.005
)
var secondary_wave_height: float = 0.045

@export_range(
	0.0,
	3.0,
	0.05
)
var secondary_wave_speed: float = 1.10

@export_range(
	0.01,
	1.0,
	0.01
)
var secondary_wave_scale: float = 0.31

@export_range(
	0.0,
	1.0,
	0.01
)
var water_roughness: float = 0.12

@export_range(
	0.0,
	1.0,
	0.01
)
var water_specular: float = 0.85


var _application_attempts: int = 0


func _ready() -> void:
	call_deferred(
		"_apply_visuals_when_ready"
	)


func _apply_visuals_when_ready() -> void:
	var chunk: Node = get_parent()

	if chunk == null:
		return

	var terrain_mesh := (
		chunk.get_node_or_null(
			"TerrainMesh"
		) as MeshInstance3D
	)

	var water_mesh := (
		chunk.get_node_or_null(
			"WaterMesh"
		) as MeshInstance3D
	)

	if (
		terrain_mesh == null
		or water_mesh == null
	):
		push_error(
			"Terrain visual controller could not find "
			+ "the terrain or water mesh."
		)
		return

	if (
		terrain_mesh.mesh == null
		or water_mesh.mesh == null
	):
		_application_attempts += 1

		if _application_attempts > 10:
			push_error(
				"Terrain visuals could not be applied "
				+ "because chunk generation did not finish."
			)
			return

		await get_tree().process_frame

		call_deferred(
			"_apply_visuals_when_ready"
		)
		return

	if enable_terrain_shader:
		_apply_terrain_material(
			terrain_mesh
		)

	if enable_water_shader:
		_apply_water_material(
			chunk,
			water_mesh
		)


func _apply_terrain_material(
	terrain_mesh: MeshInstance3D
) -> void:
	var terrain_material := ShaderMaterial.new()

	terrain_material.shader = TERRAIN_SHADER

	terrain_material.set_shader_parameter(
		&"grass_texture",
		GRASS_TEXTURE
	)

	terrain_material.set_shader_parameter(
		&"dirt_texture",
		DIRT_TEXTURE
	)

	terrain_material.set_shader_parameter(
		&"sand_texture",
		SAND_TEXTURE
	)

	terrain_material.set_shader_parameter(
		&"stone_texture",
		STONE_TEXTURE
	)

	terrain_material.set_shader_parameter(
		&"top_texture_scale",
		maxf(
			top_texture_scale,
			0.05
		)
	)

	terrain_material.set_shader_parameter(
		&"side_texture_scale",
		maxf(
			side_texture_scale,
			0.05
		)
	)

	terrain_material.set_shader_parameter(
		&"palette_steps",
		float(
			clampi(
				terrain_palette_steps,
				2,
				8
			)
		)
	)

	terrain_material.set_shader_parameter(
		&"texture_darkness",
		clampf(
			texture_darkness,
			0.20,
			1.00
		)
	)

	terrain_material.set_shader_parameter(
		&"texture_brightness",
		clampf(
			texture_brightness,
			0.80,
			1.50
		)
	)

	terrain_material.set_shader_parameter(
		&"spherical_planet",
		spherical_planet
	)

	terrain_material.set_shader_parameter(
		&"planet_center",
		planet_center
	)

	terrain_material.set_shader_parameter(
		&"planet_radius",
		maxf(
			planet_radius,
			1.0
		)
	)

	terrain_material.set_shader_parameter(
		&"sea_level",
		WorldGenerator.get_sea_level()
	)

	terrain_material.set_shader_parameter(
		&"coast_width",
		1.0
	)

	terrain_material.set_shader_parameter(
		&"rocky_height",
		4.5
	)

	terrain_material.set_shader_parameter(
		&"rock_color",
		Vector3(
			rock_color.r,
			rock_color.g,
			rock_color.b
		)
	)

	terrain_material.set_shader_parameter(
		&"rock_strata_color",
		Vector3(
			rock_strata_color.r,
			rock_strata_color.g,
			rock_strata_color.b
		)
	)

	terrain_material.set_shader_parameter(
		&"wet_ground_color",
		Vector3(
			wet_ground_color.r,
			wet_ground_color.g,
			wet_ground_color.b
		)
	)

	terrain_material.set_shader_parameter(
		&"snow_color",
		Vector3(
			snow_color.r,
			snow_color.g,
			snow_color.b
		)
	)

	terrain_material.set_shader_parameter(
		&"rock_slope_start",
		minf(
			rock_slope_start,
			rock_slope_end
		)
	)

	terrain_material.set_shader_parameter(
		&"rock_slope_end",
		maxf(
			rock_slope_start,
			rock_slope_end
		)
	)

	terrain_material.set_shader_parameter(
		&"macro_color_strength",
		clampf(
			macro_color_strength,
			0.0,
			1.0
		)
	)

	terrain_material.set_shader_parameter(
		&"strata_strength",
		clampf(
			strata_strength,
			0.0,
			1.0
		)
	)

	terrain_material.set_shader_parameter(
		&"snow_start_altitude",
		minf(
			snow_start_altitude,
			snow_end_altitude
		)
	)

	terrain_material.set_shader_parameter(
		&"snow_end_altitude",
		maxf(
			snow_start_altitude,
			snow_end_altitude
		)
	)

	terrain_mesh.material_override = (
		terrain_material
	)


func _apply_water_material(
	chunk: Node,
	water_mesh: MeshInstance3D
) -> void:
	if not chunk.has_method(
		"get_chunk_width"
	):
		push_error(
			"Terrain chunk is missing get_chunk_width()."
		)
		return

	if not chunk.has_method(
		"get_chunk_depth"
	):
		push_error(
			"Terrain chunk is missing get_chunk_depth()."
		)
		return

	var chunk_width: float = float(
		chunk.call(
			"get_chunk_width"
		)
	)

	var chunk_depth: float = float(
		chunk.call(
			"get_chunk_depth"
		)
	)

	var water_plane := PlaneMesh.new()

	water_plane.size = Vector2(
		chunk_width,
		chunk_depth
	)

	water_plane.subdivide_width = maxi(
		water_subdivisions,
		1
	)

	water_plane.subdivide_depth = maxi(
		water_subdivisions,
		1
	)

	var water_material := ShaderMaterial.new()

	water_material.shader = OCEAN_SHADER

	water_material.set_shader_parameter(
		&"deep_color",
		deep_water_color
	)

	water_material.set_shader_parameter(
		&"shallow_color",
		shallow_water_color
	)

	water_material.set_shader_parameter(
		&"reflection_tint",
		Vector3(
			water_reflection_tint.r,
			water_reflection_tint.g,
			water_reflection_tint.b
		)
	)

	water_material.set_shader_parameter(
		&"wave_height",
		maxf(
			wave_height,
			0.0
		)
	)

	water_material.set_shader_parameter(
		&"wave_speed",
		maxf(
			wave_speed,
			0.0
		)
	)

	water_material.set_shader_parameter(
		&"wave_scale",
		maxf(
			wave_scale,
			0.001
		)
	)

	water_material.set_shader_parameter(
		&"secondary_wave_height",
		maxf(
			secondary_wave_height,
			0.0
		)
	)

	water_material.set_shader_parameter(
		&"secondary_wave_speed",
		maxf(
			secondary_wave_speed,
			0.0
		)
	)

	water_material.set_shader_parameter(
		&"secondary_wave_scale",
		maxf(
			secondary_wave_scale,
			0.001
		)
	)

	water_material.set_shader_parameter(
		&"water_roughness",
		clampf(
			water_roughness,
			0.0,
			1.0
		)
	)

	water_material.set_shader_parameter(
		&"water_specular",
		clampf(
			water_specular,
			0.0,
			1.0
		)
	)

	water_material.render_priority = 1

	water_mesh.mesh = water_plane
	water_mesh.material_override = water_material

	water_mesh.position = Vector3(
		0.0,
		WorldGenerator.get_sea_level() + 0.03,
		0.0
	)

	water_mesh.cast_shadow = (
		GeometryInstance3D
		.SHADOW_CASTING_SETTING_OFF
	)

	water_mesh.extra_cull_margin = (
		maxf(
			wave_height,
			secondary_wave_height
		)
		* 4.0
		+ 1.0
	)
