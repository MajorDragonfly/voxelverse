extends "res://world/surface/living_planet_surface.gd"
## Versioned freshwater basins. Old v1 terrain remains byte-for-byte procedural.
## Candidate cells and centers are canonical across cube seams; bounded cache.
const VERSION: String = "living_planet_v2"
var _lakes: Dictionary = {}
var _neighborhoods: Dictionary = {}

func _feature(d: Array) -> Dictionary:
	var center: Dictionary = Cube.from_cartesian(body.id, [d[0] * body.radius, d[1] * body.radius, d[2] * body.radius], body.radius)
	var level: int = ceili(log(body.radius * 2.0 / 256.0) / log(2.0))
	var count: int = 1 << level
	var step: float = 2.0 / count
	var cx: int = clampi(floori((center.u + 1.0) / step), 0, count - 1)
	var cy: int = clampi(floori((center.v + 1.0) / step), 0, count - 1)
	var key: String = "%d:%d:%d" % [center.face, cx, cy]
	if not _neighborhoods.has(key):
		if _neighborhoods.size() >= 32: _neighborhoods.erase(_neighborhoods.keys()[0])
		_neighborhoods[key] = _candidates(center.face, cx, cy, count, step)
	var closest: Dictionary = {}
	var nearest: float = 22.0
	for lake: Dictionary in _neighborhoods[key]:
		var delta := Vector3((d[0] - lake.direction[0]) * body.radius, (d[1] - lake.direction[1]) * body.radius, (d[2] - lake.direction[2]) * body.radius)
		var distance: float = delta.length()
		if distance < nearest:
			nearest = distance
			closest = lake.duplicate()
			closest["distance"] = distance
	return closest

func _candidates(face: int, cx: int, cy: int, count: int, step: float) -> Array:
	var result: Array = []
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			var normalized: Dictionary = Cube.address(body.id, face, -1.0 + (x + 0.5) * step, -1.0 + (y + 0.5) * step)
			var nx: int = clampi(floori((normalized.u + 1.0) / step), 0, count - 1)
			var ny: int = clampi(floori((normalized.v + 1.0) / step), 0, count - 1)
			var key: String = "%d:%d:%d" % [normalized.face, nx, ny]
			if not _lakes.has(key):
				if _lakes.size() >= 64: _lakes.erase(_lakes.keys()[0])
				var item: Dictionary = {}
				var seed_value: int = int((str(int(body.seed)) + ":lake2:" + key).sha256_text().left(7).hex_to_int())
				if seed_value % 3 == 0:
					var direction: Array = Cube.direction(normalized.face, -1.0 + (nx + 0.5) * step, -1.0 + (ny + 0.5) * step)
					var height: float = super.height_precise(direction)
					if height > 7.0 and height < 65.0: item = {"direction": direction, "level": height - 1.5, "key": key}
				_lakes[key] = item
			if not _lakes[key].is_empty(): result.append(_lakes[key])
	return result

func height_precise(d: Array) -> float:
	var original: float = super.height_precise(d)
	var lake: Dictionary = _feature(d)
	if lake.is_empty(): return original
	return lerpf(lake.level - 2.0, original, smoothstep(8.0, 22.0, lake.distance))

func water_level_precise(d: Array) -> float:
	var lake: Dictionary = _feature(d)
	return lake.get("level", 0.0)

func _sample(d: Array) -> Dictionary:
	var result: Dictionary = super._sample(d)
	var level: float = water_level_precise(d)
	result.water_level = level
	result.water = result.height < level - 0.08
	result["water_kind"] = "lake" if level > 0 else "ocean"
	if result.water and level > 0: result.biome = "lake"
	return result
