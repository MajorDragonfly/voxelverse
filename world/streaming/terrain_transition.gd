extends RefCounted

# Nested, world-aligned column fields. Sample column centres, never interpolate
# a ramp between corners: distant mountains must keep their voxel silhouette.
const HORIZON_STEP: float = 4.0
const PROXY_STEP: float = 2.0
const DURATION: float = 0.65

static func height_at(generator: Node, point: Vector2, step: float, cache: Dictionary) -> float:
	var cell := Vector2i(floori(point.x / step), floori(point.y / step))
	if not cache.has(cell):
		var center: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * step
		cache[cell] = generator.get_visual_terrain_height(center.x, center.y)
	return float(cache[cell])

static func triangle_height(heights: Vector4, ratio: Vector2) -> float:
	if ratio.x >= ratio.y:
		return heights.x * (1.0 - ratio.x) + heights.y * (ratio.x - ratio.y) + heights.z * ratio.y
	return heights.x * (1.0 - ratio.y) + heights.z * ratio.x + heights.w * (ratio.y - ratio.x)
