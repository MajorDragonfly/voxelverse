extends "tribal_age_economy_test.gd"
const Tribal = preload("res://core/progression/tribal_progression.gd")
var progression: Node

func _run() -> void:
	progression = root.get_node("ProgressionService")
	if "--verify-economy-progress" in OS.get_cmdline_user_args():
		saves = root.get_node("SaveGameService")
		saves.autosave_enabled = false
		_expect(saves.load_now(SAVE), "Fresh process cannot load village/evidence snapshot")
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://economy_progress_expected.json"))
		_expect(JSON.parse_string(JSON.stringify(progression.export_state()["tribal"])) == expected, "Cold load changed progress or repaid the achievements")
		_expect(progression.get_tribal_economy_progress()["supply"]["met"] and progression.get_tribal_economy_progress()["professions"]["met"], "Cold restart lost earned economy prerequisites")
		_finish()
		return
	await super._run()

func _capture(label: String) -> void:
	if label == "01_workplaces":
		_expect(progression.get_behavior_wallet(1)["earned"]["social"] == 0, "Migration or new workplace construction granted instant community points")
	if label == "02_professions":
		var record: Dictionary = _record()
		_expect(int(record.get("jobs", {}).get("forester", {}).get("units", 0)) >= 1, "Save/load of paused real cargo lost its work attribution")
	await super._capture(label)

func _cleanup() -> void:
	if is_instance_valid(tribe) and tribe.is_active() and failures.is_empty():
		await _check_economy_progress()
	await super._cleanup()

func _check_economy_progress() -> void:
	print("Tribal economy: checking actual work receipts and active supply window")
	# The inherited scenario consumed/renewed initial deposits, built all four
	# workplaces and physically delivered materials with several professions.
	_expect(progression.get_tribal_economy_progress()["professions"]["met"], "Actual distinct workers and deliveries did not complete professions: " + str(_record()))
	var snapshot: Dictionary = progression.export_state()["tribal"]
	var village_snapshot: Dictionary = tribe.village().duplicate(true)
	paused = true
	await _frames(30)
	_expect(progression.export_state()["tribal"] == snapshot, "Global pause advanced economic evidence")
	_expect(saves.save_now() and saves.load_now(), "Running supply clock cannot save/load")
	_expect(JSON.parse_string(JSON.stringify(progression.export_state()["tribal"])) == JSON.parse_string(JSON.stringify(snapshot)), "Loading granted offline supply time or lost receipts")
	# Compare the exact persisted numeric representation, not the retired
	# rounded JSON writer. Keep strict equality for every resident/resource.
	_expect(tribe.village() == JSON.parse_string(Atomic.stringify(village_snapshot)), "Evidence persistence changed residents or village resources")
	paused = false
	# Continue only active simulated time; no edits to counters, clock or awards.
	state.set_simulation_speed(4)
	await _until(func() -> bool: return progression.get_tribal_economy_progress()["supply"]["met"], 2300)
	_expect(progression.get_tribal_economy_progress()["supply"]["met"], "Real maintained village never completed supply: " + str(progression.get_tribal_economy_progress()))
	_expect(progression.export_state()["tribal"]["awards"].has("working_professions") and progression.export_state()["tribal"]["awards"].has("sustained_supply"), "Economy prerequisites did not earn both separate milestones")
	var paid: Dictionary = progression.get_behavior_wallet(1)
	var current: Dictionary = progression.export_state()["tribal"]
	progression.record_tribal_tick(1.0, tribe)
	_expect(progression.export_state()["tribal"] == current, "Duplicate same-frame tick advanced the clock")
	paused = true
	var path: Dictionary = progression.get_development_path()
	for epoch: Dictionary in path["epochs"]:
		_expect(not epoch["available"] and not epoch["implemented"], "Economy progress enabled an unfinished epoch")
		if epoch["target"] == 2:
			for requirement: Dictionary in epoch["requirements"]:
				if requirement["id"] in ["supply", "professions"]:
					_expect(requirement["supported"] and requirement["met"], "Development path lacks verified live prerequisite: " + requirement["id"])
	_expect(not saves.request_phase_transition(2, "economy-complete") and state.current_phase == 1, "Completed prerequisites bypassed runtime gate")
	_expect(saves.save_now(), "Completed economy evidence cannot save")
	var expected: Dictionary = JSON.parse_string(JSON.stringify(progression.export_state()["tribal"]))
	var output: FileAccess = FileAccess.open("user://economy_progress_expected.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(expected))
	output.close()
	var restart_output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/tribal_economy_progress_world_test.gd", "--", "--verify-economy-progress"], restart_output, true)
	_expect(result == 0 and not str(restart_output).contains("SCRIPT ERROR"), "Fresh process failed: " + str(restart_output))
	for repeat in range(3):
		_expect(saves.load_now() and progression.get_behavior_wallet(1) == paid, "Repeated load repaid economic milestones")
	var future: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	future["progression"]["tribal"]["villages"][tribe.village()["id"]]["economy"]["schema"] += 1
	_expect(saves._has_unsupported_contract(future), "Save service misses a future nested economy contract")
	var copied_path: String = saves._write_slot_copy(JSON.parse_string(FileAccess.get_file_as_string(SAVE)), "Wirtschaftsnachweis Kopie", "copy")
	_expect(not copied_path.is_empty(), "Cannot copy a campaign with economic progress")
	if not copied_path.is_empty():
		var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(copied_path))
		_expect(copy["progression"]["tribal"]["villages"] == expected["villages"] and copy["progression"]["tribal"]["campaign_id"] == copy["game_state"]["campaign"]["id"], "Campaign copy lost or detached economic receipts")
	evidence["progression"] = {"wallet": paid, "economy": progression.get_tribal_economy_progress(), "receipts": _record()}
	paused = false
	state.set_simulation_speed(1)

func _record() -> Dictionary:
	return progression.export_state()["tribal"]["villages"].get(tribe.village()["id"], {}).get("economy", {})

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_economy_progress_world", "passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
