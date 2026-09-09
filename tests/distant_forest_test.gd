extends SceneTree

const Generator = preload("res://world/generation/world_generator_planetary_v9.gd")
const Terrain = preload("res://world/streaming/terrain_build_job.gd")
const Placement = preload("res://world/streaming/environment_placement_job.gd")
const Forest = preload("res://world/streaming/distant_forest_job.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var generator := Generator.new()
	generator.set_seed_override(15838)
	var spawn: Vector3 = generator.get_scenic_spawn()
	var center := Vector2(snappedf(spawn.x, 32), snappedf(spawn.z, 32))
	var tree_count: int = 0
	for offset: Vector2 in [Vector2.ZERO, Vector2(-32, -32), Vector2(32, 0)]:
		var terrain := Terrain.new()
		terrain.generator_script = Generator
		terrain.world_seed = 15838
		terrain.chunk_origin = center + offset
		terrain.cell_size = 0.5
		terrain.cells_x = 64
		terrain.cells_z = 64
		terrain.color_sample_stride = 2
		terrain.run()
		var cases: Array = []
		for sampled in [false, true]:
			var job := Placement.new()
			job.generator_script = Generator
			job.world_seed = 15838
			job.chunk_origin = center + offset
			job.width = 32
			job.depth = 32
			job.cell_size = 0.5
			job.height_width = 66
			job.height_depth = 66
			job.spawn_clear_center = Vector2(spawn.x, spawn.z)
			job.recipes = [Placement.tree_recipe()]
			if not sampled:
				job.heights = terrain.result.heights
			job.run(generator)
			cases.append(job.result)
		_expect(cases[0] == cases[1], "Distant tree positions/species differ from actual playable chunk placement.")
		tree_count += cases[0].instances
	_expect(tree_count > 3, "Forest parity fixture did not exercise enough trees.")
	var forest := Forest.new()
	forest.generator_script = Generator
	forest.world_seed = 15838
	forest.center = center
	forest.spawn_center = Vector2(spawn.x, spawn.z)
	forest.run()
	_expect(forest.result.trees > tree_count and forest.result.trees <= Forest.MAX_TREES and forest.result.batches.size() <= 6, "Forest is empty or exceeds fixed budgets.")
	var seen: Dictionary = {}
	for batch: Dictionary in forest.result.batches.values():
		_expect(batch.transforms.size() == batch.custom.size(), "Forest instance attributes do not match transforms.")
		for transform: Transform3D in batch.transforms:
			var key: String = str(transform.origin)
			_expect(not seen.has(key), "A tree was duplicated across preview tiles.")
			seen[key] = true
			_expect(Vector2(transform.origin.x, transform.origin.z).distance_to(center) <= Forest.RADIUS + 24, "Tree is outside the bounded preview.")
	print("Distant forest data ", JSON.stringify({"near_parity_trees": tree_count, "preview_trees": forest.result.trees, "batches": forest.result.batches.size(), "worker_ms": forest.result.worker_ms}))
	generator.free()
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
