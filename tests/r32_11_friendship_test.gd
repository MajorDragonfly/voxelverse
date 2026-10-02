extends "res://tests/creature_behavior_gameplay_test.gd"
## Real player/social actors and canonical SaveGameService, including a separate
## process. This supplements the existing gameplay and ambient-pair tests.
var checks: int = 0
var observations: Dictionary = {}

func _run() -> void:
	state = root.get_node("GameState")
	progression = root.get_node("ProgressionService")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://r32_11_friendship.json"
	state.start_world_with_seed(15838)
	await process_frame
	player = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.position = Vector3(0, 30, 0)
	player.fall_acceleration = 0.0
	player.set_process(false)
	behavior = player.get_node("BehaviorController")
	behavior.set_process(false)
	await process_frame
	if "--r32-restart" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process cannot load the encounter checkpoint")
		var social: Node = await _spawn(91)
		_expect(social.entry().trust == 35.0 and social.entry().relation == "wild", "Restart changed the partial relationship")
		_expect(social.response_remaining > 0.0, "Fresh process erased the animal response interval")
		_expect(not social.befriend(player).ok and social.entry().trust == 35.0, "Fresh process allowed an immediate extra trust step")
	else:
		await _response_restart()
		if "--baseline" in OS.get_cmdline_user_args():
			await _paused_help()
		else:
			await _encounter_matrix()
			await _guardrails()
			_deadline_contract()
	await _dispose_wildlife()
	player.queue_free()
	await process_frame
	print(JSON.stringify({"test": "r32_11_friendship", "passed": failures.is_empty(), "checks": checks, "observations": observations, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _response_restart() -> void:
	var social: Node = await _spawn(91)
	_expect(social.befriend(player).ok, "First calm observation failed")
	var response: float = social.response_remaining
	_expect(response > 0.0 and social.entry().trust == 35.0, "First action lacks a real response")
	_expect(saves.save_now(), "Cannot save during animal response")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/r32_11_friendship_test.gd", "--", "--r32-restart"], output, true)
	_expect(code == 0 and "".join(output).contains('"passed":true'), "Separate-process response check failed: " + str(output))
	_expect(saves.load_now(), "Cannot reload response checkpoint")
	var restored_response: float = social.response_remaining
	_expect(social.response_remaining > 0.0, "Same-process load erased the animal response interval")
	_expect(not social.befriend(player).ok and social.entry().trust == 35.0, "Reload allowed an immediate extra trust step")
	observations["restart"] = {"before_response": response, "after_response": restored_response, "child_exit": code}
	# Unloading uses a new actual actor with the same campaign object ID.
	var identity: Dictionary = wildlife.get_campaign_identity()
	social = await _spawn(91)
	_expect(wildlife.get_campaign_identity() == identity and social.response_remaining > 0.0, "Streamed respawn discarded response or changed identity")
	_expect(not social.befriend(player).ok and social.entry().trust == 35.0, "Streamed respawn bypassed response")

func _encounter_matrix() -> void:
	var results: Array = []
	for seed in [96, 97, 98]:
		var social: Node = await _spawn(seed)
		var points: int = _earned("social")
		var steps: Array = []
		for step in range(3):
			var result: Dictionary = social.befriend(player, 0.1, social.social_status().playful)
			_expect(result.ok and result.step == step + 1, "Three-action path failed for temperament " + str(seed % 3))
			steps.append(result.trust)
			for repeat in range(16):
				_expect(not social.befriend(player).ok and social.entry().trust == result.trust, "Rapid repetition farmed trust")
			if step < 2: social._process(social.response_remaining + 0.01)
		_expect(social.entry().relation == "ally" and _earned("social") == points + 3, "Completion did not create exactly one relationship/reward")
		var id: Dictionary = wildlife.get_campaign_identity()
		_expect(saves.load_now(), "Completed encounter cannot reload")
		social = await _spawn(seed)
		_expect(wildlife.get_campaign_identity() == id and not social.befriend(player).ok and _earned("social") == points + 3, "Completed identity paid or bound twice after reload")
		results.append({"temperament": seed % 3, "steps": steps, "earned": _earned("social") - points})
	observations["success_matrix"] = results
	# Cautious refusal: saved quiet time, no trust or reward, then a calm retry.
	var social: Node = await _spawn(103)
	var points: int = _earned("social")
	_expect(social.befriend(player).ok, "Cannot prepare cautious encounter")
	social._process(social.response_remaining + 0.01)
	_expect(not social.befriend(player, 0.1, true).ok and wildlife._threat_timer > 0.0 and social.entry().trust == 35.0, "Cautious animal accepted rushed play")
	_expect(saves.save_now() and saves.load_now(), "Refusal cannot save/load")
	_expect(social.response_remaining > 0.0 and not social.befriend(player).ok and social.entry().trust == 35.0, "Load bypassed refusal pause")
	social._process(social.response_remaining + 0.01)
	wildlife._threat_timer = 0.0
	wildlife._threat = null
	_expect(social.befriend(player).ok and social.entry().trust == 70.0 and _earned("social") == points, "Calm retry failed or paid prematurely")
	# Interruption/distance and a second actual nearby animal retain independent IDs.
	var other: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	other.configure(2771441, 104, Vector2i.ZERO, "forager")
	root.add_child(other)
	other.position = player.position + Vector3(1.0, 0, -2.2)
	other.set_physics_process(false)
	other.get_node("SocialBehavior").set_process(false)
	await physics_frame
	_expect(other.get_node("SocialBehavior").entry().trust == 0.0, "Neighbor inherited selected animal's trust")
	wildlife.position.z -= 20.0
	_expect(not social.befriend(player).ok and social.entry().trust == 70.0, "Out-of-range interruption advanced/reset trust")
	_expect(other.get_node("SocialBehavior").befriend(player).ok and other.get_node("SocialBehavior").entry().trust == 35.0 and social.entry().trust == 70.0, "Target switch changed more than one encounter")
	other.queue_free()
	await process_frame
	# Hostile predator and real externally frightened animal reject social input.
	social = await _spawn(107, "predator")
	_expect(not social.befriend(player).ok and social.entry().trust == 0.0, "Hostile animal gained trust")
	social = await _spawn(108)
	var attacker := Node3D.new()
	root.add_child(attacker)
	attacker.position = wildlife.position + Vector3.RIGHT
	wildlife.receive_creature_attack(1.0, attacker)
	_expect(wildlife._threat_timer > 0.0 and not social.befriend(player).ok and social.entry().trust == 0.0, "Real external threat did not interrupt social input")
	attacker.queue_free()
	await process_frame

func _guardrails() -> void:
	var social: Node = await _spawn(109)
	_expect(social.befriend(player).ok, "Cannot prepare pause case")
	var response: float = social.response_remaining
	var clock: float = state.campaign.data.elapsed_seconds
	paused = true
	social._process(10.0)
	_expect(not social.befriend(player).ok and social.response_remaining == response and state.campaign.data.elapsed_seconds == clock, "Scene pause advanced encounter")
	paused = false
	state.set_simulation_speed(0.0)
	social._process(10.0)
	_expect(not social.befriend(player).ok and social.response_remaining == response, "Zero-speed pause advanced encounter")
	state.set_simulation_speed(1.0)
	# Deadline tracks campaign simulation, without per-frame encounter writes.
	state.campaign.data.elapsed_seconds = float(social.entry().social_response_until_ms) / 1000.0 + 0.01
	_expect(saves.save_now() and saves.load_now() and social.response_remaining == 0.0, "Expired canonical-clock response did not remain ready after reload")
	_expect(social.befriend(player).ok, "Expired response blocks a deliberate next action")
	await _paused_help()
	# The existing atomic completion must roll back the new deadline as well.
	social = await _spawn(112)
	for step in range(2):
		_expect(social.befriend(player).ok, "Cannot prepare save-failure case")
		social._process(social.response_remaining + 0.01)
	var before: Dictionary = social.entry()
	var points: int = _earned("social")
	var correct_path: String = saves.save_path
	saves.save_path = "user://r32_11_missing_directory/save.json"
	_expect(not social.befriend(player).ok and social.entry() == before and _earned("social") == points, "Failed completion retained deadline/trust/reward")
	saves.save_path = correct_path
	_expect(social.befriend(player).completed and _earned("social") == points + 3, "Completion cannot retry after actual save failure")

func _paused_help() -> void:
	var social: Node = await _spawn(110)
	state.set_simulation_speed(0.0)
	var hunger: float = player.current_hunger
	var health: float = wildlife.current_health
	_expect(not social.help(player).ok and player.current_hunger == hunger and wildlife.current_health == health, "Sharing food during zero-speed pause changed hunger/health")
	observations["paused_help"] = {"hunger_before": hunger, "hunger_after": player.current_hunger, "health_before": health, "health_after": wildlife.current_health}
	state.set_simulation_speed(1.0)

func _deadline_contract() -> void:
	var entry: Dictionary = wildlife.get_node("SocialBehavior").entry()
	entry.erase("social_response_until_ms")
	_expect(Encounters.validate_entry(entry).is_empty(), "Legacy encounter no longer validates")
	for value in [-1.0, NAN, INF, "future", 1.0e16, 1.5]:
		entry.social_response_until_ms = value
		_expect(not Encounters.validate_entry(entry).is_empty(), "Invalid response deadline accepted: " + str(value))
	entry.social_response_until_ms = 1901
	var ledger := Encounters.new()
	_expect(ledger.put(entry), "Valid integer response deadline cannot be stored")
	var roundtrip := Encounters.new()
	_expect(roundtrip.import_state(Atomic.parse_dictionary(Atomic.stringify(ledger.export_state()))), "Deadline ledger cannot roundtrip through the actual JSON reader")
	_expect(roundtrip.saved(entry.object_id) == entry, "Response deadline changed exact encounter identity/data on JSON roundtrip")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)
