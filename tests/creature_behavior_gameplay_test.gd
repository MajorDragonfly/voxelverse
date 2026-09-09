extends SceneTree

const Atomic = preload("res://core/persistence/atomic_json.gd")
const Encounters = preload("res://core/progression/creature_encounters.gd")
const TEST_SAVE: String = "user://creature_behavior_gameplay.json"

var failures: Array[String] = []
var state: Node
var progression: Node
var saves: Node
var player: Node3D
var wildlife: Node3D
var behavior: Node
var reward_count: int = 0
var first_identity: Dictionary
var first_duration: float


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	state = root.get_node("GameState")
	progression = root.get_node("ProgressionService")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = TEST_SAVE
	if "--restart-check" in OS.get_cmdline_user_args():
		_verify_restart()
		_finish()
		return
	state.start_world_with_seed(12345)
	await process_frame
	player = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.position = Vector3(0, 30, 0)
	player.fall_acceleration = 0.0
	player.set_process(false)
	behavior = player.get_node("BehaviorController")
	behavior.set_process(false)
	await process_frame
	progression.behavior_rewarded.connect(func(_receipt: Dictionary) -> void: reward_count += 1)
	await _social_loop()
	await _help_loop()
	await _combat_loop()
	await _reload_and_guardrails()
	await _actual_streamer_identity()
	_phase_preview_and_migration()
	await _dispose_wildlife()
	player.queue_free()
	await process_frame
	_finish()


func _spawn(seed: int, role: String = "forager") -> Node:
	await _dispose_wildlife()
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	wildlife.configure(2771337 + seed, seed, Vector2i.ZERO, role)
	root.add_child(wildlife)
	wildlife.position = player.position + Vector3(0, 0, -2.2)
	wildlife.set_physics_process(false)
	wildlife.get_node("SocialBehavior").set_process(false)
	await physics_frame
	await process_frame
	return wildlife.get_node("SocialBehavior")


func _dispose_wildlife() -> void:
	if is_instance_valid(wildlife):
		wildlife.queue_free()
		await process_frame
		await physics_frame
	wildlife = null


func _befriend(social: Node) -> float:
	var elapsed: float = 0.0
	for tick in range(100):
		var result: Dictionary = social.befriend(player, 0.1)
		elapsed += 0.1
		if not result.get("ok", false):
			_expect(false, "Befriending failed: " + str(result))
			return elapsed
		if result.get("completed", false):
			return elapsed
	_expect(false, "Befriending never completed.")
	return elapsed


func _social_loop() -> void:
	_expect(not progression.purchase_behavior_node("creature.social.approach")["ok"], "Empty campaign purchased a node.")
	var social: Node = await _spawn(11)
	first_identity = wildlife.get_campaign_identity()
	first_duration = _befriend(social)
	_expect(_earned("social") == 3 and reward_count == 1, "Real befriending did not earn exactly three points.")
	_expect(progression.get_discovered_species_count() == 0, "Social contact bypassed the required scan.")
	_expect(social.entry()["relation"] == "ally", "Befriending did not persist an ally.")
	var disk: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(TEST_SAVE))
	_expect(disk["progression"]["creature_encounters"]["entries"][first_identity["object_id"]]["relation"] == "ally", "Reward committed without the relationship.")
	_expect(not social.befriend(player, 0.1)["ok"] and _earned("social") == 3, "Ally paid again.")
	_expect(progression.purchase_behavior_node("creature.social.approach")["ok"], "Could not spend genuinely earned points.")
	social = await _spawn(12)
	var improved: float = _befriend(social)
	_expect(first_duration >= 8.0 - 0.001 and improved <= 7.0 + 0.001, "Offenheit did not reduce real befriending time.")
	_expect(_earned("social") == 6, "Second individual did not earn its own points.")
	print("Measured befriending: %.1f s -> %.1f s with Offenheit" % [first_duration, improved])


