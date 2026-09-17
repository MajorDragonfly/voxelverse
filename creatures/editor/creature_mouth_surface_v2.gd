extends RefCounted
## Revision 2: continuous upper/lower volumes, an open oral slit and fused
## details. Revision 1 remains in the historical recipe provider.
const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")
const CACHE_LIMIT: int = 32
const TARGET_SAMPLES: int = 180000
static var _cache: Dictionary = {}


static func profile(id: String) -> Dictionary:
	var values: Dictionary = {
		"mouth_grazer": [0.62, 0.39, 0.20, "grazer"],
		"mouth_broad_beak": [0.56, 0.55, 0.21, "beak"],
		"mouth_predator_jaws": [0.73, 0.52, 0.23, "predator"],
		"mouth_filter_snout": [0.38, 0.72, 0.17, "filter"],
		"mouth_canine_snout": [0.59, 0.64, 0.23, "canine"],
		"mouth_crocodile_snout": [0.64, 0.96, 0.14, "crocodile"],
		"mouth_octopus_beak": [0.70, 0.43, 0.32, "octopus"],
		"mouth_feline_snout": [0.53, 0.30, 0.18, "feline"],
		"mouth_bear_snout": [0.77, 0.50, 0.26, "bear"],
		"mouth_pig_snout": [0.55, 0.48, 0.22, "pig"],
	}
	if not values.has(id): return {}
	var p: Array = values[id]
	return {"width": p[0], "length": p[1], "height": p[2], "kind": p[3]}


static func articulation(id: String) -> Array[Dictionary]:
	if profile(id).is_empty(): return []
	return [{"channel": "mouth", "prefixes": ["LowerJawSurface"],
		"pivot": Vector3(0, -0.085, 0.055), "axis": Vector3.RIGHT,
		"degrees": -25.0 if id != "mouth_octopus_beak" else -18.0}]


static func meshes(id: String, skin: Color, accent: Color, horn: Color, shape: Vector3 = Vector3.ONE, side: float = 1.0) -> Array[ArrayMesh]:
	var p: Dictionary = profile(id)
	if p.is_empty() or not shape.is_finite() or shape.x < 0.4 or shape.y < 0.4 or shape.z < 0.4 or shape.x > 2.5 or shape.y > 2.5 or shape.z > 2.5: return []
	var reflected: bool = side < 0
	var key: String = "%s:%s:%s:%s:%s:%s" % [id, skin, accent, horn, shape, reflected]
	if _cache.has(key): return _cache[key]
	var low := Vector3(-p.width * 0.58, -0.35, -p.length - 0.08) * shape
	var high := Vector3(p.width * 0.58, p.height + 0.12, 0.15) * shape
	var step: float = minf((high - low).length() / 66.0, 0.020 * minf(shape.x, minf(shape.y, shape.z)))
	var extent: Vector3 = high - low
	step = maxf(step, pow(extent.x * extent.y * extent.z / TARGET_SAMPLES, 1.0 / 3.0))
	var result: Array[ArrayMesh] = []
	for jaw in range(2):
		var cells: Dictionary = {}
		var bottom: float = (-0.35 if p.kind == "octopus" else -0.12) * shape.y if jaw == 0 else -0.20 * shape.y
		var top: float = high.y if jaw == 0 else -0.073 * shape.y
		for z in range(floori(low.z / step), ceili(high.z / step)):
			for y in range(floori(bottom / step), ceili(top / step)):
				for x in range(floori(low.x / step), ceili(high.x / step)):
					var cell := Vector3i(x, y, z)
					var point: Vector3 = (Vector3(cell) + Vector3.ONE * 0.5) * step / shape
					var tint: Color = _sample(point, p, jaw, skin, accent, horn)
					if tint.a == 0: continue
					if reflected: cell.x = -cell.x - 1
					cells[cell] = tint.darkened(maxf(0, Voxels.shade(cell)))
		var mesh: ArrayMesh = Voxels.from_cells(cells, step, true)
		mesh.set_meta("mouth_surface_revision", 2)
		result.append(mesh)
	if _cache.size() >= CACHE_LIMIT: _cache.erase(_cache.keys()[0])
	_cache[key] = result
	return result


