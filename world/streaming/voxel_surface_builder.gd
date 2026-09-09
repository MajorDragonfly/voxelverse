extends RefCounted

# Every LOD is a field of flat columns with vertical risers. Each height carries
# three endpoints (playable, horizon, proxy). Emit a riser if ANY endpoint needs
# it, including walls that start collapsed. This keeps the morph watertight.
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _targets := PackedVector2Array()
var _indices := PackedInt32Array()

func build(size: Vector2, step: float, heights: PackedVector3Array, colors: PackedColorArray) -> Array:
	var columns: int = roundi(size.x / step)
	var rows: int = roundi(size.y / step)
	var stride: int = columns + 2
	for z in range(rows):
		for x in range(columns):
			var index: int = (z + 1) * stride + x + 1
			var own: Vector3 = heights[index]
			var color: Color = colors[index]
			var a := Vector2(x * step - size.x * 0.5, z * step - size.y * 0.5)
			var b: Vector2 = a + Vector2(0, step)
			var c: Vector2 = a + Vector2(step, step)
			var d: Vector2 = a + Vector2(step, 0)
			_quad([a, b, c, d], [own, own, own, own], Vector3.UP, color)
			_wall(b, a, own, heights[index - 1], Vector3.LEFT, color)
			_wall(d, c, own, heights[index + 1], Vector3.RIGHT, color)
			_wall(a, d, own, heights[index - stride], Vector3.FORWARD, color)
			_wall(c, b, own, heights[index + stride], Vector3.BACK, color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV2] = _targets
	arrays[Mesh.ARRAY_INDEX] = _indices
	return arrays

func _wall(a: Vector2, b: Vector2, own: Vector3, neighbor: Vector3, normal: Vector3, color: Color) -> void:
	if own.x <= neighbor.x and own.y <= neighbor.y and own.z <= neighbor.z:
		return
	var low := Vector3(minf(own.x, neighbor.x), minf(own.y, neighbor.y), minf(own.z, neighbor.z))
	_quad([a, a, b, b], [low, own, own, low], normal, color.darkened(0.16))

func _quad(points: Array, levels: Array, normal: Vector3, color: Color) -> void:
	var start: int = _vertices.size()
	for i in range(4):
		var point: Vector2 = points[i]
		var level: Vector3 = levels[i]
		_vertices.append(Vector3(point.x, level.x, point.y))
		_normals.append(normal)
		_colors.append(color)
		_targets.append(Vector2(level.y, level.z))
	# The same clockwise winding also holds for a temporarily collapsed wall.
	_indices.append_array(PackedInt32Array([start, start + 2, start + 1, start, start + 3, start + 2]))