func _help_loop() -> void:
	var social: Node = await _spawn(10)
	_expect(is_equal_approx(wildlife.get_health_ratio(), 0.55), "Deterministic environmental injury missing.")
	var before: Dictionary = social.entry()
	var hunger: float = player.current_hunger
	saves.save_path = "user://unavailable_behavior_directory/save.json"
	var result: Dictionary = social.help(player)
	_expect(not result["ok"] and social.entry() == before and player.current_hunger == hunger, "Failed help lost food or kept healing.")
	saves.save_path = TEST_SAVE
	result = social.help(player)
	_expect(result["ok"] and not result["completed"] and _earned("social") == 6, "Partial care paid prematurely.")
	_expect(is_equal_approx(wildlife.get_health_ratio(), 0.85) and player.current_hunger == hunger - 12.0, "Real care did not exchange food for health.")
	_expect(not social.help(player)["ok"], "Help cooldown was ignored.")
	social.help_cooldown = 0.0
	result = social.help(player)
	_expect(result["completed"] and _earned("social") == 8, "Completed independent need did not earn two points.")
	social.help_cooldown = 0.0
	_expect(not social.help(player)["ok"], "Healthy animal consumed supplies.")
	_expect(progression.purchase_behavior_node("creature.social.support")["ok"], "Could not buy Zusammenhalt.")
	social = await _spawn(15)
	_befriend(social)
	var points: int = _earned("social")
	result = social.help(player)
	_expect(result["ok"] and is_equal_approx(wildlife.get_health_ratio(), 0.895), "Zusammenhalt did not improve real allied care by 15 percent.")
	social.help_cooldown = 0.0
	social.help(player)
	_expect(_earned("social") == points, "One individual rewarded befriending and helping.")


func _defeat() -> void:
	for strike in range(40):
		if wildlife.is_dead:
			return
		player._bite_cooldown_timer = 0.0
		behavior.advance_recovery(1.6)
		_expect(player.perform_bite_on_target(wildlife), "Real bite failed.")
	_expect(false, "Conflict did not finish.")


func _combat_loop() -> void:
	var social: Node = await _spawn(21, "predator")
	_expect(not social.befriend(player, 0.1)["ok"], "Hostile predator became instantly social.")
	behavior.reset_stamina()
	var health: float = wildlife.current_health
	var base_damage: float = player.get_bite_damage()
	player._bite_cooldown_timer = 0.0
	_expect(player.perform_bite_on_target(wildlife), "Bite did not reach hostile target.")
	_expect(is_equal_approx(health - wildlife.current_health, base_damage) and behavior.stamina == 88.0, "Bite damage or stamina cost incorrect.")
	_expect(not player.perform_bite_on_target(wildlife), "Bite cooldown bypassed.")
	_defeat()
	_expect(_earned("aggression") == 3, "Won hostile encounter did not earn three aggression points.")
	_expect(progression.purchase_behavior_node("creature.aggression.hunter")["ok"], "Earned aggression could not buy Jagdinstinkt.")
	_expect(is_equal_approx(player.get_bite_damage(), base_damage * 1.1), "Jagdinstinkt did not change actual bite damage.")
	for seed in [22, 23]:
		await _spawn(seed, "predator")
		_defeat()
	_expect(progression.purchase_behavior_node("creature.aggression.endurance")["ok"], "Could not purchase Ausdauer.")
	behavior.stamina = 0.0
	behavior.recovery_delay = 0.0
	behavior.advance_recovery(1.0)
	_expect(is_equal_approx(behavior.stamina, 17.25), "Ausdauer did not improve actual recovery.")
	social = await _spawn(24)
	_befriend(social)
	var earned_before: int = _earned("aggression")
	_defeat()
	_expect(social.entry()["conflict_relation"] == "ally" and _earned("aggression") == earned_before, "Betrayal turned into a rewarded hunt.")
	social = await _spawn(25)
	player._bite_cooldown_timer = 0.0
	behavior.reset_stamina()
	player.perform_bite_on_target(wildlife)
	_expect(not social.help(player)["ok"] and not social.befriend(player, 0.1)["ok"], "Player-created injury could be farmed.")
	# A genuine prey encounter is rewardable only with a meat-capable creature.
	await _spawn(26)
	player.diet_meat = 1.0
	_defeat()
	_expect(_earned("aggression") == earned_before + 3, "Completed hunt did not earn points.")


