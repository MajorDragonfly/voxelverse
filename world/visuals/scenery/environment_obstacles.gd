extends StaticBody3D

# One compound body per chunk, no node hierarchy per plant. The compact trunk,
# woody shrub core and rock hull are independent of visual LOD and wind.
const Catalog = preload("res://assets/catalog/asset_catalog.gd")
# Compact main-stem profiles from tools/art/build_benchmark.py oak()/pine().
# The old straight 3.4/5.2 m capsules missed visible upper/leaning wood. A single
# tapered convex core follows each authored variant; branches/leaves stay free.
# Each station is [x, y, z, radius], with half a Near voxel of edge allowance.
const STEMS: Dictionary = {
	"ancient_oak_v2": [
		[[0, 0, 0, 0.65], [-0.12, 1.25, 0.04, 0.49], [0.12, 2.5, -0.06, 0.38],
			[0.38, 3.5, 0.12, 0.29], [0.52, 4.7, 0.05, 0.21], [0.18, 5.8, -0.08, 0.08]],
		[[0, 0, 0, 0.42], [-0.14, 1.1, 0.08, 0.32], [0.22, 2.25, 0, 0.24], [0.32, 2.7, 0.1, 0.13]],
		[[0, 0, 0, 0.42], [-0.14, 1.1, 0.08, 0.32], [0.22, 2.25, 0, 0.24], [0.32, 4.32, 0.1, 0.13]]],
	"tall_pine_v2": [
		[[0, 0, 0, 0.38], [0.12, 4, -0.04, 0.23], [-0.12, 7.632, 0.12, 0.12], [0, 10.6, 0, 0.04]],
		[[0, 0, 0, 0.38], [0.12, 4, -0.04, 0.23], [-0.12, 6.192, 0.12, 0.12], [0, 8.6, 0, 0.04]],
		[[0, 0, 0, 0.32], [0.2, 1.5, 0, 0.25], [0.6, 3.2, 0, 0.18],
			[1, 5, 0.12, 0.12], [1.35, 6.8, 0.2, 0.035]]]
}
# Six immutable native hulls for the six authored stems. Individual sizes live
# on the shape owner, so streaming does not rebuild a convex hull per tree.
static var _stem_cores: Dictionary = {}
var shape_count: int = 0
var instances: Array[Dictionary] = []

static func has_collision(asset_id: String) -> bool:
	return Catalog.get_asset(asset_id).get("collision", "none") is Dictionary

func _init() -> void:
	collision_layer = 1
	collision_mask = 0

func add_batch(batch: Dictionary) -> void:
	var recipe: Dictionary = Catalog.get_asset(batch["asset_id"]).get("collision", {})
	var variant: int = int(batch["species"]["geometry_variant"])
	recipe = recipe.get("variants", {}).get(str(variant), recipe)
	if recipe.is_empty():
		return
	for transform: Transform3D in batch["transforms"]:
		var scale_value: Vector3 = transform.basis.get_scale()
		var shape: Shape3D
		var center := Vector3.ZERO
		if STEMS.has(batch["asset_id"]):
			var core: Dictionary = _stem_core(batch["asset_id"], variant)
			shape = core.shape
			center = core.center
		elif recipe["type"] == "capsule":
			var capsule := CapsuleShape3D.new()
			capsule.radius = float(recipe["radius"]) * maxf(scale_value.x, scale_value.z)
			capsule.height = maxf(float(recipe["height"]) * scale_value.y, capsule.radius * 2.0)
			center.y = capsule.height * 0.5
			shape = capsule
		else:
			var hull := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for vertex: Array in recipe["points"]:
				points.append(Vector3(vertex[0], vertex[1], vertex[2]) * scale_value)
			hull.points = points
			shape = hull
		var rotation: Basis = transform.basis.orthonormalized()
		var owner_id: int = create_shape_owner(self)
		var local_transform := Transform3D(rotation, transform.origin + rotation * center)
		if STEMS.has(batch["asset_id"]):
			local_transform = Transform3D(transform.basis, transform * center)
		shape_owner_set_transform(owner_id, local_transform)
		shape_owner_add_shape(owner_id, shape)
		instances.append({"asset_id": batch["asset_id"], "owner": owner_id, "transform": local_transform})
		shape_count += 1


static func _stem_core(asset_id: String, variant: int) -> Dictionary:
	variant = variant if variant in [0, 1, 2] else 0
	var key: String = "%s/%d" % [asset_id, variant]
	if _stem_cores.has(key): return _stem_cores[key]
	var stations: Array = STEMS[asset_id][variant]
	var first: Array = stations[0]
	var last: Array = stations[-1]
	var center := (Vector3(first[0], first[1], first[2]) + Vector3(last[0], last[1], last[2])) * 0.5
	var points := PackedVector3Array()
	for station: Array in stations:
		var radius: float = (float(station[3]) + 0.0625) / cos(PI / 8.0)
		for side in range(8):
			var angle: float = side * TAU / 8.0
			points.append(Vector3(station[0] + cos(angle) * radius, station[1], station[2] + sin(angle) * radius) - center)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_stem_cores[key] = {"shape": shape, "center": center}
	return _stem_cores[key]
