extends RefCounted
class_name TerrainFarMeshJobV7

# The job receives only value data. It never touches Nodes, RenderingServer or
# WorldGenerator from the worker thread. The resulting mesh arrays are consumed
# on the main thread by TerrainChunkV7.

var _input: Dictionary
var _result: Dictionary = {}
var _result_mutex := Mutex.new()


func _init(input_data: Dictionary) -> void:
	_input = input_data.duplicate(true)


func run() -> void:
	var built_result: Dictionary = _build_arrays(_input)
	_result_mutex.lock()
	_result = built_result
	_result_mutex.unlock()


func get_result() -> Dictionary:
	_result_mutex.lock()
	var copy: Dictionary = _result.duplicate(true)
	_result_mutex.unlock()
	return copy


static func _build_arrays(data: Dictionary) -> Dictionary:
	var columns: int = maxi(int(data.get("columns", 0)), 2)
	var rows: int = maxi(int(data.get("rows", 0)), 2)
	var local_x_values: PackedFloat32Array = data.get(
		"local_x_values",
		PackedFloat32Array()
	)
	var local_z_values: PackedFloat32Array = data.get(
		"local_z_values",
		PackedFloat32Array()
	)
	var heights: PackedFloat32Array = data.get(
		"heights",
		PackedFloat32Array()
	)
	var colors: PackedColorArray = data.get(
		"colors",
		PackedColorArray()
	)
	if (
		local_x_values.size() != columns
		or local_z_values.size() != rows
		or heights.size() != columns * rows
		or colors.size() != columns * rows
	):
		return {}

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(columns * rows)
	normals.resize(columns * rows)
	uvs.resize(columns * rows)

	for row in range(rows):
		for column in range(columns):
			var index: int = row * columns + column
			vertices[index] = Vector3(
				local_x_values[column],
				heights[index],
				local_z_values[row]
			)
			uvs[index] = Vector2(
				float(column) / float(columns - 1),
				float(row) / float(rows - 1)
			)

	for row in range(rows):
		for column in range(columns):
			var index: int = row * columns + column
			var left_column: int = maxi(column - 1, 0)
			var right_column: int = mini(column + 1, columns - 1)
			var north_row: int = maxi(row - 1, 0)
			var south_row: int = mini(row + 1, rows - 1)
			var left_index: int = row * columns + left_column
			var right_index: int = row * columns + right_column
			var north_index: int = north_row * columns + column
			var south_index: int = south_row * columns + column
			var tangent_x: Vector3 = vertices[right_index] - vertices[left_index]
			var tangent_z: Vector3 = vertices[south_index] - vertices[north_index]
			var normal: Vector3 = tangent_z.cross(tangent_x).normalized()
			if normal.y < 0.0:
				normal = -normal
			normals[index] = normal

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
	return {
		"arrays": arrays,
		"vertex_count": vertices.size(),
		"triangle_count": indices.size() / 3,
	}