func _reload_and_guardrails() -> void:
	var social: Node = await _spawn(31)
	_befriend(social)
	var id: Dictionary = wildlife.get_campaign_identity()
	var earned_before: int = _earned("social")
	_expect(saves.load_now(), "Joint encounter save could not reload.")
	social = await _spawn(31)
	_expect(wildlife.get_campaign_identity() == id and social.entry()["relation"] == "ally", "Streaming respawn lost stable relationship.")
	_expect(not social.befriend(player, 0.1)["ok"] and _earned("social") == earned_before, "Reload reopened a paid target.")
	social = await _spawn(32)
	for tick in range(69):
		social.befriend(player, 0.1)
	var before: Dictionary = social.entry()
	var notifications_before: int = reward_count
	saves.save_path = "user://unavailable_behavior_directory/save.json"
	_expect(not social.befriend(player, 0.1)["ok"], "Unwritable completed friendship reported success.")
	_expect(social.entry() == before and _earned("social") == earned_before and reward_count == notifications_before, "Failed friendship kept reward or relationship.")
	saves.save_path = TEST_SAVE
	_expect(social.befriend(player, 0.1).get("completed", false), "Friendship could not retry after save failure.")
	social = await _spawn(33)
	behavior.reset_stamina()
	player._bite_cooldown_timer = 0.0
	var health: float = wildlife.current_health
	saves.save_path = "user://unavailable_behavior_directory/save.json"
	_expect(not player.perform_bite_on_target(wildlife) and wildlife.current_health == health and behavior.stamina == 100.0, "Failed attack lost stamina or kept damage.")
	saves.save_path = TEST_SAVE
	paused = true
	_expect(not social.befriend(player, 0.1)["ok"] and not player.perform_bite_on_target(wildlife), "Paused world allowed behavior actions.")
	paused = false
	wildlife.position.z = -40.0
	_expect(not social.befriend(player, 0.1)["ok"] and not player.perform_bite_on_target(wildlife), "Distant creature could be interacted with.")
	wildlife.position = player.position + Vector3(0, 0, -1.3)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.position = player.position + Vector3(0, 0.7, -0.6)
	await physics_frame
	await process_frame
	_expect(not social.befriend(player, 0.1)["ok"] and not player.perform_bite_on_target(wildlife), "Close-target fallback allowed actions through a wall.")
	wall.queue_free()
	await process_frame
	_expect(saves.save_now(), "Could not create process restart checkpoint.")
	Atomic.write("user://creature_behavior_expected.json", {"progression": progression.export_state()}, false)
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://project.godot")):
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/creature_behavior_gameplay_test.gd", "--", "--restart-check"], output, true)
		_expect(code == 0 and str(output).contains("Creature behavior restart passed"), "Separate-process persistence failed: " + str(output))


func _verify_restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://creature_behavior_expected.json"))
	_expect(saves.load_now(), "Fresh process could not load behavior.")
	_expect(JSON.parse_string(JSON.stringify(progression.export_state())) == expected.get("progression"), "Fresh process changed relationships, rewards or purchases.")
	if failures.is_empty():
		print("Creature behavior restart passed")


func _actual_streamer_identity() -> void:
	await _dispose_wildlife()
	var old_position: Vector3 = player.position
	var generator := root.get_node("WorldGenerator")
	player.position = preload("res://world/generation/adventure_spawn_selector.gd").find_spawn(generator)
	var center: Vector3 = player.position
	var streamer: Node3D = load("res://world/fauna/fauna_streamer_v7.gd").new()
	root.add_child(streamer)
	streamer.set_process(false)
	await process_frame
	streamer._bind_runtime_services()
	for attempt in range(150):
		streamer._spawn_one_creature()
		if not streamer._active_fauna.is_empty():
			break
	_expect(not streamer._active_fauna.is_empty(), "Normal fauna streamer could not populate a valid habitat.")
	if streamer._active_fauna.is_empty():
		streamer.queue_free()
		await process_frame
		return
	var target: Node3D = streamer._active_fauna[0]
	target.set_physics_process(false)
	var identity: Dictionary = target.get_campaign_identity()
	var social: Node = target.get_node("SocialBehavior")
	player.position = target.position + Vector3(0, 0, 2.0)
	await physics_frame
	await process_frame
	# Persist a real action for whichever role the actual biome chooses.
	if target.ecological_role != "predator":
		_befriend(social)
	else:
		player._bite_cooldown_timer = 0.0
		behavior.reset_stamina()
		_expect(player.perform_bite_on_target(target), "Streamed predator could not receive a real attack.")
	var expected: Dictionary = social.entry()
	_expect(expected.has("habitat"), "Normal streamer did not persist its habitat descriptor.")
	var earned_before: Dictionary = progression.get_behavior_wallet(0)["earned"]
	streamer.queue_free()
	await process_frame
	await physics_frame
	player.position = center
	_expect(saves.load_now(), "Could not reload streamed encounter.")
	player.position = center
	streamer = load("res://world/fauna/fauna_streamer_v7.gd").new()
	root.add_child(streamer)
	streamer.set_process(false)
	await process_frame
	streamer._bind_runtime_services()
	streamer._spawn_serial = 997
	var restored: Node3D
	for attempt in range(250):
		streamer._spawn_one_creature()
		for creature in streamer._active_fauna:
			creature.set_physics_process(false)
			if creature.get_campaign_identity()["object_id"] == identity["object_id"]:
				restored = creature
		if restored != null:
			break
	_expect(restored != null, "Different spawn order never restored the touched habitat.")
	if restored != null:
		_expect(restored.get_campaign_identity() == identity and restored.get_node("SocialBehavior").entry() == expected, "Normal streaming changed species, identity, health or relationship.")
		_expect(progression.get_behavior_wallet(0)["earned"] == earned_before, "Normal streaming awarded points on respawn.")
	var seen: Dictionary = {}
	for creature in streamer._active_fauna:
		var object_id: String = creature.get_campaign_identity()["object_id"]
		_expect(not seen.has(object_id), "Normal streamer duplicated a living habitat identity.")
		seen[object_id] = true
	streamer.queue_free()
	await process_frame
	player.position = old_position
	await _spawn(34)


