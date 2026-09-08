extends RefCounted

const Style = preload("res://world/visuals/terrain/water_surface_style.gd")
const NEAR_RADIUS: float = 128.0
const NEAR_STEP: float = 2.0
const FAR_STEP: float = 8.0

# One indexed surface: the nonuniform grid shares every edge, including the
# 2 m / 8 m transitions. No overlapping transparent tiles or T-junctions.
# Called by the horizon worker, using its private generator and value arrays.
static func build(generator: Node, center: Vector2, radius: float) -> Array:
	var axis: PackedFloat32Array = axis_values(radius)
	var side: int = axis.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(side * side)
	normals.resize(side * side)
	normals.fill(Vector3.UP)
	colors.resize(side * side)
	var style_cache: Dictionary = {}
	for z in range(side):
		for x in range(side):
			var point: Vector2 = center + Vector2(axis[x], axis[z])
			var index: int = z * side + x
			var level: float = generator.get_water_level(point.x, point.y) if generator.has_method("get_water_level") else generator.get_sea_level()
			vertices[index] = Vector3(point.x, level + 0.03, point.y)
			colors[index] = Style.vertex_color(generator, point, style_cache)
			if x < side - 1 and z < side - 1:
				indices.append_array(PackedInt32Array([index, index + side + 1, index + side, index, index + 1, index + side + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

static func axis_values(radius: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var value: float = -radius
	while value < radius - 0.001:
		result.append(value)
		var step: float = NEAR_STEP if value >= -NEAR_RADIUS and value < NEAR_RADIUS else FAR_STEP
		value = minf(value + step, radius)
	result.append(radius)
	return result
