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
const Registry = preload("res://core/campaign/body_registry.gd")
const STATE_SCHEMA: int = Registry.STATE_SCHEMA
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
var active_body_id: String = ""
var active_system_id: String = ""
var last_campaign_error: String = ""

var _world_seed_initialized: bool = false
var far_scheduler := preload("res://core/campaign/far_scheduler.gd").new()
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
		var elapsed: float = simulation_delta(delta)
		if elapsed <= 0: return
		campaign.data["elapsed_seconds"] = float(campaign.data["elapsed_seconds"]) + elapsed
		var progression: Node = get_node_or_null("/root/ProgressionService")
		var cooperation: float = float(progression.get_behavior_effect("group_cooperation", 1).value) if progression != null else 1.0
		far_scheduler.process(campaign.data, active_body_id, cooperation, progression.record_far_work.bind(self) if progression != null else Callable())


func simulation_delta(delta: float) -> float:
	var flow := get_node_or_null("/root/SessionFlow")
	if flow != null and flow.loading: return 0.0
	return maxf(delta, 0.0) * float(campaign.data.get("time_scale", 1.0))


func set_simulation_speed(speed: float) -> bool:
	if speed not in [0.0, 1.0, 2.0, 4.0]:
		return false
	campaign.data["time_scale"] = speed
	return true


func get_current_body() -> Dictionary:
	return campaign.get_body_by_id(active_body_id)


## Runtime services share the campaign's current record. Snapshot callers keep
## using get_current_body(); physics must not deep-copy all frozen fauna bodies.
func get_current_body_record() -> Dictionary:
	return campaign.body_record(active_body_id)


func campaign_scene() -> String:
	return Campaign.Surface.SCENE if get_current_body().get("surface_mode") == Campaign.Surface.Cube.MODE else "res://main/main.tscn"


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
		var epoch: Dictionary = preload("res://core/progression/civilization_contract.gd").describe(campaign.data, active_body_id, current_phase, new_phase)
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


func start_new_random_world(surface_mode: String = Campaign.SURFACE_MODE) -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null and saves.is_phase_transition_active():
		return
	use_random_world_seed = true
	_world_seed_initialized = false
	_system_seed_initialized = false
	current_phase = Phase.CREATURE
	current_planet_index = 0
	_prepare_campaign(surface_mode)
	initialize_world_seed()
	_reset_campaign_for_new_game()
	_rebuild_world_generator_if_available()


func start_world_with_seed(new_world_seed: int, surface_mode: String = Campaign.SURFACE_MODE) -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null and saves.is_phase_transition_active():
		return
	use_random_world_seed = false
	fixed_world_seed = _sanitize_world_seed(new_world_seed)
	_world_seed_initialized = false
	_system_seed_initialized = false
	current_phase = Phase.CREATURE
	current_planet_index = 0
	_prepare_campaign(surface_mode)
	initialize_world_seed(fixed_world_seed, true)
	_reset_campaign_for_new_game()
	_rebuild_world_generator_if_available()


func set_world_seed(
	new_world_seed: int,
	rebuild_generator: bool = true
) -> bool:
	var target_seed: int = _sanitize_world_seed(new_world_seed)
	var target_system: int = system_seed if _system_seed_initialized else target_seed
	var context: String = active_system_id if not active_system_id.is_empty() else Registry.system_identity(campaign.data.id, target_system)
	var body: Dictionary = campaign.ensure_body(target_seed, target_system, context)
	last_campaign_error = campaign.last_error
	if body.is_empty(): return false
	world_seed = target_seed
	active_body_id = body.id
	active_system_id = body.system_id
	_world_seed_initialized = true
	if not _system_seed_initialized:
		system_seed = world_seed
		_system_seed_initialized = true
	if rebuild_generator:
		_rebuild_world_generator_if_available()
	world_seed_changed.emit(world_seed)
	return true


func activate_planet(
	new_system_seed: int,
	planet_index: int,
	planet_seed: int
) -> bool:
	var context: String = active_system_id if new_system_seed == system_seed else ""
	var body: Dictionary = campaign.ensure_body(_sanitize_world_seed(planet_seed), _sanitize_world_seed(new_system_seed), context)
	if body.is_empty():
		last_campaign_error = campaign.last_error
		return false
	return activate_body(body.id, new_system_seed, planet_index)


func activate_body(body_id: String, new_system_seed: int, planet_index: int, rebuild_generator: bool = true) -> bool:
	var body: Dictionary = campaign.body_record(body_id)
	if body.is_empty():
		last_campaign_error = "Zielkörper ist nicht im Kampagnenregister."
		return false
	system_seed = _sanitize_world_seed(new_system_seed)
	_system_seed_initialized = true
	current_planet_index = maxi(planet_index, 0)
	world_seed = int(body.seed)
	_world_seed_initialized = true
	active_body_id = body.id
	active_system_id = body.system_id
	if rebuild_generator: _rebuild_world_generator_if_available()
	world_seed_changed.emit(world_seed)
	planet_changed.emit(system_seed, current_planet_index, world_seed)
	last_campaign_error = ""
	far_scheduler.rebuild(campaign.data)
	return true


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
		"system_id": active_system_id,
		"world_seed": get_world_seed(),
		"planet_index": get_current_planet_index(),
		"body_id": active_body_id,
		"campaign": campaign.export_state(),
	}


func import_state(data: Dictionary, rebuild_generator: bool = true) -> bool:
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
		var body: Dictionary = Registry.active(data)
		if body.is_empty() or not campaign.import_state(data.campaign):
			last_campaign_error = "Aktiver Körper oder Körperregister ist nicht eindeutig."
			return false
		active_body_id = body.id
		active_system_id = body.system_id
	else:
		var body: Dictionary = campaign.ensure_body(imported_world_seed, imported_system_seed)
		if body.is_empty(): return false
		active_body_id = body.id
		active_system_id = body.system_id
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
	last_campaign_error = ""
	far_scheduler.rebuild(campaign.data)
	return true


func _prepare_campaign(surface_mode: String) -> void:
	far_scheduler.queue.clear()
	campaign.reset()
	campaign.data.surface_policy = surface_mode
	active_body_id = ""
	active_system_id = ""


func _reset_campaign_for_new_game() -> void:
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
	active_system_id = Registry.system_identity(campaign.data.id, system_seed)


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
