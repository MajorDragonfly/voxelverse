extends SceneTree

const TEST_SEED: int = 606_606
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
	_test_active_runtime_resources()
	_finish()


func _test_planet_profile() -> void:
	_generator.call("set_seed_override", TEST_SEED)
	var first: Dictionary = _generator.call("get_planet_profile")
	_generator.call("set_seed_override", TEST_SEED)
	var repeated: Dictionary = _generator.call("get_planet_profile")
	_expect(int(first.get("planet_seed", 0)) == TEST_SEED, "Planet profile seed mismatch.")
	_expect(first.get("planet_name", "") == repeated.get("planet_name", ""), "Planet name was not deterministic.")
	_expect(int(first.get("fauna_species_count", 0)) >= 3, "Planet species catalogue is too small.")
	_expect(str(first.get("terrain_archetype", "")).length() > 0, "Adventure terrain archetype is missing.")
	_expect(float(first.get("snow_start_altitude", 0.0)) >= 14.0, "Planet snow line is implausibly low.")


func _test_continuous_region_height() -> void:
	_generator.call("set_seed_override", TEST_SEED)
	var maximum_fine_jump: float = 0.0
	for world_z in [-512.0, -128.0, 0.0, 128.0, 512.0]:
		var previous_x: float = -800.0
		var previous_height: float = float(_generator.call("get_terrain_height", previous_x, world_z))
		for world_x_value in range(-792, 801, 8):
			var world_x: float = float(world_x_value)
			var height: float = float(_generator.call("get_terrain_height", world_x, world_z))
			if absf(height - previous_height) > 1.5:
				var fine_previous: float = previous_height
				var fine_x: float = previous_x + FINE_STEP
				while fine_x <= world_x + 0.001:
					var fine_height: float = float(_generator.call("get_terrain_height", fine_x, world_z))
					maximum_fine_jump = maxf(maximum_fine_jump, absf(fine_height - fine_previous))
					fine_previous = fine_height
					fine_x += FINE_STEP
			previous_x = world_x
			previous_height = height
	_expect(maximum_fine_jump < 1.20, "Continuous terrain contains a sub-unit height seam.")


func _test_species_catalogue_seeds() -> void:
	var first: int = int(_generator.call("get_species_seed", 0, 0, 0))
	var repeated: int = int(_generator.call("get_species_seed", 0, 0, 0))
	var neighbour: int = int(_generator.call("get_species_seed", 1, 0, 0))
	var second_species: int = int(_generator.call("get_species_seed", 0, 0, 1))
	_expect(first == repeated, "Species seed was not deterministic.")
	_expect(first != neighbour, "Neighbouring regions received the same species seed.")
	_expect(first != second_species, "Species slots received the same seed.")


func _test_active_runtime_resources() -> void:
	for path in [
		"res://world/generation/world_generator_adventure.gd",
		"res://world/generation/planet_profile_v8.gd",
		"res://world/resources/terrain/terrain_chunk_v8.gd",
		"res://world/visuals/terrain/terrain_chunk.tscn",
		"res://world/simulation/region_ecology_simulation.gd",
		"res://world/fauna/fauna_streamer_v7.gd",
		"res://creatures/player/player_controller_v2.gd",
		"res://creatures/player/player.tscn",
		"res://main/main.tscn",
	]:
		_expect(load(path) != null, "Active runtime resource failed: %s" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("World runtime continuity test passed.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0)
		return
	for failure in _failures:
		push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 1)
