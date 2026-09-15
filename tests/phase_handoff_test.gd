extends "res://tests/tribal_age_test.gd"
## Reuses the real home/player/navigation/UI fixture; no fake confirmation port.
const Handoff = preload("res://core/campaign/phase_handoff.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const EXPECTED: String = "user://phase_handoff_expected.json"
var signals_seen := {"phase": 0, "event": 0, "save_started": 0}


func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	if "--handoff-restart" in OS.get_cmdline_user_args():
		await _restart()
		return
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().get("ok", false), "Home fixture did not establish.")
	await _frames(15)
	# Add opaque future data and a second visited body to exercise whole-campaign retention.
	state.get_current_body_record()["handoff_extension"] = {"binding": "retained", "fractions": [0.25, 0.75]}
	var remote: Dictionary = state.campaign.ensure_body(12346, state.system_seed, state.active_system_id)
	state.campaign.body_record(remote.id)["handoff_extension"] = {"cargo": "retained", "quantity": 7}
	_expect(saves.save_now(), "Could not checkpoint the original campaign.")
	_expect(tribe.panel.open_confirmation() and not tribe.panel.confirm.disabled, "Confirmation unavailable: " + tribe.panel._detail.text)
	if tribe.panel.confirm.disabled:
		await _cleanup()
		await _finish()
		return
	var before: Dictionary = state.campaign.export_state()
	var progression: Dictionary = root.get_node("ProgressionService").export_state()
	var disk: String = FileAccess.get_file_as_string(SAVE)
	var token: String = tribe._token
	var prepared: Dictionary = Handoff.prepare(state, 1, token)
	_expect(prepared.ok, "Confirmed preparation failed: " + str(prepared))
	_expect(state.current_phase == 0 and state.campaign.data == before and FileAccess.get_file_as_string(SAVE) == disk,
		"Preparing a handoff mutated the campaign, phase or disk.")
	if not prepared.ok:
		tribe.panel.cancel_confirmation()
		await _cleanup()
		await _finish()
		return
	var candidate_body: Dictionary = prepared.campaign.bodies[state.active_body_id]
	_expect(Handoff.Civilization.validate_retention(before, prepared.campaign).is_empty(), "Preparation lost existing data.")
	candidate_body.tribe.stock.wood = 13
	_expect(tribe._prepared.stock.wood == 0 and not state.get_current_body().has("tribe"), "Candidate aliases the controller or live state.")
	_expect(not saves.request_phase_transition(1, "expired") and not saves.request_phase_transition(2, token), "Stale confirmation or phase skip accepted.")
	var original_id: String = tribe._prepared.members[1].id
	tribe._prepared.members[1].id = "replacement-companion"
	_expect(not saves.request_phase_transition(1, token), "Invalid resident reached the writer.")
	tribe._prepared.members[1].id = original_id
	state.get_current_body_record()["tribe"] = tribe._prepared.duplicate(true)
	_expect(not Handoff.prepare(state, 1, token).ok, "A stored village could be overwritten by phase entry.")
	state.get_current_body_record().erase("tribe")
	state.campaign.data.pending_transition = {"id": "other-handoff"}
	_expect(not Handoff.prepare(state, 1, token).ok, "Another pending handoff was ignored.")
	state.campaign.data.pending_transition = {}
	_expect(state.campaign.data == before and FileAccess.get_file_as_string(SAVE) == disk, "Rejected preparations changed the original.")
	state.phase_changed.connect(_phase_committed)
	state.campaign_event.connect(func(event: Dictionary) -> void:
		if int(event.get("kind", -1)) == Handoff.GameEvent.Kind.PHASE_TRANSITION:
			signals_seen.event += 1)
	saves.save_started.connect(func(_path: String) -> void:
		signals_seen.save_started += 1
		_expect(saves.is_phase_transition_active(), "Writer started without the transition lock.")
		_expect(not saves.request_phase_transition(1, token), "Reentrant confirmation started a second commit."))
	var blocked: FileAccess = FileAccess.open("user://phase_handoff_blocked", FileAccess.WRITE)
	blocked.store_string("not a directory")
	blocked.close()
	saves.save_path = "user://phase_handoff_blocked/campaign.json"
	_expect(not saves.request_phase_transition(1, token), "Write failure reported success.")
	_expect(state.current_phase == 0 and state.campaign.data == before and signals_seen.phase == 0 and signals_seen.event == 0,
		"Write failure leaked a phase, receipt, event, or campaign change.")
	_expect(not saves.is_phase_transition_active() and home.actors.size() == 2 and not tribe._active and tribe.camera == null,
		"Failed commit changed the live controller or retained its lock.")
	_expect(FileAccess.get_file_as_string(SAVE) == disk and root.get_node("ProgressionService").export_state() == progression,
		"Write failure changed saved originals or progression.")
	saves.save_path = SAVE
	# The same still-valid paused confirmation can retry; no phantom completion receipt.
	tribe.panel.confirm.pressed.emit()
	_expect(state.current_phase == 1 and signals_seen.phase == 1 and signals_seen.event == 1 and signals_seen.save_started == 2,
		"Successful retry did not commit and announce exactly once.")
	_expect(not saves.request_phase_transition(1, token), "Double confirmation repeated the handoff.")
	await _until(func() -> bool: return tribe.is_active(), 600)
	_expect(tribe.is_active() and tribe.camera.current and not player.is_physics_processing(), "Committed phase did not transfer group/camera control.")
	_expect(tribe.actors.size() == 3 and home.actors.is_empty() and tribe.actors[state.campaign.data.player_object_id] == player,
		"Control transfer replaced or duplicated original residents.")
	_expect(root.get_node("ProgressionService").export_state() == progression, "Handoff changed progression.")
	# Even forged availability flags and sequential enum values cannot register later runtimes.
	var phase: int = state.current_phase
	for target in [2, 3, 4, 5, 6]:
		state.current_phase = target - 1
		var snapshot: Dictionary = state.campaign.export_state()
		_expect(not state.get_phase_transition_blockers(target).is_empty() and not saves.request_phase_transition(target, token),
			"Unimplemented phase accepted: " + str(target))
		_expect(state.campaign.data == snapshot, "Rejected later phase mutated campaign.")
	state.current_phase = phase
	var saved: Dictionary = saves._read_save(SAVE)
	_expect(saved.game_state.campaign.completed_transitions.size() == 1 and saved.game_state.campaign.pending_transition.is_empty(),
		"Successful save contains multiple or pending handoffs.")
	_expect(Atomic.write(EXPECTED, {"saved": saved, "before": before}, false) == OK, "Cannot write restart evidence.")
	await _cleanup()
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/phase_handoff_test.gd", "--", "--handoff-restart"], output, true)
	_expect(exit_code == 0 and str(output).contains("PHASE_HANDOFF_RESTART_PASSED"), "Fresh process failed: " + str(output))
	await _finish()


