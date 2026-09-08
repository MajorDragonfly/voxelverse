extends RefCounted

const WorldWater = preload("res://world/streaming/world_water_mesh_job.gd")
const Surface = preload("res://world/streaming/voxel_surface_builder.gd")
const Transition = preload("res://world/streaming/terrain_transition.gd")

# A fixed-cost surface preview out to 384 m. It samples the active generator,
# so distant destinations become the same collidable terrain when approached.
const RADIUS: float = 384.0
const STEP: float = Transition.HORIZON_STEP
var generator_script: Script
var world_seed: int
var center: Vector2
var result: Dictionary = {}

func run() -> void:
	var generator: Node = generator_script.new()
	generator.set_seed_override(world_seed)
	var side: int = roundi(RADIUS * 2.0 / STEP)
	var heights := PackedVector3Array()
	var colors := PackedColorArray()
	for z in range(-1, side + 1):
		for x in range(-1, side + 1):
			var point: Vector2 = center + Vector2((x + 0.5) * STEP - RADIUS, (z + 0.5) * STEP - RADIUS)
			var height: float = generator.get_visual_terrain_height(point.x, point.y)
			heights.append(Vector3.ONE * height)
			colors.append(generator.get_biome_color(point.x, point.y, height))
	var arrays: Array = Surface.new().build(Vector2.ONE * RADIUS * 2.0, STEP, heights, colors)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		vertices[i] += Vector3(center.x, 0.0, center.y)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	result = {"terrain": arrays, "water": WorldWater.build(generator, center, RADIUS)}
	generator.free()
