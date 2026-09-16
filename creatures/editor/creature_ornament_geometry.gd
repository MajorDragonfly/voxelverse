extends RefCounted
## One connected cubic surface for each antler, crest or frill.
const Catalog = preload("res://creatures/catalog/creature_ornament_catalog.gd")
const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")
const CACHE_LIMIT: int = 24
const TARGET_CELLS: int = 60000
static var _cache: Dictionary = {}


static func branches(id: String) -> Array:
	if id == "horns_stag_antlers":
		return [[Vector3(0, -0.07, 0), Vector3(0.12, 0.42, 0.02), 0.090, 0.075],
			[Vector3(0.12, 0.42, 0.02), Vector3(0.43, 0.78, 0.08), 0.075, 0.060],
			[Vector3(0.43, 0.78, 0.08), Vector3(0.64, 1.14, -0.03), 0.060, 0.020],
			[Vector3(0.10, 0.36, 0.02), Vector3(-0.13, 0.66, -0.24), 0.062, 0.020],
			[Vector3(0.28, 0.62, 0.05), Vector3(0.24, 1.03, -0.13), 0.054, 0.020],
			[Vector3(0.43, 0.78, 0.08), Vector3(0.72, 0.91, -0.21), 0.048, 0.020]]
	if id == "horns_moose_antlers":
		return [[Vector3(0, -0.07, 0), Vector3(0.30, 0.40, 0), 0.095, 0.10],
			[Vector3(0.29, 0.57, 0), Vector3(0.22, 0.94, -0.08), 0.066, 0.023],
			[Vector3(0.42, 0.69, 0), Vector3(0.44, 1.05, -0.03), 0.068, 0.023],
			[Vector3(0.64, 0.64, 0), Vector3(0.77, 0.95, -0.07), 0.068, 0.023],
			[Vector3(0.75, 0.53, 0), Vector3(1.00, 0.75, -0.08), 0.063, 0.023]]
	return []


static func contour(id: String) -> PackedVector2Array:
	match id:
		"horns_moose_antlers": return PackedVector2Array([Vector2(0.14, 0.30), Vector2(0.22, 0.53), Vector2(0.31, 0.68), Vector2(0.44, 0.74), Vector2(0.65, 0.70), Vector2(0.80, 0.57), Vector2(0.78, 0.40), Vector2(0.62, 0.29), Vector2(0.38, 0.24)])
		"decor_low_crest": return PackedVector2Array([Vector2(-0.70, -0.09), Vector2(-0.70, 0.09), Vector2(-0.48, 0.26), Vector2(-0.14, 0.34), Vector2(0.27, 0.30), Vector2(0.66, 0.09), Vector2(0.70, -0.09)])
		"decor_saw_crest": return PackedVector2Array([Vector2(-0.73, -0.09), Vector2(-0.70, 0.10), Vector2(-0.53, 0.54), Vector2(-0.35, 0.17), Vector2(-0.15, 0.72), Vector2(0.04, 0.20), Vector2(0.24, 0.64), Vector2(0.40, 0.16), Vector2(0.58, 0.43), Vector2(0.73, 0.03), Vector2(0.73, -0.09)])
		"decor_head_crest": return PackedVector2Array([Vector2(-0.28, -0.09), Vector2(-0.31, 0.14), Vector2(-0.18, 0.53), Vector2(-0.03, 0.48), Vector2(0.22, 0.26), Vector2(0.38, 0.02), Vector2(0.35, -0.09)])
		"decor_frill": return PackedVector2Array([Vector2(-0.15, -0.11), Vector2(-0.42, 0.06), Vector2(-0.65, 0.40), Vector2(-0.54, 0.72), Vector2(-0.26, 0.95), Vector2(0, 0.86), Vector2(0.26, 0.95), Vector2(0.54, 0.72), Vector2(0.65, 0.40), Vector2(0.42, 0.06), Vector2(0.15, -0.11)])
	return PackedVector2Array()


static func bounds(id: String) -> AABB:
	if Catalog.get_profile(id).is_empty(): return AABB()
	var box := AABB(Vector3(-0.13, -0.15, -0.12), Vector3(0.26, 0.28, 0.24))
	for branch: Array in branches(id):
		var padding := Vector3.ONE * maxf(branch[2], branch[3])
		box = box.merge(AABB(branch[0].min(branch[1]) - padding, (branch[1] - branch[0]).abs() + padding * 2.0))
	var xy: bool = id in ["horns_moose_antlers", "decor_frill"]
	for p: Vector2 in contour(id):
		box = box.expand(Vector3(p.x, p.y, -0.08) if xy else Vector3(-0.07, p.y, p.x))
		box = box.expand(Vector3(p.x, p.y, 0.08) if xy else Vector3(0.07, p.y, p.x))
	return box


static func legacy_voxels(id: String, revision: int = 1) -> Array:
	if Catalog.get_profile(id, revision).is_empty(): return []
	var box: AABB = bounds(id)
	return [{"position": box.get_center(), "size": box.size, "color": Color("bca57c")}]