func _phase_committed(phase: int) -> void:
	signals_seen.phase += 1
	var raw: Dictionary = saves._read_save(SAVE)
	_expect(phase == 1 and int(raw.game_state.phase) == 1 and raw.game_state.campaign.completed_transitions.size() == 1,
		"Control signal preceded the durable phase/village commit.")


func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	_expect(saves.load_now(), "Fresh process could not load the completed handoff: " + saves.last_error)
	_expect(_json(state.campaign.data) == expected.saved.game_state.campaign, "Fresh process changed the saved campaign.")
	_expect(_json(root.get_node("ProgressionService").export_state()) == expected.saved.progression, "Fresh process changed progression.")
	_expect(Handoff.Civilization.validate_retention(expected.before, _json(state.campaign.data)).is_empty(), "Restart lost source data.")
	var events: Dictionary = state.campaign.data.event_cursors.duplicate(true)
	var disk: String = FileAccess.get_file_as_string(SAVE)
	_expect(not saves.request_phase_transition(1, "old-token") and saves.load_now(), "Completed handoff could not be reloaded safely.")
	_expect(state.campaign.data.event_cursors == events and FileAccess.get_file_as_string(SAVE) == disk, "Reload paid or saved a second transition.")
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _until(func() -> bool: return tribe.is_active(), 600)
	_expect(tribe.is_active() and tribe.actors.size() == 3 and home.actors.is_empty() and tribe.camera.current,
		"Fresh process failed to restore the same three residents and group control.")
	await _cleanup()
	if failures.is_empty(): print("PHASE_HANDOFF_RESTART_PASSED")
	await _finish()


func _json(value: Variant) -> Variant:
	return JSON.parse_string(Atomic.stringify(value))


func _finish() -> void:
	print(JSON.stringify({"test": "phase_handoff", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