func _phase_preview_and_migration() -> void:
	_expect(not saves.request_phase_transition(1), "Skilltree prematurely unlocked tribe gameplay.")
	_expect(progression.purchase_behavior_node("creature.social.legacy")["ok"], "Could not buy social legacy with earned points.")
	_expect(progression.purchase_behavior_node("creature.aggression.legacy")["ok"], "Could not buy aggression legacy with earned points.")
	for phase in range(1, 6):
		var preview: Dictionary = progression.get_phase_progression_preview(phase)
		_expect(bool(preview["implemented"]) == (phase == 1) and preview["wallet"]["available"] == {"social": 0, "aggression": 0}, "Preview must expose only the tribal village and preserve separate empty future wallets.")
		_expect(is_equal_approx(preview["legacy"]["group_cooperation"]["value"], 1.1) and is_equal_approx(preview["legacy"]["group_defense"]["value"], 1.1), "Legacy preview lost actual purchased effects.")
		state.current_phase = phase
		_expect(not wildlife.get_node("SocialBehavior").befriend(player, 0.1)["ok"], "Creature action leaked into a later phase.")
	state.current_phase = 0
	saves.save_now()
	var valid: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(TEST_SAVE))
	var future: Dictionary = valid.duplicate(true)
	future["progression"]["creature_encounters"]["schema"] = 99
	Atomic.write(TEST_SAVE, future, false)
	_expect(not saves.load_now() and not saves.save_now(), "Future encounter contract could be overwritten.")
	Atomic.write(TEST_SAVE, valid, false)
	_expect(saves.load_now(), "Compatible contract did not unblock saving.")
	var old: Dictionary = valid.duplicate(true)
	old["schema"] = 4
	old["progression"]["schema"] = 3
	old["progression"].erase("creature_encounters")
	Atomic.write(TEST_SAVE, old, false)
	var bytes: String = FileAccess.get_file_as_string(TEST_SAVE)
	_expect(saves.load_now(), "Existing M2/UI schema 4 did not migrate.")
	_expect(JSON.parse_string(JSON.stringify(progression.export_state()["behavior"])) == old["progression"]["behavior"], "Migration changed earned points or purchased nodes.")
	_expect(progression.export_state()["creature_encounters"]["entries"].is_empty(), "Migration invented historical relationships.")
	_expect(FileAccess.get_file_as_string(TEST_SAVE) == bytes and FileAccess.file_exists(TEST_SAVE + ".schema4.backup.json"), "Migration did not preserve original save bytes.")
	_expect(saves.save_now(), "Migrated campaign failed to save.")
	var bad: Dictionary = Encounters.new().export_state()
	bad["entries"]["broken"] = {"health_ratio": NAN}
	_expect(not Encounters.validate_state(bad).is_empty(), "Malformed encounter was accepted.")
	state.start_world_with_seed(12345)
	_expect(progression.export_state()["creature_encounters"]["entries"].is_empty() and _earned("social") == 0, "New game retained relationships or rewards.")


func _earned(track: String) -> int:
	return progression.get_behavior_wallet(0)["earned"][track]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Creature behavior gameplay, rewards, effects, persistence and phase preview passed.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0)
	else:
		for failure in failures:
			push_error(failure)
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
