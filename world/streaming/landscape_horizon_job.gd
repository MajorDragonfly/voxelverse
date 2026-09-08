extends RefCounted

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
	var water := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var water_colors := PackedColorArray()
	var indices := PackedInt32Array()
	var sea: float = generator.get_sea_level() + 0.03
	for z in range(side):
		for x in range(side):
			var point: Vector2 = center + Vector2(x * STEP - RADIUS, z * STEP - RADIUS)
			var height: float = generator.get_visual_terrain_height(point.x, point.y)
			vertices.append(Vector3(point.x, height - 0.12, point.y))
			water.append(Vector3(point.x, sea, point.y))
			colors.append(generator.get_biome_color(point.x, point.y, height))
			var depth: float = maxf(sea - height, 0.0)
			water_colors.append(Color(smoothstep(0.0, 4.8, depth), 1.0 - smoothstep(0.04, 0.85, depth), 0.0, 1.0))
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
	var water_arrays: Array = arrays.duplicate()
	water_arrays[Mesh.ARRAY_VERTEX] = water
	water_arrays[Mesh.ARRAY_COLOR] = water_colors
	var up := PackedVector3Array()
	up.resize(water.size())
	up.fill(Vector3.UP)
	water_arrays[Mesh.ARRAY_NORMAL] = up
	result = {"terrain": arrays, "water": water_arrays}
	generator.free()
