extends "res://tests/wildlife_ai_test.gd"
## Production actors/physics and real atomic saves; no replacement AI.
var state: Node
var saves: Node
var progression: Node
var checks: int = 0
var observations: Dictionary = {}
const SAVE = "user://wildlife_hunting.json"

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	progression = root.get_node("ProgressionService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	state.start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	_build_fixture()
	player.position = Vector3(30, 100.05, 30)
	await _frames(3)
	if "--hunt-restart" in OS.get_cmdline_user_args():
		await _restart()
	else:
		await _live_hunt()
		await _selection_and_lifecycle()
		await _meals_and_persistence()
	scene.queue_free()
	await _frames(4)
	print(JSON.stringify({"test": "wildlife_hunting", "passed": failures.is_empty(), "checks": checks, "observations": observations, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _creature(role: String, point: Vector3, species: int) -> CharacterBody3D:
	var actor: CharacterBody3D = _animal(role, point, species)
	actor.current_health = actor.maximum_health
	actor.hydration = 90.0
	actor._drinking.hydration = 90.0
	actor._drinking.seeking = false
	actor._ambient_heading = Vector3.ZERO
	actor._decision_timer = 1000.0
	actor._visual_root.rotation.y = -PI * 0.5
	_feed_state(actor, 30.0 if role in ["predator", "scavenger"] else 90.0)
	return actor

func _feed_state(actor: Node, value: float) -> void:
	actor.satiety = value
	actor._needs.satiety = value
	actor._needs.seeking = value < 45.0
	actor._meal_rest = 0.0

func _clear() -> void:
	for actor: Node in get_nodes_in_group(&"wildlife"): actor.queue_free()
	await _frames(3)

func _live_hunt() -> void:
	var hunter: CharacterBody3D = _creature("predator", Vector3(0, 100.05, 0), 411)
	var prey: CharacterBody3D = _creature("grazer", Vector3(4, 100.05, 0), 771)
	
	# A slower prey species provides a successful chase alongside the separate
	# timeout case; its fleeing, collision, health and death remain production AI.
	prey._move_speed = 1.0
	var origin: Vector3 = hunter.position
	var prey_origin: Vector3 = prey.position
	var prey_id: String = prey.get_campaign_identity().object_id
	var points: int = progression.discovery_points
	var paths: Dictionary = progression.export_state().get("behavior", {}).duplicate(true)
	var seen: Dictionary = {}
	var died: bool = false
	for tick in range(1000):
		await _frames(1)
		seen[hunter._intent] = true
		if is_instance_valid(prey): died = died or prey.is_dead
		if hunter.satiety > 39.0: break
	_expect(seen.has("hunt") and hunter.position.distance_to(origin) > 1.0, "Hungry predator did not physically pursue prey: " + str(hunter.get_ai_debug_state()))
	_expect(not is_instance_valid(prey) or prey.position.distance_to(prey_origin) > 0.3, "Live prey did not attempt to escape")
	_expect(died and hunter.satiety > 39.0, "Hunt never produced a real meal: " + str(hunter.get_ai_debug_state()))
	var stored: Dictionary = progression.get_saved_creature_encounter(prey_id)
	_expect(stored.get("dead", false) and stored.get("carcass_food", 90.0) < 90.0 and not stored.get("player_harmed", false), "Third-party death/finite carcass was not persisted")
	_expect(progression.discovery_points == points and progression.export_state().get("behavior", {}) == paths, "Animal hunt rewarded the player")
	observations.live = {"intents": seen.keys(), "distance": hunter.position.distance_to(origin), "satiety": hunter.satiety, "prey": stored}
	await _clear()

func _selection_and_lifecycle() -> void:
	var hunter: CharacterBody3D = _creature("predator", Vector3(0, 100.05, 0), 411)
	var prey: CharacterBody3D = _creature("grazer", Vector3(3, 100.05, 0), 771)
	hunter.set_physics_process(false)
	prey.set_physics_process(false)
	await _frames(3)
	hunter._sense()
	_expect(hunter._hunt_target == prey, "Visible wild prey not selected")
	for reason: String in ["full", "attention", "phase", "body", "friend", "catalog", "owned", "same_species", "own_species", "scavenger", "unloaded"]:
		var identity: Dictionary = prey._campaign_identity.duplicate(true)
		var entry: Dictionary = prey.get_node("SocialBehavior").entry()
		var original: Dictionary = entry.duplicate(true)
		var body: Dictionary = state.get_current_body_record()
		var had_ownership: bool = body.has("domesticated_animals")
		var ownership: Dictionary = body.get("domesticated_animals", {}).duplicate(true)
		match reason:
			"full": _feed_state(hunter, 90.0)
			"attention": hunter.get_node("SocialBehavior").attention_remaining = 2.0
			"phase": state.current_phase = 2
			"body": prey._campaign_identity.body_id = "another_body"
			"friend":
				entry.relation = "ally"
				entry.trust = 100.0
				progression.store_creature_encounter(entry)
			"catalog": prey.catalog_species = {"id": "protected_catalog"}
			"owned": body.domesticated_animals = {"registry": {"animals": {identity.object_id: {"status": "claimed"}}}}
			"same_species": prey._campaign_identity.species_id = hunter._campaign_identity.species_id
			"own_species": prey._campaign_identity.species_id = state.campaign.data.player_species_id
			"scavenger": hunter.ecological_role = "scavenger"
			"unloaded": prey.position.y = 110.0
		hunter._sense()
		_expect(hunter._hunt_target == null, "Hunt ignored priority/protection: " + reason)
		prey._campaign_identity = identity
		prey.catalog_species = {}
		prey.position.y = 100.05
		state.current_phase = 0
		if had_ownership: body.domesticated_animals = ownership
		else: body.erase("domesticated_animals")
		progression.store_creature_encounter(original)
		hunter.get_node("SocialBehavior").attention_remaining = 0.0
		hunter.ecological_role = "predator"
		_feed_state(hunter, 30.0)
		hunter._sense()
	var wall: StaticBody3D = _box(Vector3(0.3, 4, 8), Vector3(1.5, 101.5, 0))
	await _frames(3)
	hunter._sense()
	_expect(hunter._hunt_target == null, "Hunt selected prey through a solid wall")
	wall.queue_free()
	await _frames(3)
	hunter._sense()
	# An unobstructed but motionless pursuit must time out and avoid that target.
	for i in range(20): hunter._sense()
	_expect(hunter._hunt_target == null and hunter._hunt_avoided.has(prey.get_instance_id()), "Stalled hunt did not release/avoid prey")
	hunter._hunt_avoided.clear()
	hunter._sense()
	hunter.set_physics_process(true)
	var before: Array = [hunter.position, hunter.satiety, prey.current_health, hunter._hunt_clock]
	paused = true
	await _frames(4)
	_expect(before == [hunter.position, hunter.satiety, prey.current_health, hunter._hunt_clock], "Paused hunt advanced")
	paused = false
	state.set_simulation_speed(0.0)
	await _frames(4)
	_expect(before == [hunter.position, hunter.satiety, prey.current_health, hunter._hunt_clock], "Zero-speed hunt advanced")
	state.set_simulation_speed(1.0)
	hunter.set_physics_process(false)
	hunter._sensed_neighbors.clear()
	for i in range(40): hunter._sensed_neighbors.append(prey)
	hunter._drop_hunt(false)
	hunter._hunt_examined = 0
	hunter._find_hunt_target()
	_expect(hunter._hunt_examined == 8, "Candidate search exceeded its fixed budget")
	prey.queue_free()
	hunter.set_physics_process(true)
	await _frames(20)
	_expect(not is_instance_valid(hunter._hunt_target), "Removed prey retained a live hunt target")
	await _clear()

func _meals_and_persistence() -> void:
	serial = 500
	var eater: CharacterBody3D = _creature("scavenger", Vector3(0, 100.05, 0), 411)
	var food: CharacterBody3D = _creature("grazer", Vector3(1.1, 100.05, 0), 771)
	eater.set_physics_process(false)
	food.set_physics_process(false)
	food.receive_creature_attack(999.0, eater)
	food.carcass_food_remaining = 25.0
	_expect(food.get_node("SocialBehavior").store_carcass(), "Initial carcass could not save")
	await _frames(3)
	var food_id: String = food.get_campaign_identity().object_id
	for phase in [0, 1]:
		state.current_phase = phase
		eater._sense()
		var before: Array = [eater.satiety, food.carcass_food_remaining]
		saves.save_path = "user://missing_hunt_directory/failed.json"
		_expect(not eater._consume_carcass(), "Failed save committed meal in phase " + str(phase))
		saves.save_path = SAVE
		_expect(before == [eater.satiety, food.carcass_food_remaining], "Failed save lost food/satiety in phase " + str(phase))
		_expect(progression.get_saved_creature_encounter(food_id).carcass_food == before[1], "Failed save changed persisted carcass")
		_expect(eater._needs.satiety == before[0], "Failed save left stale needs reference")
		eater._hunt_retry = 0.0
		eater._hunt_avoided.clear()
		eater._sense()
		_expect(eater._consume_carcass(), "Retry failed in phase " + str(phase))
		_expect(eater.satiety == before[0] + 10.0 and food.carcass_food_remaining == before[1] - 10.0, "Meal did not conserve food")
	state.current_phase = 0
	_expect(saves.save_now() and saves.load_now(), "Joint snapshot could not load")
	_expect(eater._hunt_target == null and eater.satiety == 50.0 and food.carcass_food_remaining == 5.0 and food.is_dead, "Load resurrected food/lost satiety/retained target")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/wildlife_hunting_test.gd", "--", "--hunt-restart"], output, true)
	_expect(code == 0 and "".join(output).contains('"passed":true'), "Fresh process failed: " + str(output))
	observations.restart_exit = code
	# A second eater cannot take the first eater's final five units again.
	var second: CharacterBody3D = _creature("scavenger", Vector3(0, 100.05, 0.2), 512)
	second.set_physics_process(false)
	await _frames(3)
	eater._sense()
	second._sense()
	_expect(eater._consume_carcass() and eater.satiety == 55.0, "Final partial meal was not exact")
	_expect(not second._consume_carcass() and second.satiety == 30.0, "Concurrent consumer duplicated exhausted food")
	_expect(progression.get_saved_creature_encounter(food_id).carcass_food == 0.0, "Exhausted carcass not persisted")
	await _clear()

func _restart() -> void:
	serial = 500
	_expect(saves.load_now(), "Fresh process load failed")
	var eater: CharacterBody3D = _animal("scavenger", Vector3(0, 100.05, 0), 411)
	var food: CharacterBody3D = _animal("grazer", Vector3(1.1, 100.05, 0), 771)
	eater.set_physics_process(false)
	food.set_physics_process(false)
	_expect(eater.satiety == 50.0 and eater._hunt_target == null, "Fresh process lost meat-eater needs")
	_expect(food.is_dead and food.carcass_food_remaining == 5.0, "Fresh process resurrected/duplicated carcass")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)
