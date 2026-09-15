extends SceneTree
## Public title button -> real sphere -> explicit handoff -> work -> cold resume.
const Playtest = preload("res://ui/frontend/tribal_playtest.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const EXPECTED: String = "user://tribal_playtest_expected.json"
var failures: Array[String] = []
var flow: Node
var saves: Node
var state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	if "--tribal-playtest-restart" in OS.get_cmdline_user_args():
		await _restart()
		await _finish()
		return
	var original: String = saves.create_slot("Existing adventure", 23757)
	_expect(not original.is_empty(), "Original slot creation failed.")
	var original_bytes: String = FileAccess.get_file_as_string(original)
	var original_id: String = state.campaign.data.id
	flow.enter_frontend()
	current_scene._show_home()
	var slots_before: int = saves.list_slots().size()
	current_scene.find_child("TribalPlaytest", true, false).pressed.emit()
	_expect(saves.list_slots().size() == slots_before and state.campaign.data.id == original_id, "Opening the test description mutated saves.")
	current_scene.find_child("Back", true, false).pressed.emit()
	_expect(saves.list_slots().size() == slots_before, "Canceling the menu created a test slot.")
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		current_scene.find_child("TribalPlaytest", true, false).pressed.emit()
		var button: Button = current_scene.find_child("BeginTribalPlaytest", true, false)
		_expect(button.tr(button.text) != button.text, "Playtest action missing translation: " + locale)
		current_scene.find_child("Back", true, false).pressed.emit()
	# Cancel while the launcher owns the player, using the actual Escape input.
	flow.world_started.connect(func() -> void: call_deferred("_cancel_preparation"), CONNECT_ONE_SHOT)
	current_scene.find_child("TribalPlaytest", true, false).pressed.emit()
	current_scene.find_child("BeginTribalPlaytest", true, false).pressed.emit()
	await _until(func() -> bool: return not flow.loading and not flow.has_node("TribalPlaytestLauncher"), 60000)
	_expect(current_scene.scene_file_path == flow.SPHERE_SCENE and state.current_phase == 0
		and current_scene.player.process_mode != Node.PROCESS_MODE_DISABLED, "Preparation cancellation did not restore the creature.")
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "Canceled preparation changed the original.")
	flow.return_to_title()
	await scene_changed
	slots_before = saves.list_slots().size()
	current_scene.find_child("TribalPlaytest", true, false).pressed.emit()
	current_scene.find_child("BeginTribalPlaytest", true, false).pressed.emit()
	print("TRIBAL_PLAYTEST_STAGE: preparing public entry")
	_expect(not Playtest.start(flow), "Double launch accepted.")
	await _until(func() -> bool:
		var tribe: Node = current_scene.get_node_or_null("Nest/Tribe")
		return tribe != null and tribe.panel.confirmation_open, 90000)
	var tribe: Node = current_scene.get_node_or_null("Nest/Tribe")
	_expect(tribe != null and tribe.panel.confirmation_open, "Public test entry did not prepare the confirmation.")
	if tribe == null or not tribe.panel.confirmation_open:
		if is_instance_valid(flow.get_node_or_null("TribalPlaytestLauncher")):
			print("PLAYTEST_SETUP_STATUS ", flow.get_node("TribalPlaytestLauncher")._detail.text)
		await _finish()
		return
	saves.autosave_enabled = false
	print("TRIBAL_PLAYTEST_STAGE: confirmation ready")
	var path: String = saves.save_path
	_expect(path != original and state.campaign.data.id != original_id and saves.list_slots().size() == slots_before + 1, "Test did not create exactly one independent campaign.")
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "Test setup altered the original save.")
	_expect(state.current_phase == 0 and not tribe.panel.confirm.disabled and not state.get_current_body().has("tribe"), "Setup skipped confirmation or cannot enter the tribe.")
	_expect(tribe.home.actors.size() == 2 and current_scene.player.process_mode != Node.PROCESS_MODE_DISABLED, "Setup lost companions or left player disabled.")
	var before_cancel: String = FileAccess.get_file_as_string(path)
	tribe.panel.cancel.pressed.emit()
	_expect(not paused and state.current_phase == 0 and FileAccess.get_file_as_string(path) == before_cancel, "Cancel changed phase or persisted a handoff.")
	_expect(not Playtest.start(flow), "Playtest launcher accepted an active campaign.")
	_expect(tribe.panel.open_confirmation(), "Could not reopen ordinary transition after cancellation.")
	tribe.panel.confirm.pressed.emit()
	print("TRIBAL_PLAYTEST_STAGE: confirmed")
	await _until(func() -> bool: return tribe.is_active(), 20000)
	_expect(tribe.is_active() and state.current_phase == 1, "Confirmed test did not activate the tribal runtime: " + saves.last_error)
	if tribe.is_active():
		_expect(tribe.actors.size() == 3 and tribe.home.actors.is_empty() and tribe.camera.current and not tribe.player.is_physics_processing(), "Group/camera ownership did not transfer.")
		_expect(flow.get_node_or_null("TribalPlaytestLauncher") == null, "Launcher survived completion.")
		tribe.select_all()
		_expect(tribe.issue_order("wood"), "Test residents cannot accept resource gathering.")
		await _until(func() -> bool: return tribe.village().stock.wood > 0, 20000)
		_expect(tribe.village().stock.wood > 0, "No wood reached the test village on real terrain.")
		print("TRIBAL_PLAYTEST_STAGE: wood delivered")
		tribe.issue_order("wait")
		flow.toggle_pause()
		_expect(saves.save_now(), "Test village save failed.")
		var expected := {"path": path, "original": original, "original_hash": original_bytes.sha256_text(),
			"campaign_id": state.campaign.data.id, "resident_ids": tribe.actors.keys(),
			"wood": tribe.village().stock.wood, "transitions": state.campaign.data.completed_transitions.duplicate(true)}
		_expect(Atomic.write(EXPECTED, expected, false) == OK, "Could not save restart expectation.")
		flow.return_to_title()
		await scene_changed
		print("TRIBAL_PLAYTEST_STAGE: restarting")
		var output: Array = []
		var arguments: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/tribal_playtest_test.gd", "--", "--tribal-playtest-restart"]
		var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
		print("TRIBAL_PLAYTEST_STAGE: restart exit ", code)
		_expect(code == 0 and str(output).contains("TRIBAL_PLAYTEST_RESTART_PASSED"), "Cold resume failed: " + str(output))
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "Testing changed the original adventure.")
	await _finish()


