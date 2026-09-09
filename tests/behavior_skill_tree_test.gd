extends SceneTree

const Event = preload("res://core/campaign/game_event.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const SAVE_PATH := "user://progression_ui_test.json"

class InputProbe extends Node:
	var actions: int = 0
	func _physics_process(_delta: float) -> void:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (Input.is_action_just_pressed("primary_action") or Input.is_action_just_pressed("jump")):
			actions += 1

var failures: Array[String] = []
var ui: CanvasLayer
var player: Node3D
var scene: Node3D
var progression: Node
var saves: Node
var state: Node
var probe: InputProbe


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves.save_path = SAVE_PATH
	saves._loaded_once = true
	progression = root.get_node("ProgressionService")
	state = root.get_node("GameState")
	state.start_world_with_seed(15838)
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	player = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	scene.add_child(player)
	probe = InputProbe.new()
	scene.add_child(probe)
	await _frames()
	ui = scene.find_child("PlayerProgression", true, false)
	_expect(ui != null, "Real player scene did not install progression UI.")
	if ui == null:
		_finish()
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var initial_mouse_mode: int = Input.mouse_mode
	await _key(KEY_K)
	_expect(ui.visible and paused, "K did not open and pause the game.")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Opening did not release the mouse.")
	_expect(ui._cards.size() == 6, "Not all six backend nodes are visible.")
	_expect(ui._purchase.disabled, "Empty wallet permits a purchase.")
	await _screenshot("skilltree_empty.png")
	var time_before: float = state.campaign.data["elapsed_seconds"]
	var position_before := player.position
	await _key(KEY_W)
	await _key(KEY_Q)
	for key in [KEY_F2, KEY_F4, KEY_F8, KEY_F10, KEY_P]:
		await _key(key)
	_expect(current_scene == scene and paused and ui.visible, "A world/editor/menu shortcut escaped the modal.")
	var display := root.get_node("DisplaySettings")
	_expect(not display._menu_layer.visible, "F8 opened a second menu under the skilltree.")
	_expect(player.position == position_before and float(state.campaign.data["elapsed_seconds"]) == time_before, "Player or campaign advanced while paused.")
	_expect(probe.actions == 0, "Gameplay consumed UI input.")
	for index in range(3):
		_reward("friend_%d" % index)
		_reward("conflict_%d" % index, true)
	await _frames()
	await _screenshot("skilltree_available.png")
	await _click(ui._cards["creature.social.support"]["button"])
	_expect(ui._purchase.disabled and ui._requirements.text.contains("Offenheit"), "Missing prerequisite is not explained.")
	await _click(ui._cards["creature.social.approach"]["button"])
	var before: Dictionary = progression.export_state()
	saves.save_path = "user://missing_ui_directory/save.json"
	await _click(ui._purchase)
	_expect(progression.export_state() == before, "UI save failure consumed points or kept purchase.")
	_expect(ui._message.text.contains("zurückgesetzt") and not ui._purchase.disabled, "Failed purchase cannot be understood or retried.")
	saves.save_path = SAVE_PATH
	await _click(ui._purchase)
	_expect(ui._message.text.contains("gespeichert"), "Successful mouse purchase did not confirm persisted success.")
	_expect(_wallet()["available"]["social"] == 7 and ui._purchase.disabled, "Purchase not reflected in wallet/button.")
	var checkpoint: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE_PATH))
	_expect(checkpoint.get("progression", {}).get("behavior", {}).get("purchased_nodes", {}).has("creature.social.approach"), "Displayed success is not in the saved snapshot.")
	# Keyboard selection and activation, using the same GUI event dispatch.
	ui._cards["creature.social.support"]["button"].grab_focus()
	await _key(KEY_ENTER)
	ui._purchase.grab_focus()
	await _key(KEY_ENTER)
	_expect(_wallet()["available"]["social"] == 4, "Keyboard purchase did not work.")
	for id in ["creature.aggression.hunter", "creature.aggression.endurance", "creature.aggression.legacy"]:
		await _click(ui._cards[id]["button"])
		await _click(ui._purchase)
	_expect(_wallet()["available"]["aggression"] == 0, "Aggression purchases affected wrong wallet or failed.")
	# Exercise the existing late-creature-purchase contract without a phase rewrite.
	state.current_phase = 1
	state.phase_changed.emit(1)
	await _click(ui._cards["creature.social.legacy"]["button"])
	await _click(ui._purchase)
	_expect(_wallet()["available"]["social"] == 0 and ui._phase_label.text.contains("Stamm"), "Late legacy purchase or phase refresh failed.")
	_expect(ui._effect.text.contains("dieser Phase"), "Late legacy timing is not explained.")
	# Return fixture to a serializable normal campaign phase; transitions are tested in M2A.
	state.current_phase = 0
	state.phase_changed.emit(0)
	_expect(saves.save_now(), "Could not save UI fixture.")
	progression.reset_for_new_game()
	_expect(ui._wallet_labels["social"].text.begins_with("0 Punkte"), "Reset did not refresh open view.")
	_expect(saves.load_now(), "Could not reload UI purchases.")
	_expect(ui._purchase.disabled and ui._purchase.text == "Freigeschaltet", "Reload did not refresh selected purchase.")
	await _journal_checks()
	await _capture_if_requested()
	await _key(KEY_ESCAPE)
	_expect(not paused and not ui.visible and Input.mouse_mode == initial_mouse_mode, "Escape did not restore gameplay/mouse: pause=%s visible=%s mouse=%s prior=%s." % [paused, ui.visible, Input.mouse_mode, ui._previous_mouse_mode])
	_expect(probe.actions == 0, "Closing leaked a gameplay action.")
	# Another menu owns the pause: progression must not steal or release it.
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_expect(not ui.open_panel() and paused, "Progression stole an existing pause.")
	paused = false
	await _click(scene.find_child("OpenPlayerProgression", true, false))
	_expect(ui.visible, "HUD button did not open the panel with a free cursor.")
	await _click(ui._close)
	_expect(not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "HUD close did not restore prior free cursor.")
	# Unloading an open scene must release its owned pause.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.open_panel()
	scene.queue_free()
	await _frames()
	_expect(not paused, "Unloading the scene stranded the global pause.")
	_finish()


