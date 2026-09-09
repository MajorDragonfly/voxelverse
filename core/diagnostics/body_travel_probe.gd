extends "res://core/diagnostics/spherical_campaign_probe.gd"
const Home = preload("res://world/home_group/home_group_state.gd")

func _run() -> void:
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--body-travel-restart" in OS.get_cmdline_user_args():
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://body_travel_expected.json"))
		await _open(expected.path, true)
		if _expect_world():
			_expect(state.active_body_id == expected.body_id and state.campaign.data.bodies.size() == 2, "Restart lost active body or allocated another one.")
			_expect(Migration.fingerprint(state.get_current_body().tribe) == Migration.fingerprint(expected.village), "Restart replayed far production/cargo.")
			_expect(state.campaign.data.elapsed_seconds == expected.clock, "Loading generated offline work.")
		await _finish()
		return
	var path: String = saves.create_slot("Reise und Fernarbeit", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): await _finish(); return
	var home: Node = tree.current_scene.get_node("Nest/HomeGroup")
	_expect(home.establish_home().ok, "Could not establish original home.")
	await _until(func() -> bool: return home.actors.size() == 2, 12000)
	var tribe: Node = tree.current_scene.get_node("Nest/Tribe")
	_expect(tribe.prepare_confirmation().is_empty() and tribe.panel.open_confirmation(), "Could not prepare real village handoff.")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 18000)
	if not tribe.is_active(): _expect(false, "Village did not activate."); await _finish(); return
	var a: String = state.active_body_id
	var member_id: String = tribe.village().members[1].id
	tribe.select_member(member_id)
	_expect(tribe.issue_order("wood"), "Companion could not accept real work.")
	var data: Dictionary = tribe.village()
	data.members[0].hunger = 57.0
	data.members[0].hydration = 63.0
	tree.current_scene.player.current_health = tree.current_scene.player.maximum_health * 0.73
	await tree.physics_frame
	await tree.physics_frame
	var needs: Dictionary = tree.current_scene.player.export_runtime_state()
	_expect(absf(float(needs.hunger_ratio) * 100.0 - float(data.members[0].hunger)) < 0.01 and absf(float(needs.thirst_ratio) * 100.0 - float(data.members[0].hydration)) < 0.01, "Traveler export diverged from the resident's actual food/water needs.")
	flow.toggle_pause()
	# Preserve a conserved outstanding cargo while the other resident works.
	data.deposits.stone.remaining -= 1
	data.members[2].cargo = "stone"
	data.members[2].stage = "return"
	data.members[2].order = "wait"
	data.members[2].blocked = true
	_expect(saves.save_now(), "Departure fixture violated conservation.")
	var old_scene_id: int = tree.current_scene.get_instance_id()
	var departed: bool = await flow.travel_to_planet(23757, 0, 15838)
	_expect(departed, "Departure failed: " + saves.last_error)
	if not departed: await _finish(); return
	await _until(func() -> bool: return not flow.loading, 150000)
	if not _expect_world(): await _finish(); return
	var b: String = state.active_body_id
	_expect(a != b and state.world_seed == 15838 and state.campaign.data.bodies.size() == 2, "Same-seed target reused source identity.")
	var arrived_needs: Dictionary = tree.current_scene.player.export_runtime_state()
	_expect(absf(float(arrived_needs.hunger_ratio) - float(needs.hunger_ratio)) < 0.005 and absf(float(arrived_needs.thirst_ratio) - float(needs.thirst_ratio)) < 0.005 and absf(float(arrived_needs.health_ratio) - 0.73) < 0.005, "Departure replaced the traveler's needs/health with a fresh body's defaults: " + str({"before": [needs.hunger_ratio, needs.thirst_ratio, needs.health_ratio], "after": [arrived_needs.hunger_ratio, arrived_needs.thirst_ratio, arrived_needs.health_ratio]}))
	_expect(not is_instance_id_valid(old_scene_id), "Source world host survived arrival.")
	_expect(state.campaign.body_record(a).village_simulation.owner == "far", "Departure left two near simulation owners.")
	await _until(func() -> bool: return state.campaign.body_record(a).tribe.stock.wood > 0, 22000)
	var remote: Dictionary = state.campaign.body_record(a)
	_expect(remote.tribe.stock.wood > 0, "Absent companion did not complete physical-route work/return.")
	_expect(remote.tribe.stock.stone == 0 and remote.tribe.members[2].cargo == "stone", "Remote waiting cargo was automatically credited.")
	flow.toggle_pause()
	# Distinct live needs on B must replace the old traveler values retained on A.
	tree.current_scene.player.current_hunger = tree.current_scene.player.maximum_hunger * 0.46
	tree.current_scene.player.current_thirst = tree.current_scene.player.maximum_thirst * 0.41
	var paused: String = Migration.fingerprint(state.export_state())
	for index in range(15): await tree.process_frame
	_expect(Migration.fingerprint(state.export_state()) == paused, "Pause advanced remote work.")
	_expect(await flow.travel_to_planet(15838, 0, 15838, a), "Return request failed.")
	await _until(func() -> bool: return not flow.loading, 150000)
	if not _expect_world(): await _finish(); return
	tribe = tree.current_scene.get_node("Nest/Tribe")
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 18000)
	_expect(state.active_body_id == a and state.get_current_body().village_simulation.owner == "near", "Return did not reclaim exclusive near ownership.")
	_expect(tribe.is_active() and tribe.actors.size() == 3 and tribe.member_record(member_id).order == "wood", "Return duplicated residents or lost their job.")
	_expect(absf(float(tribe.village().members[0].hunger) - 46.0) < 0.5 and absf(float(tribe.village().members[0].hydration) - 41.0) < 0.5, "Return restored stale local food/water needs instead of the traveler's current state.")
	tribe.select_all()
	tribe.issue_order("wait")
	flow.toggle_pause()
	var before: Dictionary = state.export_state()
	var original_path: String = saves.save_path
	var before_autosave: bool = saves.autosave_enabled
	saves.save_path = "user://missing-travel-parent/blocked.json"
	_expect(not await flow.travel_to_planet(23757, 0, 15838, b), "Failed departure write reported success.")
	_expect(Migration.fingerprint(state.export_state()) == Migration.fingerprint(before) and state.active_body_id == a, "Failed departure changed ownership or live state.")
	_expect(saves.autosave_enabled == before_autosave, "Failed departure disabled later automatic checkpoints.")
	saves.save_path = original_path
	var population: Node = tree.get_first_node_in_group(&"campaign_surface_population")
	var food_key: String = ""
	var regrow_at: float = state.campaign.data.elapsed_seconds + 1000.0
	_expect(population != null and not population.plants.is_empty(), "Rollback fixture has no regional plant.")
	if population != null and not population.plants.is_empty():
		food_key = population.plants.values()[0].persistent_food_key
		# A real regional record has changed since its last committed root.
		var food: Dictionary = population.needs(food_key, "food", 4.0)
		food.remaining = 0.0
		food.regrow_at = regrow_at
	_expect(not await flow.travel_to_planet(23757, 0, 15838, "missing-body"), "Unknown destination was invented.")
	await _until(func() -> bool: return not flow.loading, 150000)
	if not _expect_world(): await _finish(); return
	_expect(state.active_body_id == a and state.campaign.data.bodies.size() == 2, "Failed destination did not restore source.")
	if not food_key.is_empty():
		var restored_food: Dictionary = preload("res://world/resources/plants/foraging_state.gd").plant(state, a, food_key, 4.0)
		_expect(restored_food.get("remaining") == 0.0 and restored_food.get("regrow_at") == regrow_at, "Failed target restored an older regional root and lost the last harvest.")
	flow.toggle_pause()
	_expect(saves.save_now(), "Return checkpoint failed: " + saves.last_error)
	var expected: Dictionary = {"path": path, "body_id": a, "clock": state.campaign.data.elapsed_seconds, "village": state.get_current_body().tribe}
	Atomic.write("user://body_travel_expected.json", expected, false)
	flow.return_to_title()
	await tree.scene_changed
	var output: Array = []
	var args := PackedStringArray(["--headless"])
	if OS.has_feature("editor"): args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--body-travel-smoke", "--body-travel-restart"])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	_expect(code == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Fresh-process travel recovery failed: " + str(output))
	if failures.is_empty(): print("BODY_TRAVEL_PASSED: real sphere A-B-A, same seeds, host teardown, far companion work, conserved cargo, failed writes/target rollback, fresh-process load.")
	await _finish()

func _until(predicate: Callable, milliseconds: int) -> void:
	var started: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - started < milliseconds: await tree.process_frame
