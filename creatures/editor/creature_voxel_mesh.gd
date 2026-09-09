extends RefCounted
## Cubic surface mesher: only exposed faces, one mesh per moving anatomical
## piece. The same occupied cells are used when placing parts in the editor.

const NEIGHBORS: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
static var _primitive_cache: Dictionary = {}


static func from_cells(cells: Dictionary, cell_size: float, keep_cells: bool = false, surface_cells: Array[Vector3i] = []) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# Body row spans already identify the shell. Keep the complete occupancy
	# for neighbor culling and picking, but avoid walking its solid interior.
	var candidates: Array = surface_cells if not surface_cells.is_empty() else cells.keys()
	for cell: Vector3i in candidates:
		var color: Color = cells[cell]
		for neighbor: Vector3i in NEIGHBORS:
			if cells.has(cell + neighbor):
				continue
			var normal := Vector3(neighbor)
			var tangent: Vector3 = Vector3.UP.cross(normal) if neighbor.y == 0 else Vector3.RIGHT
			var bitangent: Vector3 = tangent.cross(normal)
			var center: Vector3 = (Vector3(cell) + Vector3.ONE * 0.5 + normal * 0.5) * cell_size
			var first: int = vertices.size()
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				vertices.append(center + (tangent * corner.x + bitangent * corner.y) * cell_size * 0.5)
				normals.append(normal)
				colors.append(color)
			# Godot front faces use clockwise winding.
			indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.set_meta("voxel_size", cell_size)
	mesh.set_meta("voxel_count", cells.size())
	if keep_cells:
		mesh.set_meta("voxel_cells", cells)
	return mesh


static func shade(cell: Vector3i) -> float:
	# Small stable variations reveal the grid without noisy outlines. Mirrored
	# body cells receive the same tint, including the two sides of the center.
	var sample: int = absi((absi(cell.x * 2 + 1) * 17 + cell.y * 23 + cell.z * 13) % 7)
	return float(sample - 3) * 0.008


static func primitive(size: Vector3, kind: String = "ellipsoid") -> ArrayMesh:
	var dimensions: Vector3 = size.max(Vector3.ONE * 0.001)
	var key: String = "%s:%s" % [kind, var_to_str(dimensions)]
	if _primitive_cache.has(key):
		return _primitive_cache[key]
	var longest: float = maxf(dimensions.x, maxf(dimensions.y, dimensions.z))
	var smallest: float = minf(dimensions.x, minf(dimensions.y, dimensions.z))
	# Fine eyes, pupils, joints and horn tips need smaller cells than the skin.
	var step: float = maxf(minf(0.0325, smallest / 6.0), longest / 48.0)
	var radius: Vector3 = dimensions * 0.5
	var limit := Vector3i((radius / step).ceil())
	var cells: Dictionary = {}
	for z in range(-limit.z, limit.z):
		for y in range(-limit.y, limit.y):
			for x in range(-limit.x, limit.x):
				var cell := Vector3i(x, y, z)
				var point: Vector3 = (Vector3(cell) + Vector3.ONE * 0.5) * step
				var distance: float = (point / radius).length_squared()
				if kind == "capsule":
					var half_line: float = maxf(0.0, radius.y - radius.x)
					var closest := Vector3(0, clampf(point.y, -half_line, half_line), 0)
					distance = point.distance_squared_to(closest) / (radius.x * radius.x)
				elif kind == "cone":
					var taper: float = maxf(0.04, 0.5 - point.y / dimensions.y)
					distance = pow(point.x / (radius.x * taper), 2.0) + pow(point.z / (radius.z * taper), 2.0)
					if absf(point.y) > radius.y:
						continue
				if distance <= 1.0:
					cells[cell] = Color.WHITE.darkened(maxf(0.0, shade(cell)))
	# A very thin pupil or plate still needs visible geometry.
	if cells.is_empty():
		cells[Vector3i.ZERO] = Color.WHITE
	var mesh: ArrayMesh = from_cells(cells, step)
	if _primitive_cache.size() >= 96:
		_primitive_cache.clear()
	_primitive_cache[key] = mesh
	return mesh


static func plinth() -> ArrayMesh:
	var cells: Dictionary = {}
	for z in range(-14, 14):
		for x in range(-14, 14):
			# Stepped corners follow the creature's cube geometry.
			if absi(x * 2 + 1) + absi(z * 2 + 1) > 48:
				continue
			var color := Color("2c4951") if (x + z) % 2 == 0 else Color("29454d")
			cells[Vector3i(x, -1, z)] = color
	return from_cells(cells, 0.18)


static func raycast(mesh: ArrayMesh, origin: Vector3, direction: Vector3) -> Dictionary:
	var cells: Dictionary = mesh.get_meta("voxel_cells", {})
	if cells.is_empty() or not direction.is_finite() or direction.length_squared() < 0.0001:
		return {}
	var ray: Vector3 = direction.normalized()
	var bounds: AABB = mesh.get_aabb()
	var enter: float = 0.0
	var leave: float = INF
	var normal := Vector3.ZERO
	for axis in range(3):
		if absf(ray[axis]) < 0.000001:
			if origin[axis] < bounds.position[axis] or origin[axis] > bounds.end[axis]:
				return {}
			continue
		var first: float = (bounds.position[axis] - origin[axis]) / ray[axis]
		var last: float = (bounds.end[axis] - origin[axis]) / ray[axis]
		if minf(first, last) > enter:
			enter = minf(first, last)
			normal = Vector3.ZERO
			normal[axis] = -signf(ray[axis])
		leave = minf(leave, maxf(first, last))
	if leave < enter:
		return {}
	var step: float = float(mesh.get_meta("voxel_size"))
	var cell := Vector3i(((origin + ray * (enter + step * 0.0001)) / step).floor())
	var increments := Vector3i(signf(ray.x), signf(ray.y), signf(ray.z))
	var next := Vector3(INF, INF, INF)
	var delta := Vector3(INF, INF, INF)
	for axis in range(3):
		if increments[axis] != 0:
			var boundary: float = float(cell[axis] + (1 if increments[axis] > 0 else 0)) * step
			next[axis] = (boundary - origin[axis]) / ray[axis]
			delta[axis] = step / absf(ray[axis])
	var maximum_steps: int = ceili((bounds.size.x + bounds.size.y + bounds.size.z) / step) + 6
	for iteration in range(maximum_steps):
		if cells.has(cell):
			return {"position": origin + ray * enter, "normal": normal, "cell": cell}
		var axis: int = 0 if next.x <= next.y and next.x <= next.z else (1 if next.y <= next.z else 2)
		enter = next[axis]
		if enter > leave + step * 0.0001:
			break
		cell[axis] += increments[axis]
		next[axis] += delta[axis]
		normal = Vector3.ZERO
		normal[axis] = -float(increments[axis])
	return {}
