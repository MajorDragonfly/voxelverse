extends RefCounted
class_name PlanetTileLayout

const Cube = preload("res://world/space/cube_sphere.gd")
const ROOT_LEVEL: int = 0
const MAX_LEAVES: int = 768
const TARGET_WIDTH: float = 32.0
const NEAR_RADIUS_METERS: float = 64.0
var radius: float
var max_level: int
var root_level: int


func _init(body_radius: float) -> void:
	radius = body_radius
	root_level = 2 if radius < 50000.0 else ROOT_LEVEL
	max_level = clampi(ceili(log(radius * 2.0 / TARGET_WIDTH) / log(2.0)), root_level, 24)


static func key(face: int, level: int, x: int, y: int) -> String:
	return "%d/%d/%d/%d" % [face, level, x, y]


static func patch(face: int, level: int, x: int, y: int) -> Dictionary:
	var width: float = 2.0 / (1 << level)
	return {"id": key(face, level, x, y), "face": face, "level": level, "x": x, "y": y,
		"uv": Vector2(-1.0 + x * width, -1.0 + y * width), "width": width,
		"direction": Cube.vector(Cube.direction(face, -1.0 + (x + 0.5) * width, -1.0 + (y + 0.5) * width))}


func choose(direction: Vector3, previous_masks: Dictionary = {}) -> Dictionary:
	var retained: Dictionary = {}
	for id: String in previous_masks:
		var parts: PackedStringArray = id.split("/")
		var level: int = int(parts[1])
		for ancestor in range(level):
			retained[key(int(parts[0]), ancestor, int(parts[2]) >> (level - ancestor), int(parts[3]) >> (level - ancestor))] = true
	# Bound memory independently of planet size. If necessary reduce the finest
	# depth, never truncate a covering set or return an unbalanced hierarchy.
	for depth in range(max_level, root_level - 1, -1):
		for history: Dictionary in ([{}] if retained.is_empty() else [retained, {}]):
			var leaves: Dictionary = {}
			for face in range(6):
				var focus: Array = _project_focus(face, direction)
				for y in range(1 << root_level):
					for x in range(1 << root_level):
						_select(patch(face, root_level, x, y), focus, depth, leaves, history)
			_balance(leaves)
			if leaves.size() <= MAX_LEAVES:
				for tile: Dictionary in leaves.values():
					tile["mask"] = edge_mask(tile, leaves)
				return leaves
	return {}


func _project_focus(face: int, d: Vector3) -> Array:
	# Face-space distance keeps distant hierarchy decisions stable when the
	# observer moves metres on a world thousands of kilometres across.
	match face:
		0: return [-float(d.z) / d.x, float(d.y) / d.x] if d.x > 0.0 else [INF, INF]
		1: return [float(d.z) / -d.x, float(d.y) / -d.x] if d.x < 0.0 else [INF, INF]
		2: return [float(d.x) / d.y, -float(d.z) / d.y] if d.y > 0.0 else [INF, INF]
		3: return [float(d.x) / -d.y, float(d.z) / -d.y] if d.y < 0.0 else [INF, INF]
		4: return [float(d.x) / d.z, float(d.y) / d.z] if d.z > 0.0 else [INF, INF]
		_: return [-float(d.x) / -d.z, float(d.y) / -d.z] if d.z < 0.0 else [INF, INF]


func _select(tile: Dictionary, focus: Array, depth: int, leaves: Dictionary, retained: Dictionary) -> void:
	var distance: float = maxf(absf(float(tile.uv.x) + tile.width * 0.5 - focus[0]),
		absf(float(tile.uv.y) + tile.width * 0.5 - focus[1]))
	var reach: float = maxf(float(tile.width) * 0.8, float(tile.width) * 0.5 + NEAR_RADIUS_METERS / radius)
	# Keep existing subdivisions longer than the threshold that creates them.
	# Otherwise crossing a face can discard and rebuild hundreds of far tiles.
	if retained.has(tile.id):
		reach *= 1.35
	if tile.level < depth and distance < reach:
		for child: Dictionary in children(tile):
			_select(child, focus, depth, leaves, retained)
	else:
		leaves[tile.id] = tile


static func children(tile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y in range(2):
		for x in range(2):
			result.append(patch(tile.face, tile.level + 1, tile.x * 2 + x, tile.y * 2 + y))
	return result


func find_at(face: int, u: float, v: float, leaves: Dictionary) -> Dictionary:
	var address: Dictionary = Cube.from_direction("layout", Cube.direction(face, u, v))
	for level in range(root_level, max_level + 1):
		var side: int = 1 << level
		var x: int = clampi(floori((float(address.u) + 1.0) * 0.5 * side), 0, side - 1)
		var y: int = clampi(floori((float(address.v) + 1.0) * 0.5 * side), 0, side - 1)
		var id: String = key(address.face, level, x, y)
		if leaves.has(id):
			return leaves[id]
	return {}


func neighbor(tile: Dictionary, edge: int, t: float, leaves: Dictionary) -> Dictionary:
	var epsilon: float = float(tile.width) * 0.0001
	# The outside-edge offset is smaller than a Vector2 float's precision at
	# Earth scale. Keep both coordinates scalar doubles until face lookup.
	var u: float = tile.uv.x
	var v: float = tile.uv.y
	var width: float = tile.width
	match edge:
		0:
			u += t * width
			v -= epsilon
		1:
			u += width + epsilon
			v += t * width
		2:
			u += t * width
			v += width + epsilon
		3:
			u -= epsilon
			v += t * width
	return find_at(tile.face, u, v, leaves)


func _balance(leaves: Dictionary) -> void:
	for iteration in range(max_level + 1):
		var split: Dictionary = {}
		for tile: Dictionary in leaves.values():
			for edge in range(4):
				var adjacent: Dictionary = neighbor(tile, edge, 0.5, leaves)
				if not adjacent.is_empty() and tile.level > adjacent.level + 1:
					split[adjacent.id] = adjacent
		if split.is_empty():
			return
		for tile: Dictionary in split.values():
			leaves.erase(tile.id)
			for child: Dictionary in children(tile):
				leaves[child.id] = child


func edge_mask(tile: Dictionary, leaves: Dictionary) -> int:
	var mask: int = 0
	for edge in range(4):
		var adjacent: Dictionary = neighbor(tile, edge, 0.5, leaves)
		if not adjacent.is_empty() and adjacent.level < tile.level:
			mask |= 1 << edge
	return mask
