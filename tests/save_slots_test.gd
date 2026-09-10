extends SceneTree

const Atomic = preload("res://core/persistence/atomic_json.gd")
const History = preload("res://core/persistence/slot_history.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
var failures: Array[String] = []
var saves: Node
var state: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	saves.session_managed = true
	var original: String = saves.create_slot("Original", 15838, "legacy_plane_v9")
	_expect(not original.is_empty(), "Could not create the original slot.")
	await process_frame
	var event = state.campaign.next_event(GameEvent.Kind.INTERACTION, "shared_target", 0, "befriended")
	event.encounter_id = "first_encounter"
	event.behavior_context = {"target_relation": "neutral"}
	_expect(state.record_campaign_event(event), "Fixture event was rejected.")
	saves.record_design("user://building_designs/original.json", '{"name":"Original house","design_id":"design_retained"}')
	state.campaign.data.elapsed_seconds = 12.0
	_expect(saves.save_now(), "Could not save the starting point.")
	var original_bytes: String = FileAccess.get_file_as_string(original)
	var before: Dictionary = Atomic.parse_dictionary(original_bytes)
	var campaign_id: String = state.campaign.data.id
	_expect(saves.duplicate_slot(original).is_empty(), "Slot management was allowed in a live session.")
	saves.session_active = false
	var copied: String = saves.duplicate_slot(original, "Versuch")
	_expect(not copied.is_empty() and copied != original, "Copy did not create a separate file.")
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "Copy modified original bytes.")
	var copy_data: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(copied))
	_expect(copy_data.game_state.campaign.id != campaign_id, "Copy retained the campaign identity.")
	_expect(copy_data.design_files == before.design_files and copy_data.progression == before.progression and copy_data.regions_by_body == before.regions_by_body, "Copy lost embedded designs/progression/ecology.")
	_expect(state.campaign.data.id == campaign_id and saves.save_path == original, "Copy loaded its state into the live services.")
	_expect(saves.select_slot(copied), "Could not load the copied slot.")
	_expect(not state.record_campaign_event(event), "Copy accepted an event from the original campaign.")
	var repeated = state.campaign.next_event(GameEvent.Kind.INTERACTION, "shared_target", 0, "befriended")
	repeated.encounter_id = "another_encounter"
	repeated.behavior_context = {"target_relation": "neutral"}
	state.record_campaign_event(repeated)
	var behavior: Dictionary = root.get_node("ProgressionService").export_state()
	_expect(Atomic.parse_dictionary(JSON.stringify(behavior)) == before.progression and int(behavior.behavior.phases["0"].earned.social) == 3, "Copy awarded a paid target twice.")
	saves.record_design("user://building_designs/original.json", '{"name":"Copy house","design_id":"design_retained"}')
	state.campaign.data.elapsed_seconds = 30.0
	_expect(saves.save_now(), "Saving the copied campaign failed.")
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "Saving the copy overwrote the original.")
	_expect(saves.select_slot(original), "Original did not load after playing its copy.")
	_expect(saves._design_files["user://building_designs/original.json"].contains("Original house"), "Original inherited copied designs.")
	for index in range(History.MAX_SNAPSHOTS + 3):
		state.campaign.data.elapsed_seconds = 100.0 + index
		_expect(saves.save_now(), "History rotation interrupted a valid save.")
	_expect(History.paths(original).size() == History.MAX_SNAPSHOTS, "History did not obey its size limit.")
	var last_original: String = FileAccess.get_file_as_string(original)
	saves.session_active = false
	var entries: Array = saves.list_slot_history(original)
	_expect(not entries.is_empty() and entries[0].can_copy, "No compatible recovery entry was offered.")
	var recovery_source: String = entries[entries.size() - 1].source
	var source_bytes: String = FileAccess.get_file_as_string(recovery_source)
	var restored: String = saves.restore_slot_copy(original, recovery_source)
	_expect(not restored.is_empty() and restored != original and restored != copied, "Recovery did not create an independent adventure.")
	_expect(FileAccess.get_file_as_string(original) == last_original and FileAccess.get_file_as_string(recovery_source) == source_bytes, "Recovery changed its source/current slot.")
	var restored_data: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(restored))
	_expect(float(restored_data.game_state.campaign.elapsed_seconds) == float(Atomic.parse_dictionary(source_bytes).game_state.campaign.elapsed_seconds), "Recovery used current progress instead of the selected snapshot.")
	_expect(saves.restore_slot_copy(original, copied).is_empty(), "Recovery accepted an unrelated source path.")
	var original_time: int = int(saves.inspect_slot(original).saved_time)
	_expect(saves.rename_slot(original, "Umbenannt"), "Renaming failed.")
	_expect(saves.inspect_slot(original).name == "Umbenannt" and int(saves.inspect_slot(original).saved_time) == original_time, "Renaming changed saved progress time.")
	_expect(not saves.rename_slot(original, "  "), "Empty name was accepted.")
	recovery_source = saves.list_slot_history(original)[0].source
	# An unavailable history directory must not destroy the last committed save.
	var blocked: String = saves.duplicate_slot(original, "Schreibtest")
	var blocker := FileAccess.open(History.directory(blocked), FileAccess.WRITE)
	blocker.store_string("not a directory")
	blocker.close()
	_expect(saves.select_slot(blocked), "Blocked-history fixture did not load.")
	var blocked_bytes: String = FileAccess.get_file_as_string(blocked)
	state.campaign.data.elapsed_seconds = 999.0
	_expect(not saves.save_now() and FileAccess.get_file_as_string(blocked) == blocked_bytes, "Failed history capture replaced the live save.")
	# Explicit recovery can read a compatible history while leaving a future
	# main file untouched; ordinary loading never silently downgrades it.
	saves.session_active = false
	var future: Dictionary = Atomic.parse_dictionary(last_original)
	future.schema = 999
	Atomic.write(original, future, false)
	var future_bytes: String = FileAccess.get_file_as_string(original)
	_expect(not saves.inspect_slot(original).valid and saves.duplicate_slot(original).is_empty(), "Future save was silently copied/downgraded.")
	var recovered: String = saves.restore_slot_copy(original, recovery_source)
	_expect(not recovered.is_empty() and FileAccess.get_file_as_string(original) == future_bytes, "Explicit old-snapshot recovery touched a future save.")
	var invalid := FileAccess.open(recovery_source, FileAccess.WRITE)
	invalid.store_string("{broken")
	invalid.close()
	_expect(saves.restore_slot_copy(original, recovery_source).is_empty(), "Corrupt recovery snapshot was accepted.")
	_expect(not saves.rename_slot("user://outside.json", "Outside"), "Slot management accepted an unrelated path.")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("SAVE_SLOTS_PASSED: independent copies, paid-target deduplication, embedded designs, bounded history, selected recovery, rename, failed writes and future/corrupt snapshots.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
