extends "tribal_age_test.gd"
const Tribal = preload("res://core/progression/tribal_progression.gd")
const Epoch = preload("res://core/progression/civilization_contract.gd")
var progression: Node

func _run() -> void:
	progression = root.get_node("ProgressionService")
	if "--verify-tribal" in OS.get_cmdline_user_args():
		saves = root.get_node("SaveGameService")
		saves.autosave_enabled = false
		_expect(saves.load_now(SAVE), "Cold restart could not load tribal snapshot")
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://tribal_expected.json"))
		_expect(JSON.parse_string(JSON.stringify(progression.export_state()["tribal"])) == expected, "Cold restart changed achievements, purchases or worker evidence")
		_expect(is_equal_approx(float(progression.get_behavior_effect("group_cooperation", 1)["value"]), 1.2), "Cold restart lost or compounded work bonus")
		_finish()
		return
	await super._run()

func _capture(label: String) -> void:
	var earned: int = int(progression.get_behavior_wallet(1)["earned"]["social"])
	if label == "03_transport":
		_expect(earned == 0, "Picking up cargo earned points before delivering")
	if label == "04_tool":
		_expect(earned == 6, "Real transports and jointly completed tool did not earn six points: %d" % earned)
	if label == "05_village":
		# Housing transport takes longer than the old decorative huts. Automatic
		# meals can make the base scenario's total reach three before EVERY citizen
		# has eaten. Earn the community goal through actual additional deliveries.
		if not progression.export_state()["tribal"]["awards"].has("shared_meals"):
			tribe.select_all()
			_expect(tribe.issue_order("food"), "Cannot gather shared meal supplies")
			await _until(func() -> bool: return int(tribe.village()["stock"]["food"]) >= 3, 700)
			_expect(tribe.issue_order("feed"), "Cannot feed the whole group")
			await _until(func() -> bool: return progression.export_state()["tribal"]["awards"].has("shared_meals"), 700)
			earned = int(progression.get_behavior_wallet(1)["earned"]["social"])
		_expect(earned == 14, "Shared stock, tool, shelter and meals did not earn fourteen points: %d; evidence=%s" % [earned, str(progression.export_state()["tribal"])])
		await _check_progression()
	await super._capture(label)

func _check_progression() -> void:
	var skills: Node = player.find_child("PlayerProgression", true, false)
	_expect(skills.open_panel(), "Cannot open progression in actual tribal mode")
	skills._select_phase(1)
	var creature: Dictionary = progression.get_behavior_wallet(0)
	var before: Dictionary = progression.export_state()
	var before_campaign: Dictionary = state.campaign.export_state()
	skills._show_development()
	skills._development.refresh()
	for target: int in [2, 3]:
		_expect(skills._development._epochs[target]["action"].disabled, "Future era presents an active confirmation")
	_expect(progression.export_state() == before and state.campaign.export_state() == before_campaign, "Viewing goals mutates points or the civilization")
	skills._show_tab(false)
	saves.save_path = "user://no-such-tribal-directory/save.json"
	_expect(progression.purchase_behavior_node("tribe.social.teamwork")["reason"] == "save_failed", "Purchase did not report the failed snapshot")
	_expect(progression.export_state() == before and is_equal_approx(float(progression.get_behavior_effect("group_cooperation", 1)["value"]), 1.0), "Failed purchase spent points or activated the skill")
	saves.save_path = SAVE
	for id: String in ["tribe.social.teamwork", "tribe.social.practice"]:
		skills._select(id)
		skills._scroll.ensure_control_visible(skills._purchase)
		await _frames(4)
		await _click(skills._purchase)
	_expect(progression.get_behavior_wallet(1)["spent"]["social"] == 8 and progression.get_behavior_wallet(1)["available"]["social"] == 6, "Actual GUI purchase used the wrong balance")
	_expect(progression.get_behavior_wallet(0) == creature, "Tribal purchase spent creature points")
	_expect(is_equal_approx(tribe._work_rate(tribe.village()["members"][0]), 1.2), "Purchased coordination does not affect the real worker rate")
	for target: int in [2, 3]:
		_expect(not saves.request_phase_transition(target, "confirmed-by-points"), "Points or an invented confirmation bypassed the era gate")
	_expect(state.current_phase == 1 and Epoch.validate_retention(before_campaign, state.campaign.data).is_empty(), "Blocked transition changed inhabitants or campaign identity")
	_expect(saves.save_now(), "Cannot save earned tribal progress")
	var expected: Dictionary = JSON.parse_string(JSON.stringify(progression.export_state()["tribal"]))
	var output: FileAccess = FileAccess.open("user://tribal_expected.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(expected))
	output.close()
	var restart_output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/tribal_progression_world_test.gd", "--", "--verify-tribal"], restart_output, true)
	_expect(result == 0 and not str(restart_output).contains("SCRIPT ERROR"), "Fresh process failed: " + str(restart_output))
	for repeat in range(3):
		_expect(saves.load_now(), "Repeated load failed")
		_expect(JSON.parse_string(JSON.stringify(progression.export_state()["tribal"])) == expected, "Loading repaid a milestone or lost purchases")
	# Snapshot copy is a distinct campaign retaining its paid work history.
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var copy: String = saves._write_slot_copy(source, "Stammesfortschritt Kopie", "copy")
	_expect(not copy.is_empty(), "Copy cannot retain the tribal ledger")
	if not copy.is_empty():
		var copied: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(copy))
		_expect(copied["progression"]["tribal"]["campaign_id"] == copied["game_state"]["campaign"]["id"] and copied["progression"]["tribal"]["awards"] == expected["awards"], "Copy lost achievements or kept the source campaign binding")
	# Current complete villages in old progression format earn nothing retroactively.
	var legacy: Dictionary = source.duplicate(true)
	legacy["progression"]["schema"] = 4
	legacy["progression"].erase("tribal")
	_expect(saves._validate_save(legacy).is_empty(), "Previous integrated progression schema 4 rejected")
	_expect(progression.import_state(legacy["progression"]) and progression.get_behavior_wallet(1)["earned"]["social"] == 0, "Migration invented old tribal achievements")
	_expect(progression.import_state(source["progression"]), "Cannot restore current tribal ledger")
	var future: Dictionary = source.duplicate(true)
	future["progression"]["tribal"]["schema"] = Tribal.SCHEMA + 1
	_expect(saves._has_unsupported_contract(future), "Future tribal sub-schema is not protected")
	# Display the exact reviewed controls at a narrow resolution.
	root.size = Vector2i(800, 900)
	skills._select_phase(1)
	skills._show_tab(false)
	skills._scroll.scroll_vertical = 0
	await _frames(6)
	await super._capture("06_tribal_skilltree")
	skills._show_development()
	skills._scroll.ensure_control_visible(skills._development._epochs[2]["title"])
	await _frames(6)
	var bounds: Rect2 = root.get_visible_rect()
	for controls: Dictionary in skills._development._epochs.values():
		for key: String in ["title", "goals", "action"]:
			var rect: Rect2 = controls[key].get_global_rect()
			_expect(rect.position.x >= 0 and rect.end.x <= bounds.end.x, "Epoch UI overflows a narrow viewport: " + key)
	await super._capture("07_medieval_requirements")
	root.size = Vector2i(1280, 800)
	skills.close_panel()
	await _frames(8)

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_progression_world", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
