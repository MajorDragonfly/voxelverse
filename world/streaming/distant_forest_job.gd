extends RefCounted

const Placement = preload("res://world/streaming/environment_placement_job.gd")
const Transition = preload("res://world/streaming/terrain_transition.gd")
const RADIUS: float = 224.0
const MAX_TREES: int = 2048
var generator_script: Script
var world_seed: int
var center: Vector2
var chunk_size := Vector2(32, 32)
var cell_size: float = 0.5
var spawn_center: Vector2
var recipe: Dictionary = Placement.tree_recipe()
var result: Dictionary = {}

func run() -> void:
	var started: int = Time.get_ticks_usec()
	var generator: Node = generator_script.new()
	generator.set_seed_override(world_seed)
	var batches: Dictionary = {}
	var horizon_cache: Dictionary = {}
	var proxy_cache: Dictionary = {}
	var count: int = 0
	var coordinates: Array[Vector2i] = []
	var low := Vector2i(floori((center.x - RADIUS) / chunk_size.x), floori((center.y - RADIUS) / chunk_size.y))
	var high := Vector2i(ceili((center.x + RADIUS) / chunk_size.x), ceili((center.y + RADIUS) / chunk_size.y))
	for z in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if (Vector2(x, z) * chunk_size).distance_to(center) <= RADIUS:
				coordinates.append(Vector2i(x, z))
	coordinates.sort_custom(func(a: Vector2i, b: Vector2i):
		var da: float = (Vector2(a) * chunk_size).distance_squared_to(center)
		var db: float = (Vector2(b) * chunk_size).distance_squared_to(center)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	for coordinate in coordinates:
		var job := Placement.new()
		job.world_seed = world_seed
		job.chunk_origin = Vector2(coordinate) * chunk_size
		job.width = chunk_size.x
		job.depth = chunk_size.y
		job.cell_size = cell_size
		job.height_width = roundi(chunk_size.x / cell_size) + 2
		job.height_depth = roundi(chunk_size.y / cell_size) + 2
		job.spawn_clear_center = spawn_center
		job.recipes = [recipe]
		job.run(generator)
		for key: String in job.result.batches:
			var source: Dictionary = job.result.batches[key]
			if not batches.has(key):
				batches[key] = {"asset_id": source.asset_id, "species": source.species, "transforms": [], "custom": []}
			for index in range(source.transforms.size()):
				if count >= MAX_TREES:
					break
				var transform: Transform3D = source.transforms[index]
				transform.origin += Vector3(job.chunk_origin.x, 0, job.chunk_origin.y)
				var point := Vector2(transform.origin.x, transform.origin.z)
				var ground: float = transform.origin.y + 0.035
				var horizon: float = Transition.height_at(generator, point, Transition.HORIZON_STEP, horizon_cache)
				var proxy: float = Transition.height_at(generator, point, Transition.PROXY_STEP, proxy_cache)
				var shade: Color = source.custom[index]
				batches[key].transforms.append(transform)
				batches[key].custom.append(Color(shade.r, shade.g, horizon - ground, proxy - ground))
				count += 1
		if count >= MAX_TREES:
			break
	generator.free()
	result = {"batches": batches, "trees": count, "tiles": coordinates.size(), "worker_ms": (Time.get_ticks_usec() - started) / 1000.0}
