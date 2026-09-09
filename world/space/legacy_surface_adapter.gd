extends RefCounted
class_name LegacySurfaceAdapter

## The same sample contract, with explicitly preserved X/Z coordinates.
var generator: Node
var body_id: String


func _init(world_generator: Node, id: String) -> void:
	generator = world_generator
	body_id = id


func sample(location: Dictionary) -> Dictionary:
	assert(location.get("mode") == "legacy_plane_v9" and location.get("body_id") == body_id)
	var p: Array = location.position
	var x: float = p[0]
	var z: float = p[2]
	var h: float = generator.get_terrain_height(x, z)
	var step: float = 0.25
	var dx: float = generator.get_terrain_height(x + step, z) - generator.get_terrain_height(x - step, z)
	var dz: float = generator.get_terrain_height(x, z + step) - generator.get_terrain_height(x, z - step)
	return {"height": h, "water_level": generator.get_water_level(x, z),
		"water": generator.is_water_at(x, z), "normal": Vector3(-dx, 2.0 * step, -dz).normalized(),
		"biome": generator.get_biome_key(x, z, h),
		"blocked": false}
