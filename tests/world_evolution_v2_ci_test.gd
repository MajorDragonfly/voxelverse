extends SceneTree

const PRIMARY_SEED: int = 424_242
const SECONDARY_SEED: int = 515_151
const BIOME_MIN: int = 0
const BIOME_MAX: int = 15

var _failures: Array[String] = []
var _generator: Node


func _initialize() -> void:
	print("World test stage: resolve WorldGenerator autoload")
	_generator = root.get_node_or_null("WorldGenerator")

	if _generator == null:
		_failures.append("WorldGenerator autoload was not instantiated.")
		_finish()
		return

	_test_primary_world()
	_test_seed_reproducibility()
	_test_required_resources()
	_finish()


func _test_primary_world() -> void:
	print("World test stage: sample primary world")
	_generator.call("set_seed_override", PRIMARY_SEED)

	var heights: Array[float] = []
	var biomes: Dictionary = {}
	var minimum_height: float = INF
	var maximum_height: float = -INF

	for world_z in range(-3600, 3601, 600):
		for world_x in range(-3600, 3601, 600):
			var sample_value: Variant = _generator.call(
				"sample_world",
				float(world_x),
				float(world_z)
			)
			if not (sample_value is Dictionary):
				_failures.append("World sample was not a dictionary.")
				continue

			var sample: Dictionary = sample_value
			var height: float = float(sample.get("height", NAN))
			var biome: int = int(sample.get("biome", -1))
			var temperature: float = float(sample.get("temperature", -1.0))
			var moisture: float = float(sample.get("moisture", -1.0))
			var river: float = float(sample.get("river", -1.0))
			var lake: float = float(sample.get("lake", -1.0))

			_expect(not is_nan(height) and not is_inf(height), "Non-finite terrain height.")
			_expect(height >= -7.01 and height <= 18.01, "Terrain height outside range.")
			_expect(biome >= BIOME_MIN and biome <= BIOME_MAX, "Invalid biome index.")
			_expect(temperature >= 0.0 and temperature <= 1.0, "Temperature outside range.")
			_expect(moisture >= 0.0 and moisture <= 1.0, "Moisture outside range.")
			_expect(river >= 0.0 and river <= 1.0, "River value outside range.")
			_expect(lake >= 0.0 and lake <= 1.0, "Lake value outside range.")

			heights.append(height)
			minimum_height = minf(minimum_height, height)
			maximum_height = maxf(maximum_height, height)
			biomes[biome] = true

	print(
		"World sample seed %d: range %.3f, biomes %d, samples %d"
		% [PRIMARY_SEED, maximum_height - minimum_height, biomes.size(), heights.size()]
	)
	_expect(maximum_height - minimum_height >= 8.0, "World lacks elevation diversity.")
	_expect(biomes.size() >= 5, "World produced fewer than five biomes.")


func _test_seed_reproducibility() -> void:
	print("World test stage: verify seed reproducibility")
	var points: Array[Vector2] = [
		Vector2(-2800.0, -1900.0),
		Vector2(-1200.0, 900.0),
		Vector2(0.0, 0.0),
		Vector2(1350.0, -2250.0),
		Vector2(3100.0, 1700.0),
	]

	_generator.call("set_seed_override", PRIMARY_SEED)
	var baseline: Array[float] = []
	for point in points:
		baseline.append(float(_generator.call("get_terrain_height", point.x, point.y)))

	_generator.call("set_seed_override", PRIMARY_SEED)
	for index in range(points.size()):
		var repeated: float = float(_generator.call(
			"get_terrain_height",
			points[index].x,
			points[index].y
		))
		_expect(is_equal_approx(repeated, baseline[index]), "Same seed was not deterministic.")

	_generator.call("set_seed_override", SECONDARY_SEED)
	var changed_count: int = 0
	for index in range(points.size()):
		var changed: float = float(_generator.call(
			"get_terrain_height",
			points[index].x,
			points[index].y
		))
		if absf(changed - baseline[index]) > 0.05:
			changed_count += 1

	print("World sample seed comparison: %d of %d points changed" % [changed_count, points.size()])
	_expect(changed_count >= 3, "Different seed did not materially change terrain.")


func _test_required_resources() -> void:
	print("World test stage: load required resources")
	for path in [
		"res://main/main.tscn",
		"res://world/world_manager.tscn",
		"res://world/visuals/terrain/terrain_chunk.tscn",
		"res://world/visuals/planet_visual_environment.tscn",
		"res://creatures/player/player.tscn",
		"res://creatures/editor/creature_editor.tscn",
		"res://world/generation/world_generator_v2.gd",
		"res://world/resources/terrain/terrain_chunk_v2.gd",
		"res://world/visuals/scenery/procedural_biome_assets.gd",
		"res://creatures/runtime/procedural_locomotion_animator.gd",
		"res://core/display_settings.gd",
	]:
		_expect(load(path) != null, "Required resource could not be loaded: %s" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("World Evolution V2 CI test passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
