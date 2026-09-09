extends Node

## Run with isolated user storage; uses real menus and gameplay scenes.
var failures: Array[String] = []
var captures: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	captures = "--frontend-capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	var tree := get_tree()
	var flow := get_node("/root/SessionFlow")
	var saves := get_node("/root/SaveGameService")
	var settings := get_node("/root/DisplaySettings")
	await _frames(4)
	_expect(tree.current_scene.scene_file_path == flow.TITLE_SCENE, "Default entry is not the Voxelverse title.")
	_expect(not saves.session_active and tree.get_first_node_in_group(&"player") == null, "Title has an active campaign/player.")
	var before: Array = saves.list_slots()
	saves._process(999.0)
	_expect(saves.list_slots() == before, "Idling in the menu wrote a save.")
	_expect(not FileAccess.file_exists(saves.DEFAULT_SAVE_PATH), "Title boot wrote the legacy save.")
	await _capture("title")
	_click(tree.current_scene.find_child("Settings", true, false))
	await _frames(2)
	_expect(settings.is_menu_open() and tree.paused, "Title settings did not open.")
	var old_vsync: bool = settings.vsync_enabled
	_click(settings._vsync_option)
	_click(settings._menu_panel.find_child("Apply", true, false))
	await _frames(2)
	_expect(settings.vsync_enabled != old_vsync, "Real settings clicks were ignored.")
	await _capture("settings")
	await _exercise_controls(settings)
	_key(KEY_ESCAPE)
	await _frames(2)
	_expect(not tree.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Title settings captured the cursor or retained pause.")
	_click(tree.current_scene.find_child("NewGame", true, false))
	await _frames(2)
	tree.current_scene.find_child("AdventureName", true, false).text = "Erste Schritte"
	tree.current_scene.find_child("WorldSeed", true, false).text = "invalid"
	_click(tree.current_scene.find_child("Begin", true, false))
	await _frames(2)
	_expect(not flow.loading and tree.current_scene._status.text.contains("Welt-Seed"), "Invalid seed started or produced no feedback.")
	var seed_input: LineEdit = tree.current_scene.find_child("WorldSeed", true, false)
	seed_input.select_all()
	for character in "15838":
		var typed := InputEventKey.new()
		typed.unicode = character.unicode_at(0)
		typed.pressed = true
		get_viewport().push_input(typed, true)
		typed = typed.duplicate()
		typed.pressed = false
		get_viewport().push_input(typed, true)
	await _frames(2)
	_expect(seed_input.text == "15838" and tree.current_scene._status.text.is_empty(), "Corrected seed kept stale validation feedback.")
	await _capture("new_game")
	_click(tree.current_scene.find_child("Begin", true, false))
	await flow.world_started
	await _frames(8)
	var first_path: String = saves.save_path
	var first_id: String = get_node("/root/GameState").campaign.data.id
	_expect(int(get_node("/root/GameState").world_seed) == 15838, "Requested seed was not used.")
	_expect(tree.get_first_node_in_group(&"player") != null, "No player after loading.")
	var player: Node = tree.get_first_node_in_group(&"player")
	_key(KEY_R)
	_expect(player.inspection_mode_enabled, "Remapped inspection key did not reach the player.")
	_key(KEY_R)
	_key(KEY_E)
	_expect(not player.inspection_mode_enabled, "Old inspection key still toggled the player.")
	# The headless display server cannot capture the cursor. The real render
	# acceptance checks the full input path; preferences_test covers the math.
	if DisplayServer.get_name() != "headless":
		var old_rotation: Vector3 = player.camera_pivot.rotation
		var motion := InputEventMouseMotion.new()
		motion.screen_relative = Vector2(8, 4)
		motion.relative = Vector2(8, 4)
		get_viewport().push_input(motion, true)
		_expect(is_equal_approx(player.camera_pivot.rotation.y - old_rotation.y, -8.0 * player.mouse_sensitivity * 1.5) and is_equal_approx(player.camera_pivot.rotation.x - old_rotation.x, 4.0 * player.mouse_sensitivity * 1.5), "Player camera did not use the saved sensitivity/inversion: %s -> %s; mouse mode %d." % [old_rotation, player.camera_pivot.rotation, Input.mouse_mode])
	await _exercise_first_steps(player)
	_expect(saves.save_now(), "In-game save failed.")
	await _frames(2)
	_expect(flow.get_node("SaveFeedback").visible and flow.get_node("SaveFeedback")._label.text.contains("Gespeichert"), "In-game save confirmation was not visible.")
	await _capture("save_status")
	_key(KEY_ESCAPE)
	await _frames(2)
	_expect(flow.pause_open and tree.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc did not pause the world.")
	var elapsed: float = get_node("/root/GameState").campaign.data.elapsed_seconds
	await _frames(5)
	_expect(get_node("/root/GameState").campaign.data.elapsed_seconds == elapsed, "Campaign advanced while paused.")
	await _capture("pause")
	_click(flow._overlay.find_child("PauseSettings", true, false))
	await _frames(2)
	_key(KEY_ESCAPE)
	await _frames(2)
	_expect(tree.paused and flow.pause_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Settings close resumed underneath pause.")
	saves.record_design("user://building_designs/frontend_sentinel.json", '{"name":"First campaign only"}')
	_click(flow._overlay.find_child("SaveGame", true, false))
	await _frames(2)
	_expect(flow._message.text == "Spielstand gespeichert.", "Save success was not visible.")
	_expect(flow.get_node("SaveFeedback")._label.text.contains("Gespeichert"), "Save status did not reflect the committed snapshot.")
	saves.save_path = "user://missing-frontend-directory/save.json"
	_click(flow._overlay.find_child("ReturnToTitle", true, false))
	await _frames(2)
	_expect(tree.current_scene.scene_file_path == flow.WORLD_SCENE and flow.pause_open, "Failed save left the running world.")
	_expect(flow._message.text.contains("fehlgeschlagen"), "Failed save was not explained.")
	saves.save_path = first_path
	_click(flow._overlay.find_child("ReturnToTitle", true, false))
	await tree.scene_changed
	await _frames(3)
	_expect(tree.get_first_node_in_group(&"player") == null and tree.get_nodes_in_group(&"world_manager").is_empty(), "Return to title retained a world/player.")
	_expect(not tree.paused and not saves.session_active, "Return to title retained an active/paused campaign.")
	var first_bytes: String = FileAccess.get_file_as_string(first_path)
	flow.new_game("Zweite Welt", 23757)
	await flow.world_started
	await _frames(8)
	var second_path: String = saves.save_path
	_expect(second_path != first_path and get_node("/root/GameState").campaign.data.id != first_id, "New game reused campaign identity/path.")
	_expect(not saves._design_files.has("user://building_designs/frontend_sentinel.json"), "New campaign inherited another campaign's design.")
	_expect(FileAccess.get_file_as_string(first_path) == first_bytes, "New game overwrote the previous save.")
	flow.toggle_pause()
	flow.return_to_title()
	await tree.scene_changed
	await _frames(3)
	_click(tree.current_scene.find_child("Saves", true, false))
	await _frames(3)
	await _capture("save_slots")
	await _exercise_save_browser(first_path)
	flow.load_game(first_path)
	await flow.world_started
	_expect(get_node("/root/GameState").campaign.data.id == first_id and int(get_node("/root/GameState").world_seed) == 15838, "Loading did not restore the first campaign.")
	_expect(saves._design_files.has("user://building_designs/frontend_sentinel.json"), "Loading lost the design snapshot.")
	flow.toggle_pause()
	flow.return_to_title()
	await tree.scene_changed
	await _frames(3)
	var original: String = FileAccess.get_file_as_string(first_path)
	var file := FileAccess.open(first_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var recovered: Dictionary = saves.inspect_slot(first_path)
	_expect(recovered.valid and recovered.recovered, "Backup-only recovery is not offered.")
	var newer: Dictionary = JSON.parse_string(original)
	newer.schema = 999
	file = FileAccess.open(first_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(newer))
	file.close()
	_expect(not saves.inspect_slot(first_path).valid, "Future save was silently downgraded to backup.")
	var future_bytes: String = FileAccess.get_file_as_string(first_path)
	saves._process(999.0)
	_expect(FileAccess.get_file_as_string(first_path) == future_bytes, "Title autosave overwrote a future save.")
	file = FileAccess.open(first_path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("FRONTEND_PASSED: title, settings, seed validation, loading, first-steps actions/help/skip/restart, pause nesting, save status, failed save retention, world teardown, campaign isolation, thumbnails, rename, independent copies, selected history recovery, reload and backup/version handling.")
	tree.quit(0 if failures.is_empty() else 1)

func _exercise_first_steps(player: Node) -> void:
	var flow: Node = get_node("/root/SessionFlow")
	var saves: Node = get_node("/root/SaveGameService")
	var guide: Node = flow.get_node("FirstSteps")
	_expect(guide.visible and saves.guidance.current_step() == "look", "Fresh adventure did not show the first-steps card.")
	_expect(guide.hint("move").contains("Pfeil ↑"), "Guide did not display the remapped movement key.")
	_expect(guide.hint("inspect").contains("R"), "Guide did not display the remapped inspection key.")
	await _capture("first_steps")
	_key(KEY_ESCAPE)
	await _frames(2)
	_click(flow._overlay.find_child("PauseFirstSteps", true, false))
	await _frames(2)
	var paused_progress: Dictionary = saves.guidance.export_state()
	player.guidance_action.emit("move", 50.0)
	_expect(not guide.visible and saves.guidance.export_state() == paused_progress, "Paused play advanced or showed the guide.")
	await _capture("first_steps_help")
	_click(flow._overlay.find_child("SkipFirstSteps", true, false))
	await _frames(2)
	_expect(not flow.pause_open and not guide.visible and bool(saves.guidance.data.skipped), "Skip did not resume and hide the introduction.")
	await _restart_first_steps(flow)
	_expect(guide.visible and saves.guidance.completed_count() == 0, "Restart did not reset only the introduction.")
	var home_position: Vector3 = player.global_position
	var home_camera: Vector3 = player.camera_pivot.rotation
	# An invisible physics fixture makes movement/jump acceptance independent
	# of terrain streaming and the procedural shoreline around the spawn.
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	ground.add_child(shape)
	get_tree().current_scene.add_child(ground)
	var water: float = get_node("/root/WorldGenerator").get_water_level(home_position.x, home_position.z)
	ground.global_position = Vector3(home_position.x, maxf(home_position.y + 1.0, water + 4.0), home_position.z)
	player.global_position = ground.global_position + Vector3(0, 1.5, 0)
	player.velocity = Vector3.ZERO
	if DisplayServer.get_name() != "headless":
		var motion := InputEventMouseMotion.new()
		motion.screen_relative = Vector2(190, 0)
		motion.relative = motion.screen_relative
		get_viewport().push_input(motion, true)
		_expect(saves.guidance.done("look"), "Actual camera movement did not complete looking around.")
	for frame in range(240):
		if player.is_on_floor():
			break
		await get_tree().physics_frame
	_expect(saves.guidance.amount("move") == 0.0 and not saves.guidance.done("jump"), "Falling/landing completed walking or jumping.")
	_hold_key(KEY_UP, true)
	for frame in range(120):
		await get_tree().physics_frame
		if saves.guidance.done("move"):
			break
	_hold_key(KEY_UP, false)
	_expect(saves.guidance.done("move"), "Real movement on the remapped key did not complete walking.")
	for frame in range(180):
		if player.is_on_floor():
			break
		await get_tree().physics_frame
	await _frames(2)
	await _capture("first_steps_jump")
	_hold_key(KEY_SPACE, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_hold_key(KEY_SPACE, false)
	_expect(saves.guidance.done("jump"), "A real grounded jump did not complete the jump task.")
	var radius: float = player.inspection_radius
	player.inspection_radius = 0.01
	_key(KEY_R)
	await _frames(2)
	_expect(not saves.guidance.done("inspect"), "Opening an empty inspection completed the creature task.")
	player.inspection_radius = radius
	# Aim the real gameplay camera at an actual animal and hold it through
	# the real physics-driven timer. A proximity fixture is insufficient.
	for frame in range(180):
		if player.is_on_floor():
			break
		await get_tree().physics_frame
	var creature: Node3D
	for frame in range(180):
		creature = get_tree().get_first_node_in_group(&"wildlife") as Node3D
		if creature != null:
			break
		await get_tree().physics_frame
	_expect(creature != null, "No real wildlife available for scanning.")
	if creature != null:
		var creature_home: Vector3 = creature.global_position
		creature.set_physics_process(false)
		creature.global_position = player.global_position + Vector3(0, 0, -4)
		await _frames(3)
		player._gameplay_camera.look_at(creature.global_position + Vector3(0, 0.56, 0))
		var scanner: Node = player.get_node("CreatureScanner")
		for frame in range(180):
			await get_tree().physics_frame
			if scanner.ratio() >= 0.4:
				break
		_expect(scanner.target == creature and scanner.ratio() >= 0.4 and not scanner.known, "Sustained aimed scan did not show partial progress.")
		_expect(not player.get_node("HUD/CreatureInspectionPanel").visible and not saves.guidance.done("inspect"), "Unknown species exposed stats or completed the introduction early.")
		await _capture("scan_progress")
		for frame in range(180):
			await get_tree().physics_frame
			if scanner.known:
				break
		await _frames(2)
		_expect(scanner.known and player.get_node("HUD/CreatureInspectionPanel").visible and saves.guidance.done("inspect"), "Completed scan did not unlock stats, book and introduction.")
		await _capture("scan_known")
		await _capture("first_steps_complete")
		_key(KEY_J)
		await _frames(3)
		var journal: Node = get_tree().get_first_node_in_group(&"discovery_journal")
		_expect(journal != null and journal.is_open and journal._list.item_count > 0 and get_tree().paused, "J did not open the populated discovery book.")
		await _capture("scan_journal")
		_key(KEY_ESCAPE)
		await _frames(3)
		_expect(not get_tree().paused and scanner.known, "Closing the book did not immediately recognize the known animal.")
		creature.global_position = creature_home
		creature.set_physics_process(true)
	ground.queue_free()
	player.global_position = home_position
	player.velocity = Vector3.ZERO
	player.camera_pivot.rotation = home_camera
	player._gameplay_camera.rotation = Vector3.ZERO
	_key(KEY_R)
	await _restart_first_steps(flow)

func _restart_first_steps(flow: Node) -> void:
	_key(KEY_ESCAPE)
	await _frames(2)
	_click(flow._overlay.find_child("PauseFirstSteps", true, false))
	await _frames(2)
	_click(flow._overlay.find_child("RestartFirstSteps", true, false))
	await _frames(2)

func _hold_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _exercise_save_browser(original: String) -> void:
	var tree := get_tree()
	var saves: Node = get_node("/root/SaveGameService")
	var flow: Node = get_node("/root/SessionFlow")
	var browser: Node = tree.current_scene.get_node("SaveBrowser")
	for button: Button in browser._list.get_children():
		if str(button.get_meta("slot_path")) == original:
			browser._list.get_parent().ensure_control_visible(button)
			await _frames(2)
			_click(button)
			break
	await _frames(2)
	_expect(browser.selected_path == original, "Slot card selected the wrong adventure.")
	if DisplayServer.get_name() != "headless":
		_expect(not saves.inspect_slot(original).preview.is_empty(), "Rendered gameplay did not create a stored thumbnail.")
	browser._name_input.text = "Erste Schritte – Basis"
	var rename: Button = browser.find_child("RenameSlot", true, false)
	browser._details.get_parent().ensure_control_visible(rename)
	await _frames(2)
	_click(rename)
	await _frames(2)
	_expect(saves.inspect_slot(original).name == "Erste Schritte – Basis", "Rename button did not update the selected slot.")
	var original_bytes: String = FileAccess.get_file_as_string(original)
	var copy: Button = browser.find_child("CopySlot", true, false)
	browser._details.get_parent().ensure_control_visible(copy)
	await _frames(2)
	_click(copy)
	await _frames(2)
	var copied: String = browser.selected_path
	_expect(copied != original and FileAccess.get_file_as_string(original) == original_bytes, "Copy button altered the original slot.")
	await _capture("save_copy")
	var play: Button = browser.find_child("LoadAdventure", true, false)
	browser._details.get_parent().ensure_control_visible(play)
	await _frames(2)
	_click(play)
	await flow.world_started
	await _frames(8)
	_expect(saves.save_path == copied, "Load button did not start the selected copied campaign.")
	saves.record_design("user://building_designs/copy_only.json", '{"name":"Copy only"}')
	flow.toggle_pause()
	flow.return_to_title()
	await tree.scene_changed
	await _frames(3)
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "Playing the copied adventure changed the original.")
	_click(tree.current_scene.find_child("Saves", true, false))
	await _frames(3)
	browser = tree.current_scene.get_node("SaveBrowser")
	browser.select_slot(original)
	await _frames(2)
	var source: String = browser._entries[0].source
	var source_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var restore: Button = browser.find_child("RestoreSlot", true, false)
	browser._details.get_parent().ensure_control_visible(restore)
	await _frames(3)
	await _capture("save_history")
	_click(restore)
	await _frames(3)
	_expect(browser.selected_path not in [original, copied], "Restore button did not select a new adventure.")
	var restored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(browser.selected_path))
	_expect(restored.design_files == source_data.design_files and is_equal_approx(float(restored.game_state.campaign.elapsed_seconds), float(source_data.game_state.campaign.elapsed_seconds)), "Restore button used the wrong snapshot.")
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "Restore button overwrote the original adventure.")
	_key(KEY_ESCAPE)
	await _frames(2)
	_expect(tree.current_scene._page == "home" and not tree.paused, "Esc did not leave the save browser cleanly.")

func _exercise_controls(settings: Node) -> void:
	var panel: Node = settings._control_settings
	var bar: TabBar = settings._tabs.get_tab_bar()
	_click_position(bar.global_position + bar.get_tab_rect(1).get_center())
	await _frames(2)
	_expect(settings._tabs.current_tab == 1, "Real click did not select the controls tab.")
	var slider: HSlider = panel.sensitivity
	slider.grab_focus()
	for step in range(10):
		_key(KEY_RIGHT)
	_click(panel.invert_y)
	panel.fps.select(panel.fps.get_item_index(120))
	await _capture("controls")
	var scroll: ScrollContainer = panel.get_parent()
	var bind: Button = panel.find_child("Bind_move_forward_0", true, false)
	scroll.ensure_control_visible(bind)
	await _frames(2)
	_click(bind)
	_key(KEY_S)
	_expect(panel.listening_action == "move_forward" and panel.message.text.contains("bereits"), "Conflicting key was not rejected in the UI.")
	_key(KEY_ESCAPE)
	_expect(settings.is_menu_open() and get_tree().paused and panel.listening_action.is_empty(), "Escape during capture closed the settings.")
	_click(bind)
	_key(KEY_UP)
	_expect(panel.draft.move_forward[0] == KEY_UP and settings.input_preferences.bindings.move_forward[0] == KEY_W, "Draft key changed the live binding before Apply.")
	bind = panel.find_child("Bind_inspection_mode_0", true, false)
	scroll.ensure_control_visible(bind)
	await _frames(2)
	_click(bind)
	_key(KEY_J)
	_expect(panel.listening_action == "inspection_mode", "Reserved journal key was accepted.")
	_key(KEY_R)
	await _capture("bindings")
	_click(settings._menu_panel.find_child("Apply", true, false))
	await _frames(2)
	_expect(is_equal_approx(settings.input_preferences.sensitivity, 1.5) and settings.input_preferences.invert_y and Engine.max_fps == 120, "GUI camera and FPS settings were not applied.")
	var loaded = load("res://core/input_preferences.gd").new()
	loaded.load_saved()
	_expect(loaded.bindings.inspection_mode[0] == KEY_R and loaded.bindings.move_forward[0] == KEY_UP, "GUI remapping was not persisted.")
	_expect(get_node("/root/SessionFlow").controls_text().contains("R   Scanmodus"), "Help still showed the old binding.")
	# Unsaved reset is discarded on close; confirmed reset must update InputMap.
	var reset: Button = panel.find_child("ResetControls", true, false)
	scroll.ensure_control_visible(reset)
	await _frames(2)
	_click(reset)
	settings.close_menu()
	settings.open_menu()
	_expect(panel.draft.inspection_mode[0] == KEY_R, "Closing settings persisted a draft reset.")
	settings._tabs.current_tab = 1
	scroll.ensure_control_visible(reset)
	await _frames(2)
	_click(reset)
	_click(settings._menu_panel.find_child("Apply", true, false))
	_expect(settings.input_preferences.bindings.inspection_mode[0] == KEY_E and Engine.max_fps == 0, "Confirmed defaults did not restore the original bindings/cap.")
	# Restore the tested settings for the subsequent real-player acceptance.
	var saved: Dictionary = loaded.bindings.duplicate(true)
	_expect(settings.input_preferences.save_and_apply(saved, 1.5, true, 120).is_empty(), "Could not restore the test preferences.")
	panel.refresh()

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _capture(filename: String) -> void:
	if not captures or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var dir: String = OS.get_environment("VOXELVERSE_CAPTURE_DIR")
	if dir.is_empty():
		dir = "user://frontend_captures"
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(filename + ".png"))

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)

func _click(control: Control) -> void:
	if control == null:
		_expect(false, "Missing frontend control.")
		return
	var point: Vector2 = control.get_global_rect().get_center()
	_click_position(point)

func _click_position(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
