extends RefCounted

## Radial voxel columns: one terraced top per cell, actual vertical side
## faces, and the shared stitched perimeter as the outermost cell boundary.
## The water mesh and distant hierarchy keep their common spherical surface.
const Cube = preload("res://world/space/cube_sphere.gd")
const CELLS: int = 16
const STRIDE: int = 17
const HEIGHT_STEP: float = 0.5
const MAX_CELL_WIDTH: float = 8.0
var vertices: PackedVector3Array
var normals: PackedVector3Array
var colors: PackedColorArray
var indices := PackedInt32Array()


func build(tile: Dictionary, surface: RefCounted, seam_arrays: Array) -> Array:
	# Keep the canonical boundary samples addressable for seam checks; render
	# indices below refer only to the real column tops/walls, never an overlay.
	vertices = (seam_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	normals = (seam_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	colors = (seam_arrays[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
	var tops: Array[PackedVector3Array] = []
	var heights: Array[float] = []
	var pigments: Array[Color] = []
	var directions: Array[Vector3] = []
	for y in range(CELLS):
		for x in range(CELLS):
			var center: Vector2 = tile.uv + Vector2(x + 0.5, y + 0.5) * (float(tile.width) / CELLS)
			var precise: Array = Cube.direction(tile.face, center.x, center.y)
			var direction: Vector3 = Cube.vector(precise)
			var height: float = snappedf(surface.height_precise(precise), HEIGHT_STEP)
			var pigment: Color = surface.color_at(direction, height)
			var hash_value: int = absi((tile.x * CELLS + x) * 73856093 ^ (tile.y * CELLS + y) * 19349663 ^ tile.face * 83492791)
			pigment = pigment.darkened(float(hash_value % 5) * 0.012)
			var top := PackedVector3Array()
			for corner: Vector2i in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)]:
				if corner.x == 0 or corner.y == 0 or corner.x == CELLS or corner.y == CELLS:
					top.append(vertices[corner.y * STRIDE + corner.x])
				else:
					var uv: Vector2 = tile.uv + Vector2(corner) * (float(tile.width) / CELLS)
					var address: Dictionary = Cube.address(surface.body.id, tile.face, uv.x, uv.y, height)
					top.append(Cube.local_position(Cube.cartesian(address, surface.body.radius), tile.anchor))
			tops.append(top)
			heights.append(height)
			pigments.append(pigment)
			directions.append(direction)
			_quad(top, pigment, direction)
	for y in range(CELLS):
		for x in range(CELLS):
			var i: int = y * CELLS + x
			if x < CELLS - 1:
				_wall(tops[i], tops[i + 1], [1, 2, 0, 3], pigments[i], directions[i + 1] - directions[i], heights[i] - heights[i + 1])
			if y < CELLS - 1:
				_wall(tops[i], tops[i + CELLS], [3, 2, 0, 1], pigments[i], directions[i + CELLS] - directions[i], heights[i] - heights[i + CELLS])
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = vertices
	result[Mesh.ARRAY_NORMAL] = normals
	result[Mesh.ARRAY_COLOR] = colors
	result[Mesh.ARRAY_INDEX] = indices
	return result


func _wall(a: PackedVector3Array, b: PackedVector3Array, edge: Array, pigment: Color, outward: Vector3, difference: float) -> void:
	if absf(difference) < 0.001:
		return
	_quad(PackedVector3Array([a[edge[0]], a[edge[1]], b[edge[3]], b[edge[2]]]), pigment.darkened(0.16), outward * signf(difference))


func _quad(points: PackedVector3Array, pigment: Color, outward: Vector3) -> void:
	var normal: Vector3 = (points[2] - points[0]).cross(points[1] - points[0])
	if normal.length_squared() < 0.00000001:
		normal = (points[3] - points[0]).cross(points[2] - points[0])
	if normal.length_squared() < 0.00000001:
		return
	if normal.dot(outward) < 0.0:
		points = PackedVector3Array([points[0], points[3], points[2], points[1]])
		normal = -normal
	normal = normal.normalized()
	var first: int = vertices.size()
	vertices.append_array(points)
	for corner in range(4):
		normals.append(normal)
		colors.append(pigment)
	indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
