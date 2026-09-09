extends Node

signal phase_changed(new_phase: int)
signal world_seed_changed(new_seed: int)
signal planet_changed(system_seed: int, planet_index: int, planet_seed: int)
signal campaign_event(event: Dictionary)


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
const STATE_SCHEMA: int = 3
const Campaign = preload("res://core/campaign/campaign_state.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")


const PHASE_ABILITIES: Dictionary = {
	Phase.CREATURE: [&"bite", &"eat", &"drink", &"socialize", &"mate"],
	Phase.TRIBE: [&"bite", &"eat", &"drink", &"socialize", &"mate", &"gather", &"chop", &"mine", &"build"],
	Phase.ANCIENT_MEDIEVAL: [&"gather", &"chop", &"mine", &"build", &"farm", &"trade"],
	Phase.NATION: [&"gather", &"chop", &"mine", &"build", &"farm", &"trade", &"industrialize"],
	Phase.SPACE: [&"build", &"trade", &"industrialize", &"colonize", &"terraform"],
	Phase.MULTIVERSE: [&"build", &"trade", &"industrialize", &"colonize", &"terraform", &"travel_multiverse"],
}

var campaign := Campaign.new()
var current_phase: int = Phase.CREATURE
var use_random_world_seed: bool = true
var fixed_world_seed: int = 12345
var world_seed: int = 12345
var system_seed: int = 12345
var current_planet_index: int = 0

var _world_seed_initialized: bool = false
var _system_seed_initialized: bool = false


func _enter_tree() -> void:
	campaign.reset()
	initialize_world_seed()


func _process(delta: float) -> void:
	# No offline catch-up or campaign time spent in editors. SceneTree pause
	# stops this node; speed applies to campaign simulation, not player physics.
	var player := get_tree().get_first_node_in_group(&"player")
	var tribe := get_tree().get_first_node_in_group(&"tribe_controller")
	if (player != null and player.is_physics_processing()) or (tribe != null and tribe.is_active()):
		campaign.data["elapsed_seconds"] = float(campaign.data["elapsed_seconds"]) + simulation_delta(delta)


func simulation_delta(delta: float) -> float:
	return maxf(delta, 0.0) * float(campaign.data.get("time_scale", 1.0))


func set_simulation_speed(speed: float) -> bool:
	if speed not in [0.0, 1.0, 2.0, 4.0]:
		return false
	campaign.data["time_scale"] = speed
	return true


func get_current_body() -> Dictionary:
	return campaign.body_for_seed(get_world_seed(), get_system_seed())


func record_campaign_event(event: GameEvent) -> bool:
	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null and progression.is_behavior_transaction_active():
		return false
	if not campaign.accept_event(event, current_phase):
		return false
	# Commit reward state before any event observer can take a save snapshot.
	if progression != null:
		progression.call("apply_campaign_event", event)
	campaign_event.emit(event.to_dict())
	return true


func get_phase_transition_blockers(new_phase: int) -> Array[String]:
	if new_phase != current_phase + 1 or not PHASE_ABILITIES.has(new_phase):
		return ["Only the next supported phase can be entered."]
	if new_phase == Phase.TRIBE:
		var tribe := get_tree().get_first_node_in_group(&"tribe_controller")
		if tribe != null:
			return tribe.blockers()
	if new_phase in [2, 3]:
		var epoch: Dictionary = preload("res://core/progression/civilization_contract.gd").describe(campaign.data, str(world_seed), current_phase, new_phase)
		var reasons: Array[String] = []
		reasons.assign(epoch["blockers"])
		return reasons
	# Later phases still require their own playable loop and explicit handoff.
	return ["The gameplay and handoff for this phase are not implemented yet."]


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
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null and saves.is_phase_transition_active():
		return
	use_random_world_seed = true
	_world_seed_initialized = false
	_system_seed_initialized = false
	current_phase = Phase.CREATURE
	current_planet_index = 0
	initialize_world_seed()
	_reset_campaign_for_new_game()
	_rebuild_world_generator_if_available()


func start_world_with_seed(new_world_seed: int) -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null and saves.is_phase_transition_active():
		return
	use_random_world_seed = false
	fixed_world_seed = _sanitize_world_seed(new_world_seed)
	_world_seed_initialized = false
	_system_seed_initialized = false
	current_phase = Phase.CREATURE
	current_planet_index = 0
	initialize_world_seed(fixed_world_seed, true)
	_reset_campaign_for_new_game()
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
	if rebuild_generator:
		_rebuild_world_generator_if_available()
	world_seed_changed.emit(world_seed)


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
	planet_changed.emit(system_seed, current_planet_index, world_seed)


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
	var available_abilities: Array = PHASE_ABILITIES.get(current_phase, [])
	return ability in available_abilities


func set_phase(new_phase: int) -> void:
	# Backward compatible debug API. Normal progression uses SaveGameService.
	debug_set_phase(new_phase)


func debug_set_phase(new_phase: int) -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null and saves.is_phase_transition_active():
		return
	if not PHASE_ABILITIES.has(new_phase):
		push_warning("Unknown game phase: %s" % new_phase)
		return
	if current_phase == new_phase:
		return
	current_phase = new_phase
	phase_changed.emit(current_phase)


func get_phase_name() -> String:
	match current_phase:
		Phase.CREATURE: return "Creature"
		Phase.TRIBE: return "Tribe"
		Phase.ANCIENT_MEDIEVAL: return "Ancient / Medieval"
		Phase.NATION: return "Nation"
		Phase.SPACE: return "Space"
		Phase.MULTIVERSE: return "Multiverse"
		_: return "Unknown"


func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"phase": current_phase,
		"system_seed": get_system_seed(),
		"world_seed": get_world_seed(),
		"planet_index": get_current_planet_index(),
		"body_id": get_current_body()["id"],
		"campaign": campaign.export_state(),
	}


func import_state(data: Dictionary, rebuild_generator: bool = true) -> void:
	var imported_system_seed: int = _sanitize_world_seed(
		int(data.get("system_seed", data.get("world_seed", 12345)))
	)
	var imported_world_seed: int = _sanitize_world_seed(
		int(data.get("world_seed", imported_system_seed))
	)
	var imported_phase: int = int(data.get("phase", Phase.CREATURE))
	if not PHASE_ABILITIES.has(imported_phase):
		imported_phase = Phase.CREATURE
	if data.get("campaign", {}) is Dictionary and not data.get("campaign", {}).is_empty():
		campaign.import_state(data["campaign"])
	use_random_world_seed = false
	fixed_world_seed = imported_system_seed
	system_seed = imported_system_seed
	world_seed = imported_world_seed
	current_planet_index = maxi(int(data.get("planet_index", 0)), 0)
	current_phase = imported_phase
	_system_seed_initialized = true
	_world_seed_initialized = true
	if rebuild_generator:
		_rebuild_world_generator_if_available()
	world_seed_changed.emit(world_seed)
	phase_changed.emit(current_phase)
	planet_changed.emit(system_seed, current_planet_index, world_seed)


func _reset_campaign_for_new_game() -> void:
	campaign.reset()
	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null:
		progression.call("reset_for_new_game")
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		saves.call("reset_runtime_for_new_game")


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
