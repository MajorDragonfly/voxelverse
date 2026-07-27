extends RefCounted
class_name WaterMeshBuilderV7

const OCEAN_SHADER: Shader = preload(
	"res://world/visuals/terrain/ocean_surface.gdshader"
)


static func build(
	chunk: Node,
	water_mesh: MeshInstance3D,
	settings: Dictionary
) -> void:
	if not chunk.has_method("get_chunk_width"):
		push_error("Terrain chunk is missing get_chunk_width().")
		return
	if not chunk.has_method("get_chunk_depth"):
		push_error("Terrain chunk is missing get_chunk_depth().")
		return

	var chunk_width: float = float(chunk.call("get_chunk_width"))
	var chunk_depth: float = float(chunk.call("get_chunk_depth"))
	var subdivisions: int = maxi(int(settings.get("subdivisions", 24)), 4)
	var columns: int = subdivisions + 1
	var rows: int = subdivisions + 1
	var depth_fade_distance: float = maxf(
		float(settings.get("depth_fade_distance", 4.5)),
		0.001
	)
	var foam_distance: float = maxf(
		float(settings.get("foam_distance", 0.90)),
		0.05
	)
	var water_height: float = WorldGenerator.get_sea_level() + 0.03

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(columns * rows)
	normals.resize(columns * rows)
	uvs.resize(columns * rows)
	colors.resize(columns * rows)

	for row in range(rows):
		var row_ratio: float = float(row) / float(rows - 1)
		var local_z: float = lerpf(
			-chunk_depth * 0.5,
			chunk_depth * 0.5,
			row_ratio
		)
		for column in range(columns):
			var column_ratio: float = float(column) / float(columns - 1)
			var local_x: float = lerpf(
				-chunk_width * 0.5,
				chunk_width * 0.5,
				column_ratio
			)
			var index: int = row * columns + column
			var world_x: float = chunk.global_position.x + local_x
			var world_z: float = chunk.global_position.z + local_z
			var terrain_height: float = WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
			var actual_depth: float = maxf(water_height - terrain_height, 0.0)
			var depth_weight: float = smoothstep(
				0.0,
				depth_fade_distance,
				actual_depth
			)
			var foam_weight: float = 1.0 - smoothstep(
				0.04,
				foam_distance,
				actual_depth
			)
			vertices[index] = Vector3(local_x, 0.0, local_z)
			normals[index] = Vector3.UP
			uvs[index] = Vector2(column_ratio, row_ratio)
			colors[index] = Color(depth_weight, foam_weight, 0.0, 1.0)

	for row in range(rows - 1):
		for column in range(columns - 1):
			var a: int = row * columns + column
			var b: int = (row + 1) * columns + column
			var c: int = (row + 1) * columns + column + 1
			var d: int = row * columns + column + 1
			indices.append_array(PackedInt32Array([a, b, c, a, c, d]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := ShaderMaterial.new()
	material.shader = OCEAN_SHADER
	for parameter_name in [
		"deep_color",
		"shallow_color",
		"reflection_tint",
		"foam_color",
		"wave_height",
		"wave_speed",
		"wave_scale",
		"secondary_wave_height",
		"secondary_wave_speed",
		"secondary_wave_scale",
		"water_roughness",
		"water_specular",
		"refraction_strength",
	]:
		if settings.has(parameter_name):
			material.set_shader_parameter(
				StringName(parameter_name),
				settings[parameter_name]
			)
	material.render_priority = 1
	water_mesh.mesh = array_mesh
	water_mesh.material_override = material
	water_mesh.position = Vector3(0.0, water_height, 0.0)
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_mesh.extra_cull_margin = (
		maxf(
			float(settings.get("wave_height", 0.05)),
			float(settings.get("secondary_wave_height", 0.02))
		) * 4.0 + 1.0
	)