func _journal_checks() -> void:
	progression.discovered_species["ui_fixture"] = {"name": "Kieselrücken", "role": "grazer", "world_seed": 15838}
	progression.discovered_regions["ui_region"] = {"world_seed": 15838, "x": -2, "z": 7}
	ui._refresh_journal()
	await _click(ui._journal_tab)
	var journal: VBoxContainer = ui._journal
	journal._search.grab_focus()
	await _key(KEY_K, 107)
	_expect(ui.visible and journal._search.text.to_lower() == "k", "K closed the modal while typing a search.")
	_expect(journal._entries.get_child_count() == 1, "Journal search did not filter saved species.")
	journal._search.text = "no-result"
	journal._search.text_changed.emit("no-result")
	_expect(journal._entries.get_child(0).text.contains("Keine passenden"), "Search has no clear empty state.")
	journal._search.clear()
	journal._search.text_changed.emit("")
	journal._category.select(1)
	journal._category.item_selected.emit(1)
	_expect(journal._records[0]["title"] == "Region -2 / 7", "Region coordinates are not from the saved discovery.")
	journal._category.select(2)
	journal._category.item_selected.emit(2)
	_expect(journal._records.size() == progression.get_unlocked_count(), "Journal does not reflect actual unlocked parts.")
	for index in range(70):
		progression.discovered_species["page_%d" % index] = {"name": "Testart %d" % index, "role": "unknown", "world_seed": 15838}
	journal._category.select(0)
	journal._category.item_selected.emit(0)
	_expect(journal._entries.get_child_count() == 30 and not journal._next.disabled, "Large journal is not paginated.")
	journal._next.pressed.emit()
	_expect(journal._page == 1 and journal._entries.get_child_count() == 30, "Journal page advance failed.")
	for index in range(70):
		progression.discovered_species.erase("page_%d" % index)
	journal.refresh()
	progression.reset_for_new_game()
	_expect(journal._records.is_empty(), "New game left old discoveries visible in the journal.")
	_expect(saves.load_now(), "Could not restore journal fixture after reset.")
	progression.discovered_species["ui_fixture"] = {"name": "Kieselrücken", "role": "grazer", "world_seed": 15838}
	journal.refresh()
	await _click(ui._tree_tab)


func _capture_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--capture" in args:
		return
	var directory: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for size_value in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(800, 900)]:
		root.content_scale_size = Vector2i.ZERO
		root.content_scale_factor = 1.0
		root.size = size_value
		await _frames()
		ui._layout()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("skilltree_%dx%d.png" % [size_value.x, size_value.y]))
	root.size = Vector2i(1600, 900)
	await _frames()
	ui._show_tab(true)
	await _frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("journal.png"))


func _screenshot(filename: String) -> void:
	var args := OS.get_cmdline_user_args()
	if not "--capture" in args:
		return
	var directory: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(filename))


func _reward(target: String, aggressive: bool = false) -> void:
	var event = state.campaign.next_event(Event.Kind.CONFLICT_RESULT if aggressive else Event.Kind.INTERACTION, target, 0, "won" if aggressive else "befriended")
	event.encounter_id = "ui_encounter_" + target
	event.behavior_context = {"target_relation": "hostile" if aggressive else "neutral", "conflict_reason": "self_defense"}
	_expect(state.record_campaign_event(event), "Fixture event rejected.")


func _wallet() -> Dictionary:
	return progression.get_behavior_wallet(0)


func _click(control: Control) -> void:
	_expect(control.is_visible_in_tree(), "Attempted click on hidden control.")
	if ui._scroll.is_ancestor_of(control):
		ui._scroll.ensure_control_visible(control)
	await _frames()
	var position: Vector2 = control.get_global_rect().get_center()
	for pressed_value in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed_value
		root.push_input(event, true)
		await process_frame
	await _frames()


func _key(code: int, unicode_value: int = 0) -> void:
	for pressed_value in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode_value
		event.pressed = pressed_value
		Input.parse_input_event(event)
		await process_frame
	await _frames()


func _frames() -> void:
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PROGRESSION_UI_OK: GUI mouse/keyboard, owned pause, purchases, rollback, reload, phases, journal and teardown")
	else:
		for message in failures:
			push_error(message)
	quit(0 if failures.is_empty() else 1)
