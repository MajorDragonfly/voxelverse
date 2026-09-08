extends RefCounted

# A world-anchored field, shared by the world surface and standalone chunks.
# Only amplitude varies locally: changing wave speed by biome splits the phase.
const SAMPLE_STEP: float = 32.0

static func sample_stillness(generator: Node, point: Vector2, cache: Dictionary) -> float:
	var cell := Vector2i(floori(point.x / SAMPLE_STEP), floori(point.y / SAMPLE_STEP))
	var weight: Vector2 = point / SAMPLE_STEP - Vector2(cell)
	var a: float = _at(generator, cell, cache)
	var b: float = _at(generator, cell + Vector2i.RIGHT, cache)
	var c: float = _at(generator, cell + Vector2i.DOWN, cache)
	var d: float = _at(generator, cell + Vector2i.ONE, cache)
	return lerpf(lerpf(a, b, weight.x), lerpf(c, d, weight.x), weight.y)

static func _at(generator: Node, cell: Vector2i, cache: Dictionary) -> float:
	if not cache.has(cell):
		var stillness: float = 0.0
		if generator.has_method("get_biome_composition"):
			var composition: Dictionary = generator.get_biome_composition(cell.x * SAMPLE_STEP, cell.y * SAMPLE_STEP)
			stillness = float(composition.get("water_style", {}).get("still", 0.0))
		cache[cell] = clampf(stillness, 0.0, 1.0)
	return float(cache[cell])


static func vertex_color(generator: Node, point: Vector2, cache: Dictionary) -> Color:
	var still: float = sample_stillness(generator, point, cache)
	var flow := Vector2.ZERO
	if generator.has_method("get_water_info"):
		var info: Dictionary = generator.get_water_info(point.x, point.y)
		if not info.is_empty():
			var influence: float = 1.0 - smoothstep(0.0, 10.0, float(info["distance"]))
			if info["kind"] == "lake":
				still = lerpf(still, 1.0, influence)
			else:
				flow = (info["flow"] as Vector2) * influence
	return Color(flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, still, 1.0)


static func height_at(generator: Node, point: Vector2, step: Vector2, cache: Dictionary) -> float:
	var corner: Vector2 = (point / step).floor() * step
	var ratio: Vector2 = (point - corner) / step
	var heights := Vector4.ZERO
	for i in range(4):
		var key: Vector2 = corner + [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN][i] * step
		if not cache.has(key):
			cache[key] = generator.get_water_level(key.x, key.y)
		heights[i] = float(cache[key])
	if ratio.x >= ratio.y:
		return heights.x * (1.0 - ratio.x) + heights.y * (ratio.x - ratio.y) + heights.z * ratio.y
	return heights.x * (1.0 - ratio.y) + heights.z * ratio.x + heights.w * (ratio.y - ratio.x)

static func shared_step(point: Vector2, center: Vector2) -> Vector2:
	var delta: Vector2 = (point - center).abs()
	return Vector2(2.0 if delta.x < 128.0 else 8.0, 2.0 if delta.y < 128.0 else 8.0)
