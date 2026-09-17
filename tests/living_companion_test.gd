extends "res://tests/home_group_test.gd"

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://living_companion.json"
	if "--living-restart" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process failed to load companion health")
		var group: Dictionary = state.get_current_body_record().home_group
		_expect(group.members[0].health == 20.0 and group.members[0].order == "wait", "Restart lost health/order")
		_finish()
		return
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	await _frames(30)
	_expect(home.establish_home().ok, "Cannot establish actual home group")
	if home.actors.size() != 2:
		_expect(false, "Missing residents")
		await _cleanup()
		_finish()
		return
	var a: Node = home.actors.values()[0]
	var b: Node = home.actors.values()[1]
	_expect(a.personality != b.personality and a._preview.scale != b._preview.scale, "Residents still have identical roles and presentation")
	var original_ids: Array = home.actors.keys()
	_expect(home.issue_order("follow").ok, "Follow order failed")
	await _frames(3)
	a._play_cooldown = 0.0
	b._play_cooldown = 0.0
	var stages: Dictionary = {}
	for i in range(570):
		await _frames(1)
		if a._play_session != null: stages[a._play_session.stage] = true
	_expect(stages.has("greet") and stages.has("play") and stages.has("rest"), "Companions did not complete mutual greeting/play: " + str(stages) + " reason=" + a._play_last_reason + " position=" + str(a.global_position) + " other=" + str(b.global_position))
	_expect(a.has_node("_VoxelverseAudio") and b.has_node("_VoxelverseAudio"), "Companions were not bound to the existing voice budget")
	_expect(home.issue_order("wait").ok, "Wait order failed")
	await _frames(4)
	var stopped: Vector3 = a.global_position
	await _frames(35)
	_expect(a._play_session == null and a.global_position.distance_to(stopped) < 0.05, "Wait did not cancel social movement")
	_expect(home.issue_order("follow").ok, "Cannot resume following")
	await _frames(3)
	var enemy: CharacterBody3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	enemy.configure(919, 333, Vector2i.ZERO, "predator")
	enemy.position = a.global_position + Vector3(0, 0, -1.4)
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy._intent = "chase"
	enemy._target = player
	enemy._warning = 0.0
	var health: float = enemy.current_health
	await _frames(65)
	_expect(enemy.current_health < health, "Follower did not actually damage an attacker threatening the player")
	_expect(enemy._threat in [a, b], "Wild creature cannot retaliate against the defending companion")
	enemy.queue_free()
	await _frames(4)
	# The curious companion points at an actual finite food source. It cannot
	# consume it remotely or manufacture food for the player.
	var food: Node3D = load("res://world/resources/plants/berry_bush.tscn").instantiate()
	food.snap_to_terrain = false
	food.position = Vector3(0, 100.02, -3)
	scene.add_child(food)
	player.current_hunger = 40.0
	await _frames(35)
	_expect(b.status_code == "scouting" and is_instance_valid(b._food_source), "Curious companion ignored nearby real food")
	_expect(player.current_hunger == 40.0, "Scouting manufactured food")
	player.current_hunger = 100.0
	food.queue_free()
	await _frames(3)
	a.receive_damage(80.0)
	_expect(a.current_health == 20.0 and home.member_record(a.member_id).health == 20.0, "Companion damage did not reach its canonical record")
	_expect(home.issue_order("wait").ok, "Cannot stop injured companion")
	await _frames(2)
	var before: float = a.current_health
	paused = true
	await _frames(15)
	_expect(a.current_health == before, "Paused companion recovered")
	paused = false
	state.set_simulation_speed(0.0)
	var stopped_clock: float = a._clock
	await _frames(10)
	_expect(a.current_health == before and a._clock == stopped_clock, "Zero simulation speed advanced a companion")
	state.set_simulation_speed(1.0)
	_expect(saves.save_now(), "Health snapshot failed")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--living-restart"], output, true)
	_expect(code == 0 and not str(output).contains("ERROR"), "Fresh process rejected health: " + str(output).right(1000))
	_expect(saves.load_now(), "Health reload failed")
	await _frames(30)
	_expect(home.actors.keys() == original_ids and home.actors.size() == 2, "Reload duplicated or changed companion identities")
	a = home.actors.values()[0]
	_expect(a.current_health < 25.0 and a._recovering, "Reload reset the wounded companion")
	a.receive_damage(100.0)
	_expect(a.current_health == 0.0 and not a.is_combat_target(), "Downed companion remained an endless combat target")
	var member: Dictionary = home.member_record(a.member_id)
	member.health = NAN
	_expect(not Model.validate(home.group_state(), home.group_state().body_id, home.group_state().species_id).is_empty(), "Malformed health accepted")
	member.health = 20.0
	await _cleanup()
	_finish()
