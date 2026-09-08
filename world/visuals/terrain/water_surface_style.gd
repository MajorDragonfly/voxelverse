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
