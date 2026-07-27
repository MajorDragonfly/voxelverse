extends SceneTree

const GeneratorScript = preload(
	"res://world/generation/world_generator_v2.gd"
)

const PRIMARY_TEST_SEED: int = 424_242
const SECONDARY_TEST_SEED: int = 515_151
const SAMPLE_MIN: int = -3600
const SAMPLE_MAX: int = 3600
const SAMPLE_STEP: int = 600

var _failures: Array[String] = []
var _generator: Node


func _initialize() -> void:
	print("World test stage: initialize generator")
	_generator = GeneratorScript.new()
	root.add_child(_generator)

	_run_world_generator_checks()
	print("World test stage: load scene resources")
	_run_scene_resource_checks()

	if _failures.is_empty():
		print("World Evolution V2 smoke test passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)


func _run_world_generator_checks() -> void:
	print("World test stage: sample primary seed")
	_generator.set_seed_override(PRIMARY_TEST_SEED)
	var first_samples: Array[float] = []
	var biome_counts: Dictionary = {}
	var minimum_height: float = INF
	var maximum_height: float = -INF
	var sampled_rows: int = 0

	for world_z in range(SAMPLE_MIN, SAMPLE_MAX + 1, SAMPLE_STEP):
		for world_x in range(SAMPLE_MIN, SAMPLE_MAX + 1, SAMPLE_STEP):
			var sample: Dictionary = _generator.sample_world(
				float(world_x),
				float(world_z)
			)
			var height: float = float(sample.get("height", 0.0))
			var visual_height: float = float(sample.get("visual_height", 0.0))
			var biome: int = int(sample.get("biome", -1))
			var temperature: float = float(sample.get("temperature", -1.0))
			var moisture: float = float(sample.get("moisture", -1.0))
			var slope: float = float(sample.get("slope", -1.0))
			var river: float = float(sample.get("river", -1.0))
			var lake: float = float(sample.get("lake", -1.0))

			_expect(
				not is_nan(height) and not is_inf(height),
				"Terrain produced a non-finite height at %d/%d." % [world_x, world_z]
			)
			_expect(
				height >= -7.01 and height <= 18.01,
				"Terrain height is outside the declared world range."
			)
			_expect(
				is_equal_approx(
					visual_height,
					snappedf(height, 0.5)
				),
				"Visual terrain height is not aligned to half-voxel terraces."
			)
			_expect(
				biome >= GeneratorScript.Biome.OCEAN
				and biome <= GeneratorScript.Biome.RIVER,
				"World generator returned an invalid biome index."
			)
			_expect(
				temperature >= 0.0 and temperature <= 1.0,
				"Temperature is outside the normalized range."
			)
			_expect(
				moisture >= 0.0 and moisture <= 1.0,
				"Moisture is outside the normalized range."
			)
			_expect(
				slope >= 0.0 and slope <= 2.0,
				"Slope is outside the normalized range."
			)
			_expect(
				river >= 0.0 and river <= 1.0
				and lake >= 0.0 and lake <= 1.0,
				"Hydrology values are outside the normalized range."
			)

			minimum_height = minf(minimum_height, height)
			maximum_height = maxf(maximum_height, height)
			first_samples.append(height)
			biome_counts[biome] = int(biome_counts.get(biome, 0)) + 1

		sampled_rows += 1
		print("World test stage: sampled primary row %d" % sampled_rows)

	print(
		"World sample seed %d: height %.3f..%.3f, range %.3f, biomes %d, samples %d"
		% [
			PRIMARY_TEST_SEED,
			minimum_height,
			maximum_height,
			maximum_height - minimum_height,
			biome_counts.size(),
			first_samples.size(),
		]
	)

	_expect(
		maximum_height - minimum_height >= 8.0,
		"The sampled world lacks sufficient elevation diversity."
	)
	_expect(
		biome_counts.size() >= 5,
		"The sampled world produced fewer than five distinct biomes."
	)

	print("World test stage: verify deterministic repeat")
	_generator.set_seed_override(PRIMARY_TEST_SEED)
	var repeated_index: int = 0

	for world_z in range(SAMPLE_MIN, SAMPLE_MAX + 1, SAMPLE_STEP):
		for world_x in range(SAMPLE_MIN, SAMPLE_MAX + 1, SAMPLE_STEP):
			var repeated_height: float = _generator.get_terrain_height(
				float(world_x),
				float(world_z)
			)
			_expect(
				is_equal_approx(repeated_height, first_samples[repeated_index]),
				"The same world seed did not reproduce identical terrain."
			)
			repeated_index += 1

	print("World test stage: compare secondary seed")
	_generator.set_seed_override(SECONDARY_TEST_SEED)
	var changed_samples: int = 0
	var comparison_index: int = 0

	for world_z in range(SAMPLE_MIN, SAMPLE_MAX + 1, SAMPLE_STEP):
		for world_x in range(SAMPLE_MIN, SAMPLE_MAX + 1, SAMPLE_STEP):
			var changed_height: float = _generator.get_terrain_height(
				float(world_x),
				float(world_z)
			)
			if absf(changed_height - first_samples[comparison_index]) > 0.05:
				changed_samples += 1
			comparison_index += 1

	print(
		"World sample seed comparison: %d of %d terrain samples changed"
		% [changed_samples, first_samples.size()]
	)

	_expect(
		changed_samples > first_samples.size() / 3,
		"Changing the seed did not materially change the world layout."
	)


func _run_scene_resource_checks() -> void:
	for scene_path in [
		"res://main/main.tscn",
		"res://world/world_manager.tscn",
		"res://world/visuals/terrain/terrain_chunk.tscn",
		"res://world/visuals/planet_visual_environment.tscn",
		"res://creatures/player/player.tscn",
		"res://creatures/editor/creature_editor.tscn",
	]:
		_expect(
			load(scene_path) != null,
			"Required scene could not be loaded: %s" % scene_path
		)

	for script_path in [
		"res://world/generation/world_generator_v2.gd",
		"res://world/world_manager_v2.gd",
		"res://world/resources/terrain/terrain_chunk_v2.gd",
		"res://world/visuals/scenery/procedural_biome_assets.gd",
		"res://world/visuals/scenery/terrain_scenic_dressing_v2.gd",
		"res://world/visuals/world_presentation_director.gd",
		"res://creatures/runtime/procedural_locomotion_animator.gd",
		"res://core/display_settings.gd",
		"res://ui/hud_presentation.gd",
	]:
		_expect(
			load(script_path) != null,
			"Required script could not be loaded: %s" % script_path
		)


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
