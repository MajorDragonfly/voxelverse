extends StaticBody3D

# One compound body per chunk, no node hierarchy per plant. The compact trunk,
# woody shrub core and rock hull are independent of visual LOD and wind.
const Catalog = preload("res://assets/catalog/asset_catalog.gd")
var shape_count: int = 0
var instances: Array[Dictionary] = []

static func has_collision(asset_id: String) -> bool:
	return Catalog.get_asset(asset_id).get("collision", "none") is Dictionary

func _init() -> void:
	collision_layer = 1
	collision_mask = 0

func add_batch(batch: Dictionary) -> void:
	var recipe: Dictionary = Catalog.get_asset(batch["asset_id"]).get("collision", {})
	recipe = recipe.get("variants", {}).get(str(batch["species"]["geometry_variant"]), recipe)
	if recipe.is_empty():
		return
	for transform: Transform3D in batch["transforms"]:
		var scale_value: Vector3 = transform.basis.get_scale()
		var shape: Shape3D
		var center := Vector3.ZERO
		if recipe["type"] == "capsule":
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
		shape_owner_set_transform(owner_id, local_transform)
		shape_owner_add_shape(owner_id, shape)
		instances.append({"asset_id": batch["asset_id"], "owner": owner_id, "transform": local_transform})
		shape_count += 1
