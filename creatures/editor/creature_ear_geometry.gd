extends RefCounted
const Catalog = preload("res://creatures/catalog/creature_ear_catalog.gd")
const Raster = preload("res://creatures/editor/creature_surface_appendage.gd")
const Voxels = Raster.Voxels
const CACHE_LIMIT: int = 24
const RECIPES: Dictionary = {
	"ears_cat_pointed": {
		"layout": "ear", "socket": [0.16, 0.13, 0.12],
		"outline": [[-0.08, -0.12], [0.12, -0.17], [0.62, 0.08], [0.3, 0.31], [-0.08, 0.14]],
		"rays": [],
	},
	"ears_bear_round": {
		"layout": "ear", "socket": [0.16, 0.13, 0.12],
		"outline": [[-0.08, -0.1], [0.05, -0.19], [0.25, -0.2], [0.42, -0.08], [0.44, 0.13], [0.3, 0.3], [0.08, 0.3], [-0.08, 0.12]],
		"rays": [],
	},
	"ears_rabbit_long": {
		"layout": "ear", "socket": [0.16, 0.13, 0.12],
		"outline": [[-0.08, -0.08], [0.35, -0.12], [0.78, -0.1], [1.08, 0.02], [1.15, 0.14], [1.06, 0.26], [0.76, 0.3], [0.3, 0.2], [-0.08, 0.09]],
		"rays": [],
	},
	"ears_dog_floppy": {
		"layout": "ear", "socket": [0.16, 0.13, 0.12],
		"outline": [[0.08, -0.07], [0.06, 0.16], [-0.14, 0.3], [-0.48, 0.37], [-0.8, 0.34], [-0.94, 0.19], [-0.91, 0.02], [-0.65, -0.05], [-0.27, -0.05]],
		"rays": [],
	},
	"ears_elephant_broad": {
		"layout": "ear", "socket": [0.16, 0.13, 0.12],
		"outline": [[-0.07, -0.06], [0.17, -0.09], [0.46, 0.1], [0.56, 0.36], [0.46, 0.63], [0.23, 0.78], [-0.13, 0.8], [-0.46, 0.61], [-0.59, 0.4], [-0.46, 0.16]],
		"rays": [],
	},
	"ears_bat_large": {
		"layout": "ear", "socket": [0.16, 0.13, 0.12],
		"outline": [[-0.08, -0.08], [0.25, -0.18], [0.68, -0.12], [0.98, 0.25], [0.68, 0.48], [0.26, 0.46], [-0.08, 0.13]],
		"rays": [],
	},
}
static var _cache: Dictionary = {}

static func articulation(id: String, revision: int = 1) -> Array[Dictionary]:
	var profile: Dictionary = Catalog.get_profile(id, revision)
	if profile.is_empty(): return []
	return [{"channel": "ear", "prefixes": ["EarSurface"], "pivot": Vector3.ZERO,
		"axis": Vector3.BACK, "degrees": 16.0}]

static func legacy_voxels(id: String, revision: int = 1) -> Array:
	if Catalog.get_profile(id, revision).is_empty(): return []
	var bounds: AABB = Raster.bounds(RECIPES[id])
	return [{"position": bounds.get_center(), "size": bounds.size, "color": Color("90ada0")}]

static func meshes(id: String, skin: Color, accent: Color, shape: Vector3 = Vector3.ONE, side: float = 1, revision: int = 1) -> Array[ArrayMesh]:
	if Catalog.get_profile(id, revision).is_empty() or not shape.is_finite() or shape.x < 0.4 or shape.y < 0.4 or shape.z < 0.4 or shape.x > 2.5 or shape.y > 2.5 or shape.z > 2.5: return []
	var key: String = "%s:%s:%s:%s:%s" % [id, skin, accent, var_to_str(shape), side < 0]
	if _cache.has(key): return _cache[key]
	var surfaces: Array[ArrayMesh] = Raster.build(RECIPES[id], skin, accent, shape, side)
	if _cache.size() >= CACHE_LIMIT: _cache.erase(_cache.keys()[0])
	_cache[key] = surfaces
	return surfaces
