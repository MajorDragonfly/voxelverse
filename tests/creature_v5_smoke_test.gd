extends SceneTree

const Blueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const BlueprintV5 = preload(
	"res://creatures/editor/creature_blueprint_v5.gd"
)
const EvolutionGenerator = preload(
	"res://creatures/editor/creature_evolution_generator.gd"
)

const TEST_SEED: int = 314159265

var _failures: Array[String] = []


func _initialize() -> void:
	_run_generator_checks()
	_run_mutation_checks()
	_run_scene_resource_checks()

	if _failures.is_empty():
		print("Creature V5 smoke test passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)


func _run_generator_checks() -> void:
	for archetype in EvolutionGenerator.ARCHETYPES:
		var first: Dictionary = EvolutionGenerator.generate(
			TEST_SEED,
			archetype
		)
		var second: Dictionary = EvolutionGenerator.generate(
			TEST_SEED,
			archetype
		)

		_expect(
			not first.is_empty(),
			"Generator returned an empty blueprint for %s." % archetype
		)
		_expect(
			Blueprint.get_part_count(first) >= 2,
			"Generated %s creature has too few parts." % archetype
		)
		_expect(
			Blueprint.calculate_complexity(first)
			<= Blueprint.COMPLEXITY_LIMIT,
			"Generated %s creature exceeds complexity limit." % archetype
		)

		var first_path: String = "user://creature_v5_%s_a.json" % archetype
		var second_path: String = "user://creature_v5_%s_b.json" % archetype
		var first_error: Error = BlueprintV5.save_to_file(
			first,
			first_path
		)
		var second_error: Error = BlueprintV5.save_to_file(
			second,
			second_path
		)

		_expect(
			first_error == OK and second_error == OK,
			"Could not save deterministic %s test blueprints." % archetype
		)

		if first_error == OK and second_error == OK:
			_expect(
				_read_text(first_path) == _read_text(second_path),
				"Seeded generation is not deterministic for %s." % archetype
			)

		var loaded: Dictionary = BlueprintV5.load_from_file(first_path)
		var loaded_generation: Dictionary = loaded.get("generation", {})
		_expect(
			not loaded.is_empty(),
			"V5 round-trip load failed for %s." % archetype
		)
		_expect(
			int(loaded_generation.get("seed", 0)) == TEST_SEED,
			"V5 round-trip lost seed metadata for %s." % archetype
		)


func _run_mutation_checks() -> void:
	var parent: Dictionary = EvolutionGenerator.generate(
		TEST_SEED,
		"grazer"
	)
	var child: Dictionary = EvolutionGenerator.mutate(
		parent,
		TEST_SEED + 1,
		0.24
	)
	var parent_generation: Dictionary = parent.get("generation", {})
	var child_generation: Dictionary = child.get("generation", {})

	_expect(
		int(child_generation.get("generation", -1))
		== int(parent_generation.get("generation", 0)) + 1,
		"Mutation did not increment generation metadata."
	)
	_expect(
		int(child_generation.get("parent_seed", 0))
		== int(parent_generation.get("seed", 0)),
		"Mutation did not retain the parent seed."
	)
	_expect(
		Blueprint.calculate_complexity(child)
		<= Blueprint.COMPLEXITY_LIMIT,
		"Mutated creature exceeds complexity limit."
	)


func _run_scene_resource_checks() -> void:
	_expect(
		load("res://creatures/editor/creature_editor.tscn") != null,
		"Creature Lab V5 scene could not be loaded."
	)
	_expect(
		load("res://creatures/player/player.tscn") != null,
		"Player scene with runtime creature bridge could not be loaded."
	)
	_expect(
		load("res://main/main.tscn") != null,
		"Main scene could not be loaded."
	)


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return ""

	var content: String = file.get_as_text()
	file.close()
	return content
