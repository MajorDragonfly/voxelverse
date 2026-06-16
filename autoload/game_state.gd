extends Node


enum Phase {
	CREATURE,
	TRIBE,
	ANCIENT_MEDIEVAL,
	NATION,
	SPACE,
	MULTIVERSE,
}


const RANDOM_WORLD_SEED_MIN: int = 1
const RANDOM_WORLD_SEED_MAX: int = 2_147_483_647

const PHASE_ABILITIES: Dictionary = {
	Phase.CREATURE: [
		&"bite",
		&"eat",
		&"drink",
		&"socialize",
		&"mate",
	],
	Phase.TRIBE: [
		&"bite",
		&"eat",
		&"drink",
		&"socialize",
		&"mate",
		&"gather",
		&"chop",
		&"mine",
		&"build",
	],
	Phase.ANCIENT_MEDIEVAL: [
		&"gather",
		&"chop",
		&"mine",
		&"build",
		&"farm",
		&"trade",
	],
	Phase.NATION: [
		&"gather",
		&"chop",
		&"mine",
		&"build",
		&"farm",
		&"trade",
		&"industrialize",
	],
	Phase.SPACE: [
		&"build",
		&"trade",
		&"industrialize",
		&"colonize",
		&"terraform",
	],
	Phase.MULTIVERSE: [
		&"build",
		&"trade",
		&"industrialize",
		&"colonize",
		&"terraform",
		&"travel_multiverse",
	],
}


# Jeder neue Durchlauf beginnt in der Kreaturenphase.
var current_phase: int = Phase.CREATURE

# V1: Standardmäßig erzeugt jeder Programmstart eine neue Welt.
# Für reproduzierbare Tests kann use_random_world_seed auf false
# gesetzt und fixed_world_seed angepasst werden.
var use_random_world_seed: bool = true
var fixed_world_seed: int = 12345

# Der aktive Seed wird von WorldGenerator, Terrain, Biomen,
# Objekten und Kreaturen als reproduzierbare Grundlage genutzt.
var world_seed: int = 12345

var _world_seed_initialized: bool = false


func _enter_tree() -> void:
	initialize_world_seed()


func initialize_world_seed(
	optional_seed: int = 0,
	use_provided_seed: bool = false
) -> void:
	if use_provided_seed:
		set_world_seed(optional_seed, false)
		return

	if use_random_world_seed:
		var random := RandomNumberGenerator.new()
		random.randomize()

		set_world_seed(
			random.randi_range(
				RANDOM_WORLD_SEED_MIN,
				RANDOM_WORLD_SEED_MAX
			),
			false
		)
		return

	set_world_seed(fixed_world_seed, false)


func start_new_random_world() -> void:
	use_random_world_seed = true
	initialize_world_seed()
	_rebuild_world_generator_if_available()


func start_world_with_seed(new_world_seed: int) -> void:
	use_random_world_seed = false
	fixed_world_seed = _sanitize_world_seed(new_world_seed)
	initialize_world_seed(fixed_world_seed, true)
	_rebuild_world_generator_if_available()


func set_world_seed(
	new_world_seed: int,
	rebuild_generator: bool = true
) -> void:
	world_seed = _sanitize_world_seed(new_world_seed)
	_world_seed_initialized = true

	print("GameState world seed: ", world_seed)

	if rebuild_generator:
		_rebuild_world_generator_if_available()


func get_world_seed() -> int:
	if not _world_seed_initialized:
		initialize_world_seed()

	return world_seed


func has_ability(ability: StringName) -> bool:
	var available_abilities: Array = PHASE_ABILITIES.get(
		current_phase,
		[]
	)

	return ability in available_abilities


func set_phase(new_phase: int) -> void:
	if not PHASE_ABILITIES.has(new_phase):
		push_warning("Unknown game phase: %s" % new_phase)
		return

	current_phase = new_phase

	print("Game phase changed to: ", get_phase_name())


func get_phase_name() -> String:
	match current_phase:
		Phase.CREATURE:
			return "Creature"
		Phase.TRIBE:
			return "Tribe"
		Phase.ANCIENT_MEDIEVAL:
			return "Ancient / Medieval"
		Phase.NATION:
			return "Nation"
		Phase.SPACE:
			return "Space"
		Phase.MULTIVERSE:
			return "Multiverse"
		_:
			return "Unknown"


func _sanitize_world_seed(new_world_seed: int) -> int:
	return clampi(
		new_world_seed,
		RANDOM_WORLD_SEED_MIN,
		RANDOM_WORLD_SEED_MAX
	)


func _rebuild_world_generator_if_available() -> void:
	var world_generator := get_node_or_null("/root/WorldGenerator")

	if world_generator == null:
		return

	if not world_generator.has_method("rebuild"):
		return

	world_generator.call_deferred("rebuild")
