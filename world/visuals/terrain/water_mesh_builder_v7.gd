extends RefCounted
class_name WaterMeshBuilderV7

const OCEAN_SHADER: Shader = preload(
	"res://world/visuals/terrain/ocean_surface.gdshader"
)
const Style = preload("res://world/visuals/terrain/water_surface_style.gd")


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
	# Nested subdivisions preserve the common 2 m water triangles, even with
	# an inspector value such as 20. Finer wave vertices stay on that surface.
	var subdivisions: int = maxi(16, int(nearest_po2(clampi(int(settings.get("subdivisions", 24)), 4, 64))))
	var columns: int = subdivisions + 1
	var rows: int = subdivisions + 1
	var water_height: float = WorldGenerator.get_sea_level() + 0.03
	var style_cache: Dictionary = {}
	var height_cache: Dictionary = {}

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
			var point := Vector2(chunk.global_position.x + local_x, chunk.global_position.z + local_z)
			var level: float = Style.height_at(WorldGenerator, point, Vector2(2, 2), height_cache)
			vertices[index] = Vector3(local_x, level + 0.03 - water_height, local_z)
			normals[index] = Vector3.UP
			uvs[index] = Vector2(column_ratio, row_ratio)
			colors[index] = Style.vertex_color(WorldGenerator, point, style_cache)

	for row in range(rows - 1):
		for column in range(columns - 1):
			var a: int = row * columns + column
			var b: int = (row + 1) * columns + column
			var c: int = (row + 1) * columns + column + 1
			var d: int = row * columns + column + 1
			indices.append_array(PackedInt32Array([a, c, b, a, d, c]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	water_mesh.mesh = array_mesh
	water_mesh.material_override = make_material(WorldGenerator.get_planet_profile(), settings)
	water_mesh.position = Vector3(0.0, water_height, 0.0)
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_mesh.extra_cull_margin = displacement_margin(settings)
	water_mesh.set_meta("wave_margin", water_mesh.extra_cull_margin)
	if water_mesh.has_meta("joined_bounds"):
		water_mesh.remove_meta("joined_bounds")
	set_shared_coverage(chunk, chunk.get_meta(&"shared_water_bounds", Rect2()))


static func make_material(profile: Dictionary, settings: Dictionary) -> ShaderMaterial:
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
		"foam_distance",
		"depth_fade_distance",
	]:
		if settings.has(parameter_name):
			material.set_shader_parameter(
				StringName(parameter_name),
				settings[parameter_name]
			)
	var slots: Dictionary = profile.get("material_slots", {})
	for name: String in ["deep", "shallow"]:
		var parameter: String = name + "_color"
		var fallback: Color = settings.get(parameter, material.get_shader_parameter(parameter))
		var pigment: Color = slots.get("water_" + name, fallback)
		pigment.a = fallback.a
		material.set_shader_parameter(parameter, pigment)
	var horizon: Color = profile.get("atmosphere", {}).get("sky_horizon", Color(0.55, 0.78, 0.88))
	material.set_shader_parameter("reflection_tint", Vector3(horizon.r, horizon.g, horizon.b))
	material.render_priority = 1
	return material


static func displacement_margin(settings: Dictionary) -> float:
	return absf(float(settings.get("wave_height", 0.042))) + absf(float(settings.get("secondary_wave_height", 0.014))) + 1.0


static func set_shared_coverage(chunk: Node3D, bounds: Rect2) -> void:
	chunk.set_meta(&"shared_water_bounds", bounds)
	var water: MeshInstance3D = chunk.get_node("WaterMesh")
	var size := Vector2(chunk.get_chunk_width(), chunk.get_chunk_depth())
	var own_bounds := Rect2(Vector2(chunk.chunk_coordinates) * size - size * 0.5, size)
	water.visible = not bounds.has_area() or not bounds.encloses(own_bounds)
	# A teleport can leave a chunk only partially under the previous surface.
	# Clip the intersection, retain the rest until the replacement is published.
	if water.material_override is ShaderMaterial:
		var join: bool = water.visible and bounds.has_area() and bounds.grow(8.0).intersects(own_bounds)
		water.material_override.set_shader_parameter("join_shared_surface", join)
		if join and water.mesh != null:
			_align_shared_edge(chunk, water, bounds)
		water.material_override.set_shader_parameter("clip_shared_surface", bounds.has_area())
		water.material_override.set_shader_parameter("shared_surface_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))


static func _align_shared_edge(chunk: Node3D, water: MeshInstance3D, bounds: Rect2) -> void:
	if water.get_meta("joined_bounds", Rect2()) == bounds:
		return
	var arrays: Array = water.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var targets := PackedVector2Array()
	var cache: Dictionary = {}
	var margin: float = 0.0
	for vertex: Vector3 in vertices:
		var point := Vector2(chunk.position.x + vertex.x, chunk.position.z + vertex.z)
		var height: float = Style.height_at(WorldGenerator, point, Style.shared_step(point, bounds.get_center()), cache) + 0.03 - water.position.y
		targets.append(Vector2(height, 0.0))
		margin = maxf(margin, absf(height - vertex.y))
	arrays[Mesh.ARRAY_TEX_UV2] = targets
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	water.mesh = mesh
	water.extra_cull_margin = margin + float(water.get_meta("wave_margin", 1.1))
	water.set_meta("joined_bounds", bounds)
