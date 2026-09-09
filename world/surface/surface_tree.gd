extends StaticBody3D

## Reuses the campaign's authored oak and its catalog collision dimensions.
const Catalog = preload("res://assets/catalog/asset_catalog.gd")
const ASSET_ID: String = "ancient_oak_v2"


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var model: PackedScene = load(Catalog.get_scene_path(ASSET_ID))
	add_child(model.instantiate())
	var dimensions: Dictionary = Catalog.get_asset(ASSET_ID).collision
	var shape := CapsuleShape3D.new()
	shape.radius = dimensions.radius
	shape.height = dimensions.height
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
