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

# Standardmäßig erzeugt jeder Programmstart ein neues deterministisches System.
# Für reproduzierbare Tests kann use_random_world_seed auf false gesetzt werden.
var use_random_world_seed: bool = true
var fixed_world_seed: int = 12345

# world_seed beschreibt immer den aktuell besuchten Planeten. system_seed bleibt
# beim Wechsel zwischen Planeten stabil und reproduziert den gesamten Katalog.
var world_seed: int = 12345
var system_seed: int = 12345
var current_planet_index: int = 0

var _world_seed_initialized: bool = false
var _system_seed_initialized: bool = false


func _enter_tree() -> void:
	initialize_world_seed()


func initialize_world_seed(
	optional_seed: int = 0,
	use_provided_seed: bool = false
) -> void:
	if use_provided_seed:
		var provided_seed: int = _sanitize_world_seed(optional_seed)
		_set_system_seed_for_new_run(provided_seed)
		set_world_seed(provided_seed, false)
		return
	if use_random_world_seed:
		var random := RandomNumberGenerator.new()
		random.randomize()
		var random_seed: int = random.randi_range(
			RANDOM_WORLD_SEED_MIN,
			RANDOM_WORLD_SEED_MAX
		)
		_set_system_seed_for_new_run(random_seed)
		set_world_seed(random_seed, false)
		return
	var fixed_seed: int = _sanitize_world_seed(fixed_world_seed)
	_set_system_seed_for_new_run(fixed_seed)
	set_world_seed(fixed_seed, false)


func start_new_random_world() -> void:
	use_random_world_seed = true
	_world_seed_initialized = false
	_system_seed_initialized = false
	current_planet_index = 0
	initialize_world_seed()
	_rebuild_world_generator_if_available()


func start_world_with_seed(new_world_seed: int) -> void:
	use_random_world_seed = false
	fixed_world_seed = _sanitize_world_seed(new_world_seed)
	_world_seed_initialized = false
	_system_seed_initialized = false
	current_planet_index = 0
	initialize_world_seed(fixed_world_seed, true)
	_rebuild_world_generator_if_available()


func set_world_seed(
	new_world_seed: int,
	rebuild_generator: bool = true
) -> void:
	world_seed = _sanitize_world_seed(new_world_seed)
	_world_seed_initialized = true
	if not _system_seed_initialized:
		system_seed = world_seed
		_system_seed_initialized = true
	print("GameState world seed: ", world_seed)
	if rebuild_generator:
		_rebuild_world_generator_if_available()


func activate_planet(
	new_system_seed: int,
	planet_index: int,
	planet_seed: int
) -> void:
	system_seed = _sanitize_world_seed(new_system_seed)
	_system_seed_initialized = true
	current_planet_index = maxi(planet_index, 0)
	set_world_seed(planet_seed, false)
	_rebuild_world_generator_if_available()
	print(
		"Activated planet %d in system %d with world seed %d"
		% [current_planet_index, system_seed, world_seed]
	)


func get_world_seed() -> int:
	if not _world_seed_initialized:
		initialize_world_seed()
	return world_seed


func get_system_seed() -> int:
	if not _system_seed_initialized:
		get_world_seed()
		system_seed = world_seed
		_system_seed_initialized = true
	return system_seed


func get_current_planet_index() -> int:
	return maxi(current_planet_index, 0)


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


func _set_system_seed_for_new_run(new_seed: int) -> void:
	system_seed = _sanitize_world_seed(new_seed)
	_system_seed_initialized = true
	current_planet_index = 0


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
	if world_generator.has_method("set_world_seed"):
		world_generator.call_deferred("set_world_seed", world_seed)
		return
	if world_generator.has_method("rebuild"):
		world_generator.call_deferred("rebuild")