func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	await flow.load_game(expected.path)
	await _until(func() -> bool:
		var tribe: Node = current_scene.get_node_or_null("Nest/Tribe")
		return not flow.loading and tribe != null and tribe.is_active(), 60000)
	var tribe: Node = current_scene.get_node_or_null("Nest/Tribe")
	_expect(tribe != null and tribe.is_active(), "Fresh process did not restore group control.")
	if tribe != null and tribe.is_active():
		flow.toggle_pause()
		_expect(state.current_phase == 1 and state.campaign.data.id == expected.campaign_id, "Cold resume replaced the campaign or phase.")
		_expect(tribe.actors.keys() == expected.resident_ids and tribe.home.actors.is_empty(), "Cold resume changed or duplicated residents.")
		_expect(tribe.village().stock.wood == expected.wood and state.campaign.data.completed_transitions == expected.transitions, "Cold resume lost stock or repeated the transition.")
		_expect(tribe.camera.current and not tribe.player.is_physics_processing(), "Cold resume lost tribal controls.")
	_expect(FileAccess.get_file_as_string(expected.original).sha256_text() == expected.original_hash, "Cold resume altered original save.")
	_expect(not flow.has_node("TribalPlaytestLauncher"), "Normal load reran test setup.")
	if failures.is_empty(): print("TRIBAL_PLAYTEST_RESTART_PASSED")


func _cancel_preparation() -> void:
	var launcher: Node = flow.get_node_or_null("TribalPlaytestLauncher")
	_expect(launcher != null and current_scene.player.process_mode == Node.PROCESS_MODE_DISABLED,
		"Preparation did not acquire player control.")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)


func _until(predicate: Callable, milliseconds: int) -> void:
	var deadline: int = Time.get_ticks_msec() + milliseconds
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await physics_frame
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _finish() -> void:
	paused = false
	for failure: String in failures: push_error(failure)
	print(JSON.stringify({"test": "tribal_playtest", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