static func mesh(id: String, skin: Color, accent: Color, horn: Color, shape: Vector3 = Vector3.ONE, side: float = 1.0, revision: int = 1) -> ArrayMesh:
	if Catalog.get_profile(id, revision).is_empty() or not shape.is_finite() or shape.x < 0.4 or shape.y < 0.4 or shape.z < 0.4 or shape.x > 2.5 or shape.y > 2.5 or shape.z > 2.5: return ArrayMesh.new()
	var key: String = "%s:%s:%s:%s:%s:%s" % [id, skin, accent, horn, shape, side < 0]
	if _cache.has(key): return _cache[key]
	var step: float = _sampling_step(id, shape)
	var cells: Dictionary = {}
	_ellipsoid(cells, Vector3(0, -0.01, 0), Vector3(0.13, 0.14, 0.12), shape, step, skin)
	for branch: Array in branches(id): _branch(cells, branch, shape, step, horn)
	_polygon(cells, id, shape, step, horn if id.begins_with("horns_") else skin.lerp(accent, 0.40))
	if side < 0:
		var reflected: Dictionary = {}
		for cell: Vector3i in cells: reflected[Vector3i(-cell.x - 1, cell.y, cell.z)] = cells[cell]
		cells = reflected
	for cell: Vector3i in cells: cells[cell] = cells[cell].darkened(maxf(0, Voxels.shade(cell)))
	var result: ArrayMesh = Voxels.from_cells(cells, step, true)
	if _cache.size() >= CACHE_LIMIT: _cache.erase(_cache.keys()[0])
	_cache[key] = result
	return result


static func _sampling_step(id: String, shape: Vector3) -> float:
	# Bound the occupied volume before sampling. Capsule overlap makes this
	# conservative; the reserve leaves room for lattice quantization at thin tips.
	var volume: float = 4.0 / 3.0 * PI * 0.13 * 0.14 * 0.12
	for branch: Array in branches(id):
		var radius: float = maxf(branch[2], branch[3])
		volume += PI * radius * radius * branch[0].distance_to(branch[1]) + 4.0 / 3.0 * PI * pow(radius, 3)
	var polygon: PackedVector2Array = contour(id)
	var area: float = 0
	for index in range(polygon.size()): area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	volume += absf(area) * 0.5 * (0.156 if id in ["horns_moose_antlers", "decor_frill"] else 0.11)
	var detail: float = minf((bounds(id).size * shape).length() / 64.0, 0.020 * minf(shape.x, minf(shape.y, shape.z)))
	return maxf(detail, pow(volume * shape.x * shape.y * shape.z / TARGET_CELLS, 1.0 / 3.0))


static func _polygon(cells: Dictionary, id: String, shape: Vector3, step: float, color: Color) -> void:
	var polygon: PackedVector2Array = contour(id)
	if polygon.is_empty(): return
	var xy: bool = id in ["horns_moose_antlers", "decor_frill"]
	var box: AABB = bounds(id)
	var low := Vector3i((box.position * shape / step).floor())
	var high := Vector3i((box.end * shape / step).ceil())
	for x in range(low.x, high.x):
		for y in range(low.y, high.y):
			for z in range(low.z, high.z):
				var cell := Vector3i(x, y, z)
				var p: Vector3 = (Vector3(cell) + Vector3.ONE * 0.5) * step / shape
				var point := Vector2(p.x if xy else p.z, p.y)
				if absf(p.z if xy else p.x) > (0.078 if xy else 0.055) or not Geometry2D.is_point_in_polygon(point, polygon): continue
				cells[cell] = color.lightened(0.10) if p.y > 0.10 and fmod(absf(point.x) * 14 + p.y * 3, 1.0) < 0.15 else color


static func _branch(cells: Dictionary, branch: Array, shape: Vector3, step: float, color: Color) -> void:
	var start: Vector3 = branch[0]
	var end: Vector3 = branch[1]
	var axis: Vector3 = end - start
	var padding := Vector3.ONE * maxf(branch[2], branch[3])
	var low := Vector3i(((start.min(end) - padding) * shape / step).floor())
	var high := Vector3i(((start.max(end) + padding) * shape / step).ceil())
	for x in range(low.x, high.x):
		for y in range(low.y, high.y):
			for z in range(low.z, high.z):
				var cell := Vector3i(x, y, z)
				var p: Vector3 = (Vector3(cell) + Vector3.ONE * 0.5) * step / shape
				var t: float = clampf((p - start).dot(axis) / axis.length_squared(), 0, 1)
				var radius: float = lerpf(branch[2], branch[3], t)
				if p.distance_squared_to(start + axis * t) <= radius * radius: cells[cell] = color


static func _ellipsoid(cells: Dictionary, center: Vector3, radius: Vector3, shape: Vector3, step: float, color: Color) -> void:
	var low := Vector3i(((center - radius) * shape / step).floor())
	var high := Vector3i(((center + radius) * shape / step).ceil())
	for x in range(low.x, high.x):
		for y in range(low.y, high.y):
			for z in range(low.z, high.z):
				var cell := Vector3i(x, y, z)
				var p: Vector3 = (Vector3(cell) + Vector3.ONE * 0.5) * step / shape
				if ((p - center) / radius).length_squared() <= 1.0: cells[cell] = color
