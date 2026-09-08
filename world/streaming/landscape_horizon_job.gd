extends RefCounted

const WorldWater = preload("res://world/streaming/world_water_mesh_job.gd")

# A fixed-cost surface preview out to 384 m. It samples the active generator,
# so distant destinations become the same collidable terrain when approached.
const RADIUS: float = 384.0
const STEP: float = 8.0
var generator_script: Script
var world_seed: int
var center: Vector2
var result: Dictionary = {}

func run() -> void:
	var generator: Node = generator_script.new()
	generator.set_seed_override(world_seed)
	var side: int = roundi(RADIUS * 2.0 / STEP) + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for z in range(side):
		for x in range(side):
			var point: Vector2 = center + Vector2(x * STEP - RADIUS, z * STEP - RADIUS)
			var height: float = generator.get_visual_terrain_height(point.x, point.y)
			vertices.append(Vector3(point.x, height - 0.12, point.y))
			colors.append(generator.get_biome_color(point.x, point.y, height))
	for z in range(side):
		for x in range(side):
			var left: Vector3 = vertices[z * side + maxi(0, x - 1)]
			var right: Vector3 = vertices[z * side + mini(side - 1, x + 1)]
			var back: Vector3 = vertices[maxi(0, z - 1) * side + x]
			var front: Vector3 = vertices[mini(side - 1, z + 1) * side + x]
			normals.append((front - back).cross(right - left).normalized())
			if x < side - 1 and z < side - 1:
				var a: int = z * side + x
				indices.append_array(PackedInt32Array([a, a + side + 1, a + side, a, a + 1, a + side + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	result = {"terrain": arrays, "water": WorldWater.build(generator, center, RADIUS)}
	generator.free()
