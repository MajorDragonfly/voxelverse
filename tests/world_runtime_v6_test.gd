extends SceneTree

const TEST_SEED: int = 606_606

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
	var maximum_adjacent_jump: float = 0.0
	for world_z in [-768.0, -256.0, 0.0, 256.0, 768.0]:
		var previous_height: float = float(
			_generator.call("get_terrain_height", -1200.0, world_z)
		)
		for world_x in range(-1192, 1201, 8):
			var height: float = float(
				_generator.call("get_terrain_height", float(world_x), world_z)
			)
			maximum_adjacent_jump = maxf(
				maximum_adjacent_jump,
				absf(height - previous_height)
			)
			previous_height = height
	print("World Runtime V6 maximum adjacent logical-height jump: ", maximum_adjacent_jump)
	_expect(maximum_adjacent_jump < 4.5, "Continuous region field contains an extreme height seam.")


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
