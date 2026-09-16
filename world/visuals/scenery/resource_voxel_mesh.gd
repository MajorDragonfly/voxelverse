extends RefCounted
## Small native resource meshes. Occupied cells share a grid; only exposed faces
## are emitted. No per-voxel Nodes, hidden internal faces or unbounded mesh cache.
const DIRECTIONS: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const CORNERS: Array = [
	[Vector3(1,-1,-1), Vector3(1,1,-1), Vector3(1,1,1), Vector3(1,-1,1)],
	[Vector3(-1,-1,1), Vector3(-1,1,1), Vector3(-1,1,-1), Vector3(-1,-1,-1)],
	[Vector3(-1,1,-1), Vector3(-1,1,1), Vector3(1,1,1), Vector3(1,1,-1)],
	[Vector3(-1,-1,1), Vector3(-1,-1,-1), Vector3(1,-1,-1), Vector3(1,-1,1)],
	[Vector3(1,-1,1), Vector3(1,1,1), Vector3(-1,1,1), Vector3(-1,-1,1)],
	[Vector3(-1,-1,-1), Vector3(-1,1,-1), Vector3(1,1,-1), Vector3(1,-1,-1)],
]
static var _material: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.94
	return _material

static func line(cells: Dictionary, start: Vector3, end: Vector3, cell: Vector3, color: Color) -> void:
	var steps: int = maxi(1, ceili(((end - start) / cell).length() * 2.0))
	for i in range(steps + 1):
		cells[Vector3i((start.lerp(end, float(i) / steps) / cell).round())] = color

static func build(cells: Dictionary, cell: Vector3) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for key: Vector3i in cells:
		var center: Vector3 = Vector3(key) * cell
		for side in range(6):
			if cells.has(key + DIRECTIONS[side]): continue
			var offset: int = vertices.size()
			for corner: Vector3 in CORNERS[side]:
				vertices.append(center + corner * cell * 0.5)
				normals.append(Vector3(DIRECTIONS[side]))
				colors.append(cells[key])
			# Clockwise front faces, matching Godot's native primitive meshes.
			for index in [0, 2, 1, 0, 3, 2]: indices.append(offset + index)
	var mesh := ArrayMesh.new()
	if vertices.is_empty(): return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh
