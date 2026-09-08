extends RefCounted

# Both grids use world coordinates and the same diagonal as the GPU meshes.
# Bilinear interpolation would bend the quad away from its two triangles.
const HORIZON_STEP: float = 8.0
const PROXY_STEP: float = 2.0
const DURATION: float = 0.65

static func height_at(generator: Node, point: Vector2, step: float, cache: Dictionary) -> float:
	var cell := Vector2i(floori(point.x / step), floori(point.y / step))
	var ratio: Vector2 = point / step - Vector2(cell)
	var heights := Vector4.ZERO
	for i in range(4):
		var key: Vector2i = cell + [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN][i]
		if not cache.has(key):
			cache[key] = generator.get_visual_terrain_height(key.x * step, key.y * step)
		heights[i] = float(cache[key])
	return triangle_height(heights, ratio)

static func triangle_height(heights: Vector4, ratio: Vector2) -> float:
	if ratio.x >= ratio.y:
		return heights.x * (1.0 - ratio.x) + heights.y * (ratio.x - ratio.y) + heights.z * ratio.y
	return heights.x * (1.0 - ratio.y) + heights.z * ratio.x + heights.w * (ratio.y - ratio.x)