static func _sample(v: Vector3, p: Dictionary, jaw: int, skin: Color, accent: Color, horn: Color) -> Color:
	var empty := Color(0, 0, 0, 0)
	var interior := Color("38292d")
	var kind: String = p.kind
	if kind == "octopus": return _octopus(v, jaw, skin, accent, horn)
	var t: float = clampf((0.12 - v.z) / (p.length + 0.12), 0, 1)
	var taper: float = 0.0 if kind in ["grazer", "pig", "filter"] else (0.45 if kind == "canine" else 0.26)
	var half_width: float = p.width * 0.5 * (1.0 - taper * t)
	var round_tip: float = sqrt(clampf((v.z + p.length) / 0.065, 0, 1))
	if kind == "beak": round_tip = pow(1.0 - t, 0.65) + 0.015
	half_width *= round_tip * (1.0 if jaw == 0 else 0.91)
	var nx: float = absf(v.x) / maxf(half_width, 0.001)
	var inside: bool = v.z <= 0.12 and v.z > -p.length and nx < 1.0
	var roof: float = sqrt(maxf(0, 1.0 - nx * nx))
	var color: Color = empty
	if jaw == 0:
		var height: float = p.height * roof * (1.0 - t * (0.84 if kind == "beak" else 0.34))
		if inside and v.y >= -0.015 and v.y <= height:
			color = horn if kind == "beak" else skin
			if v.y < 0.006: color = interior
		# The throat joins the root to the upper jaw, behind the open slit.
		if v.z > 0.055 and v.z < 0.115 and absf(v.x) < p.width * 0.37 and v.y > -0.11 and v.y < 0.04: color = interior
		if kind in ["predator", "canine", "crocodile", "feline", "bear"]:
			var tooth_z: Array = [-p.length * 0.68] if kind != "crocodile" else [-0.22, -0.39, -0.56, -0.73]
			for z in tooth_z:
				var fraction: float = (0.12 - float(z)) / (p.length + 0.12)
				var x: float = p.width * 0.5 * (1 - taper * fraction) * 0.77
				if v.y > -0.072 and v.y < 0.035 and absf(v.z - float(z)) < 0.031:
					var radius: float = 0.030 * clampf((v.y + 0.076) / 0.07, 0.10, 1.0)
					if absf(absf(v.x) - x) < radius: color = horn
		if kind in ["canine", "feline", "bear", "pig"]:
			var nose_center := Vector3(0, p.height * 0.42, -p.length + 0.025)
			var nose_size := Vector3(p.width * (0.40 if kind == "pig" else 0.23), p.height * 0.40, 0.080)
			if _ellipsoid(v, nose_center, nose_size):
				color = skin.lightened(0.16) if kind == "pig" else accent.darkened(0.64)
				if v.z < nose_center.z - 0.041 and absf(absf(v.x) - nose_size.x * 0.45) < nose_size.x * 0.18 and absf(v.y - nose_center.y) < nose_size.y * 0.40: color = Color("151d1e")
		elif kind != "beak":
			if color.a > 0 and inside and absf(absf(v.x) - p.width * 0.17) < 0.026 and absf(v.z + p.length * 0.81) < 0.033 and v.y > p.height * (1 - t * 0.34) * 0.80: color = accent.darkened(0.55)
	else:
		if inside and v.y <= -0.085 and v.y >= -0.085 - (0.070 if kind == "beak" else 0.105) * roof:
			color = horn.darkened(0.13) if kind == "beak" else skin.darkened(0.09)
			if v.y > -0.108:
				color = interior
				if kind != "beak" and pow(v.x / maxf(half_width * 0.50, 0.001), 2) + pow((t - 0.54) / 0.29, 2) < 1.0: color = skin.lerp(Color("b0717c"), 0.65)
	return color


static func _ellipsoid(v: Vector3, center: Vector3, radius: Vector3) -> bool:
	return ((v - center) / radius).length_squared() <= 1.0


static func _octopus(v: Vector3, jaw: int, skin: Color, accent: Color, horn: Color) -> Color:
	var color := Color(0, 0, 0, 0)
	if jaw == 0:
		var radial: float = Vector2(v.x / 0.32, v.y / 0.31).length_squared()
		if v.z > -0.29 and v.z < 0.11 and radial <= 1 and (radial >= 0.43 or v.z > -0.06): color = skin.lerp(accent, 0.12) if radial >= 0.43 else Color("38292d")
		if _ellipsoid(v, Vector3(0, 0.10, -0.10), Vector3(0.12, 0.085, 0.20)): color = horn.darkened(0.55)
		var hook: float = (-v.z - 0.15) / 0.29
		if hook >= 0 and hook <= 1 and absf(v.x) < 0.12 * (1 - hook) + 0.006 and v.y > 0.06 - hook * 0.12 and v.y < 0.15 * (1 - hook) + 0.018: color = horn.darkened(0.55)
	else:
		if _ellipsoid(v, Vector3(0, -0.13, -0.14), Vector3(0.10, 0.057, 0.20)): color = horn.darkened(0.40)
	return color
