extends RefCounted
class_name PlanetTileLayout

const Cube = preload("res://world/space/cube_sphere.gd")
const ROOT_LEVEL: int = 2
const MAX_LEAVES: int = 768
const TARGET_WIDTH: float = 32.0
var radius: float
var max_level: int


func _init(body_radius: float) -> void:
	radius = body_radius
	max_level = clampi(ceili(log(radius * 2.0 / TARGET_WIDTH) / log(2.0)), ROOT_LEVEL, 16)


static func key(face: int, level: int, x: int, y: int) -> String:
	return "%d/%d/%d/%d" % [face, level, x, y]


static func patch(face: int, level: int, x: int, y: int) -> Dictionary:
	var width: float = 2.0 / (1 << level)
	return {"id": key(face, level, x, y), "face": face, "level": level, "x": x, "y": y,
		"uv": Vector2(-1.0 + x * width, -1.0 + y * width), "width": width,
		"direction": Cube.vector(Cube.direction(face, -1.0 + (x + 0.5) * width, -1.0 + (y + 0.5) * width))}


func choose(direction: Vector3) -> Dictionary:
	# Bound memory independently of planet size. If necessary reduce the finest
	# depth, never truncate a covering set or return an unbalanced hierarchy.
	for depth in range(max_level, ROOT_LEVEL - 1, -1):
		var leaves: Dictionary = {}
		for face in range(6):
			for y in range(1 << ROOT_LEVEL):
				for x in range(1 << ROOT_LEVEL):
					_select(patch(face, ROOT_LEVEL, x, y), direction, depth, leaves)
		_balance(leaves)
		if leaves.size() <= MAX_LEAVES:
			for tile: Dictionary in leaves.values():
				tile["mask"] = edge_mask(tile, leaves)
			return leaves
	return {}


func _select(tile: Dictionary, direction: Vector3, depth: int, leaves: Dictionary) -> void:
	var distance: float = tile.direction.distance_to(direction) * radius
	if tile.level < depth and distance < float(tile.width) * radius * 1.65:
		for child: Dictionary in children(tile):
			_select(child, direction, depth, leaves)
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
	for level in range(ROOT_LEVEL, max_level + 1):
		var side: int = 1 << level
		var x: int = clampi(floori((float(address.u) + 1.0) * 0.5 * side), 0, side - 1)
		var y: int = clampi(floori((float(address.v) + 1.0) * 0.5 * side), 0, side - 1)
		var id: String = key(address.face, level, x, y)
		if leaves.has(id):
			return leaves[id]
	return {}


func neighbor(tile: Dictionary, edge: int, t: float, leaves: Dictionary) -> Dictionary:
	var epsilon: float = float(tile.width) * 0.0001
	var uv: Vector2 = tile.uv
	var width: float = tile.width
	match edge:
		0: uv += Vector2(t * width, -epsilon)
		1: uv += Vector2(width + epsilon, t * width)
		2: uv += Vector2(t * width, width + epsilon)
		3: uv += Vector2(-epsilon, t * width)
	return find_at(tile.face, uv.x, uv.y, leaves)


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
