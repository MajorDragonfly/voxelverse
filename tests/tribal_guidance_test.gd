extends SceneTree
## The existing optional participant owns both introductions, including migration.
const Progress = preload("res://core/onboarding_progress.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const EXPECTED := "user://tribal_guidance_restart.json"
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--tribal-guidance-restart" in OS.get_cmdline_user_args():
		var expected := Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
		_expect(saves.select_slot(expected.path), "Fresh process could not load tutorial save.")
		_expect(_normalized(saves.guidance.export_state()) == expected.guide and state.campaign.data.id == expected.campaign_id, "Fresh process changed tutorial or campaign identity.")
		_expect(saves.guidance.tribal_step() == "tribe_delivery" and saves.save_now(), "Fresh process did not resume the chosen incomplete chapter.")
		if failures.is_empty(): print("TRIBAL_GUIDANCE_RESTART_PASSED")
		await _finish()
		return
	var model := Progress.new()
	_expect(model.tribal_step().is_empty(), "Legacy/default progress forces the tribe guide.")
	model.reset(true)
	model.record("tribe")
	_expect(model.current_step().is_empty() and model.tribal_step() == "tribe_camera" and model.tribal_completed() == 0, "Handoff fabricated tribe exercises or hid the new guide.")
	_expect(not model.record_tribal("invalid") and not model.record_tribal("tribe_camera", NAN) and not model.record_tribal("tribe_camera", -1), "Invalid evidence advanced the guide.")
	model.record_tribal("tribe_camera", 1.25)
	model.record_tribal("tribe_place")
	var partial: Dictionary = model.export_state()
	model.import_state(_normalized(partial))
	_expect(is_equal_approx(model.tribal_amount("tribe_camera"), 1.25) and model.tribal_done("tribe_place") and not model.tribal_done("tribe_finish"), "Partial movement/placement was lost or finished construction early.")
	model.skip_tribal()
	var skipped := model.export_state()
	_expect(not model.record_tribal("tribe_delivery") and model.export_state() == skipped, "Skipped guide accepted evidence.")
	_expect(model.select_tribal("tribe_work") and model.tribal_step() == "tribe_order" and not model.select_tribal("invalid"), "Chapter selection cannot resume partial work.")
	var creature: Dictionary = model.data.progress.duplicate(true)
	model.restart_tribal()
	_expect(model.data.progress == creature and model.tribal_completed() == 0, "Tribe restart erased the creature introduction.")
	for step: String in Progress.TRIBE_STEPS: model.record_tribal(step, 1000)
	_expect(model.tribal_completed() == 11 and model.tribal_step().is_empty() and model.tribal_amount("tribe_camera") == 4, "Completed guide did not stop/clamp.")
	model.import_state({"schema": 2, "skipped": false, "focus": "home", "progress": {"move": 1.75, "command": 1}})
	_expect(model.tribal_step().is_empty() and model.amount("move") == 1.75 and model.done("command"), "v2 migration forced tribe help or lost old progress.")
	_expect(model.select_tribal("tribe_build") and model.tribal_step() == "tribe_tool", "Old campaign cannot opt in to tribe help.")
	model.import_state({"schema": 3, "progress": {}, "tribal": {"skipped": false, "focus": "invalid", "progress": {"tribe_camera": INF, "tribe_place": -1, "tribe_finish": "yes", "tribe_single": 500}}})
	_expect(model.tribal_completed() == 1 and model.tribal_done("tribe_single") and model.tribal_step() == "tribe_camera", "Malformed optional progress fabricated completion.")
	for version: float in [2.5, 4, 99]:
		var future := {"schema": version, "future": ["keep"], "tribal": {"future_step": 0.5}}
		model.import_state(future)
		model.restart_tribal()
		model.skip_tribal()
		_expect(not model.select_tribal("tribe_work") and not model.record_tribal("tribe_camera", 4) and model.export_state() == future, "Unknown version was changed by tribe controls.")
	var path: String = saves.create_slot("Tribe guide", 23757, "legacy_plane_v9")
	_expect(not path.is_empty() and saves.guidance.tribal_step() == "tribe_camera", "New campaign did not enable tribe help.")
	saves.guidance.record_tribal("tribe_camera", 1.5)
	saves.guidance.record_tribal("tribe_order")
	saves.guidance.select_tribal("tribe_work")
	_expect(saves.save_now(), "Cannot save partial tribe guide.")
	partial = saves.guidance.export_state()
	var bytes: String = FileAccess.get_file_as_string(path)
	saves.guidance.restart_tribal()
	_expect(saves.load_now() and saves.guidance.export_state() == partial, "Reload lost partial tribe progress.")
	saves.session_active = false
	var copied: String = saves.duplicate_slot(path)
	_expect(saves.select_slot(copied) and saves.guidance.export_state() == partial, "Copied adventure lost tribe guide.")
	saves.guidance.skip_tribal()
	_expect(saves.save_now() and saves.load_now() and saves.guidance.tribal_step().is_empty(), "Skipped guide did not survive reload.")
	_expect(FileAccess.get_file_as_string(path) == bytes, "Skipping in a copy changed the original.")
	saves.save_path = "user://missing_tribal_guide/save.json"
	saves.guidance.restart_tribal()
	_expect(not saves.save_now() and FileAccess.get_file_as_string(path) == bytes, "Failed guide write replaced the valid save.")
	saves.save_path = path
	_expect(saves.load_now(), "Cannot restore original guide after failed write.")
	var expected := {"path": path, "campaign_id": state.campaign.data.id, "guide": _normalized(partial)}
	_expect(Atomic.write(EXPECTED, expected, false) == OK, "Cannot prepare cold-resume check.")
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/tribal_guidance_test.gd", "--", "--tribal-guidance-restart"], output, true)
	_expect(code == 0 and str(output).contains("TRIBAL_GUIDANCE_RESTART_PASSED"), "Fresh process failed: " + str(output))
	var future := {"schema": 99, "tribal": {"future_step": ["preserve"]}}
	saves.guidance.import_state(future)
	_expect(saves.save_now() and saves.load_now() and _normalized(saves.guidance.export_state()) == _normalized(future), "Shared save participant discarded future tutorial data.")
	if failures.is_empty(): print("TRIBAL_GUIDANCE_PASSED: migration, partial chapters, independent copies, failed writes, cold resume and future protection.")
	await _finish()

func _normalized(value: Dictionary) -> Dictionary:
	return Atomic.parse_dictionary(JSON.stringify(value))

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
