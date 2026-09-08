extends RefCounted

const WorldWater = preload("res://world/streaming/world_water_mesh_job.gd")
const Surface = preload("res://world/streaming/voxel_surface_builder.gd")
const Transition = preload("res://world/streaming/terrain_transition.gd")

# A fixed-cost surface preview out to 384 m. It samples the active generator,
# so distant destinations become the same collidable terrain when approached.
const RADIUS: float = 384.0
const STEP: float = Transition.HORIZON_STEP
const BANDS: int = 4
const SAMPLING_WORKERS: int = 2
const COLOR_STEP: float = 4.0
var generator_script: Script
var world_seed: int
var center: Vector2
var result: Dictionary = {}
var _bands: Array[Dictionary] = []
var _water: Array = []

func run() -> void:
	prepare()
	for index in range(BANDS):
		sample_band(index)
	assemble()

func prepare() -> void:
	_bands.clear()
	for index in range(BANDS):
		_bands.append({})

func sample_band(index: int) -> void:
	# Each task owns a generator and buffers. No mutable generator cache is
	# shared between threads; band boundaries use identical world samples.
	var generator: Node = generator_script.new()
	generator.set_seed_override(world_seed)
	var side: int = roundi(RADIUS * 2.0 / STEP)
	var heights := PackedVector3Array()
	var colors := PackedColorArray()
	var first: int = -1 + (side + 2) * index / BANDS
	var last: int = -1 + (side + 2) * (index + 1) / BANDS
	var color_cache: Dictionary = {}
	for z in range(first, last):
		for x in range(-1, side + 1):
			var point: Vector2 = center + Vector2((x + 0.5) * STEP - RADIUS, (z + 0.5) * STEP - RADIUS)
			var height: float = generator.get_visual_terrain_height(point.x, point.y)
			heights.append(Vector3.ONE * height)
			colors.append(_color_at(generator, point, color_cache))
	_bands[index]["heights"] = heights
	_bands[index]["colors"] = colors
	if index == 0:
		_water = WorldWater.build(generator, center, RADIUS)
	generator.free()

func assemble() -> void:
	var heights := PackedVector3Array()
	var colors := PackedColorArray()
	for band: Dictionary in _bands:
		heights.append_array(band.heights)
		colors.append_array(band.colors)
	var arrays: Array = Surface.new().build(Vector2.ONE * RADIUS * 2.0, STEP, heights, colors)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		vertices[i] += Vector3(center.x, 0.0, center.y)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	result = {"terrain": arrays, "water": _water}
	_bands.clear()
	_water = []

static func _color_at(generator: Node, point: Vector2, cache: Dictionary) -> Color:
	# Colour varies more slowly than 2 m geometry. Interpolating one cached
	# world-aligned field avoids four costly biome evaluations per old column
	# while retaining continuous palette changes across the sampling bands.
	var grid: Vector2 = point / COLOR_STEP - Vector2.ONE * 0.5
	var cell := Vector2i(floori(grid.x), floori(grid.y))
	var fraction: Vector2 = grid - Vector2(cell)
	var samples: Array[Color] = []
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		var key: Vector2i = cell + offset
		if not cache.has(key):
			var p: Vector2 = (Vector2(key) + Vector2.ONE * 0.5) * COLOR_STEP
			cache[key] = generator.get_biome_color(p.x, p.y, generator.get_visual_terrain_height(p.x, p.y))
		samples.append(cache[key])
	return samples[0].lerp(samples[1], fraction.x).lerp(samples[2].lerp(samples[3], fraction.x), fraction.y)
