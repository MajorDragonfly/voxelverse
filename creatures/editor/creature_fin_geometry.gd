extends RefCounted
const Catalog = preload("res://creatures/catalog/creature_fin_catalog.gd")
const Raster = preload("res://creatures/editor/creature_surface_appendage.gd")
const Voxels = Raster.Voxels
const CACHE_LIMIT: int = 24
const RECIPES: Dictionary = {
	"fins_broad_paddle": {
		"layout": "side", "socket": [0.17, 0.13, 0.19],
		"outline": [[-0.1, -0.12], [0.25, -0.23], [0.72, -0.41], [1.15, -0.33], [1.36, -0.09], [1.34, 0.22], [1.1, 0.45], [0.67, 0.49], [0.22, 0.19], [-0.1, 0.12]],
		"rays": [[0.73, -0.38], [1.16, -0.29], [1.32, -0.06], [1.28, 0.21], [1.05, 0.42], [0.7, 0.44]],
	},
	"fins_slender_steering": {
		"layout": "side", "socket": [0.17, 0.13, 0.19],
		"outline": [[-0.1, -0.08], [0.37, -0.2], [0.91, -0.09], [1.48, 0.48], [1.17, 0.32], [0.74, 0.24], [0.23, 0.14], [-0.1, 0.08]],
		"rays": [[0.9, -0.06], [1.36, 0.37], [1.13, 0.29], [0.74, 0.2]],
	},
	"fins_round_side": {
		"layout": "side", "socket": [0.17, 0.13, 0.19],
		"outline": [[-0.1, -0.07], [0.18, -0.13], [0.36, -0.29], [0.6, -0.26], [0.74, -0.08], [0.75, 0.11], [0.59, 0.28], [0.35, 0.3], [0.16, 0.11], [-0.1, 0.07]],
		"rays": [[0.4, -0.24], [0.65, -0.14], [0.71, 0.02], [0.63, 0.2], [0.4, 0.25]],
	},
	"fins_tall_dorsal": {
		"layout": "dorsal", "socket": [0.11, 0.1, 0.28],
		"outline": [[-0.08, -0.43], [0.1, -0.42], [0.55, -0.27], [1.01, 0.01], [0.73, 0.11], [0.4, 0.16], [0.14, 0.32], [0.02, 0.5], [-0.08, 0.5]],
		"rays": [[0.24, -0.34], [0.53, -0.24], [0.88, -0.05], [0.6, 0.12], [0.27, 0.23]],
	},
	"fins_long_fringe": {
		"layout": "dorsal", "socket": [0.11, 0.1, 0.62],
		"outline": [[-0.08, -0.86], [0.09, -0.83], [0.23, -0.65], [0.31, -0.4], [0.27, -0.15], [0.34, 0.15], [0.28, 0.45], [0.19, 0.7], [0.04, 0.86], [-0.08, 0.86]],
		"rays": [[0.2, -0.66], [0.28, -0.43], [0.25, -0.19], [0.29, 0.06], [0.29, 0.32], [0.21, 0.57], [0.12, 0.74]],
	},
	"fins_small_stabilizer": {
		"layout": "dorsal", "socket": [0.11, 0.1, 0.28],
		"outline": [[-0.08, -0.24], [0.08, -0.23], [0.43, -0.05], [0.53, 0.21], [0.31, 0.12], [0.04, 0.29], [-0.08, 0.29]],
		"rays": [[0.2, -0.15], [0.4, -0.02], [0.45, 0.15], [0.22, 0.14]],
	},
}
static var _cache: Dictionary = {}

static func articulation(id: String, revision: int = 1) -> Array[Dictionary]:
	var profile: Dictionary = Catalog.get_profile(id, revision)
	if profile.is_empty(): return []
	return [{"channel": "fin", "prefixes": ["FinSurface"], "pivot": Vector3.ZERO,
		"axis": Vector3.BACK, "degrees": 32.0 if profile.layout == "side" else 12.0}]

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
