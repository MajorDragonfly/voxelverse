extends SceneTree

const TEST_SEED: int = 606_606
const COARSE_STEP: float = 8.0
const FINE_STEP: float = 0.25

var _generator: Node
var _failures: Array[String] = []


func _initialize() -> void:
	_generator = root.get_node_or_null("WorldGenerator")
	_expect(_generator != null, "WorldGenerator autoload is missing.")
	if _generator == null:
		_finish()
		return
	_test_planet_profile()
	_test_continuous_region_height()
	_test_species_catalogue_seeds()
	_test_v6_resources()
	_finish()


func _test_planet_profile() -> void:
	_generator.call("set_seed_override", TEST_SEED)
	var first: Dictionary = _generator.call("get_planet_profile")
	_generator.call("set_seed_override", TEST_SEED)
	var repeated: Dictionary = _generator.call("get_planet_profile")
	_expect(int(first.get("planet_seed", 0)) == TEST_SEED, "Planet profile seed mismatch.")
	_expect(first.get("planet_name", "") == repeated.get("planet_name", ""), "Planet name was not deterministic.")
	_expect(is_equal_approx(float(first.get("relief_scale", 0.0)), float(repeated.get("relief_scale", -1.0))), "Planet relief was not deterministic.")
	_expect(int(first.get("fauna_species_count", 0)) >= 3, "Planet species catalogue is too small.")


func _test_continuous_region_height() -> void:
	_generator.call("set_seed_override", TEST_SEED)
	var maximum_coarse_jump: float = 0.0
	var maximum_fine_jump: float = 0.0
	var maximum_region_weight_delta: float = 0.0

	for world_z in [-768.0, -256.0, 0.0, 256.0, 768.0]:
		var previous_x: float = -1200.0
		var previous_height: float = float(
			_generator.call("get_terrain_height", previous_x, world_z)
		)
		var previous_profile: Dictionary = _generator.call(
			"get_region_profile",
			previous_x,
			world_z
		)
		var previous_weights: Vector4 = previous_profile.get(
			"weights",
			Vector4(1.0, 0.0, 0.0, 0.0)
		)

		for world_x_value in range(-1192, 1201, 8):
			var world_x: float = float(world_x_value)
			var height: float = float(
				_generator.call("get_terrain_height", world_x, world_z)
			)
			var coarse_jump: float = absf(height - previous_height)
			maximum_coarse_jump = maxf(maximum_coarse_jump, coarse_jump)

			var profile: Dictionary = _generator.call(
				"get_region_profile",
				world_x,
				world_z
			)
			var weights: Vector4 = profile.get(
				"weights",
				Vector4(1.0, 0.0, 0.0, 0.0)
			)
			maximum_region_weight_delta = maxf(
				maximum_region_weight_delta,
				(weights - previous_weights).length()
			)

			# A mountain or cliff may change several metres over eight world units.
			# A formula seam instead produces a large jump at sub-unit spacing.
			if coarse_jump > 1.5:
				var fine_previous: float = previous_height
				var fine_x: float = previous_x + FINE_STEP
				while fine_x <= world_x + 0.001:
					var fine_height: float = float(
						_generator.call("get_terrain_height", fine_x, world_z)
					)
					maximum_fine_jump = maxf(
						maximum_fine_jump,
						absf(fine_height - fine_previous)
					)
					fine_previous = fine_height
					fine_x += FINE_STEP

			previous_x = world_x
			previous_height = height
			previous_weights = weights

	print(
		"World Runtime V6 continuity: coarse %.3f, fine %.3f, weight delta %.3f"
		% [maximum_coarse_jump, maximum_fine_jump, maximum_region_weight_delta]
	)
	_expect(
		maximum_fine_jump < 1.20,
		"Continuous region field contains a sub-unit height seam."
	)
	_expect(
		maximum_region_weight_delta < 0.18,
		"Region blend weights change too abruptly."
	)


func _test_species_catalogue_seeds() -> void:
	var first: int = int(_generator.call("get_species_seed", 0, 0, 0))
	var repeated: int = int(_generator.call("get_species_seed", 0, 0, 0))
	var neighbour: int = int(_generator.call("get_species_seed", 1, 0, 0))
	var second_species: int = int(_generator.call("get_species_seed", 0, 0, 1))
	_expect(first == repeated, "Species seed was not deterministic.")
	_expect(first != neighbour, "Neighbouring regions received the same species seed.")
	_expect(first != second_species, "Species slots received the same seed.")


func _test_v6_resources() -> void:
	for path in [
		"res://world/generation/planet_profile_v6.gd",
		"res://world/generation/world_generator_v6.gd",
		"res://world/streaming/chunk_lod_controller_v6.gd",
		"res://world/visuals/terrain/micro_voxel_surface_v6.gd",
		"res://world/visuals/scenery/procedural_ecosystem_v6.gd",
		"res://world/visuals/scenery/voxel_asset_library_v6.gd",
		"res://world/fauna/fauna_streamer_v6.gd",
		"res://creatures/wildlife/procedural_wildlife_v6.tscn",
		"res://creatures/player/player_v6.gd",
		"res://main/main.tscn",
	]:
		_expect(load(path) != null, "V6 resource could not be loaded: %s" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("World Runtime V6 test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
