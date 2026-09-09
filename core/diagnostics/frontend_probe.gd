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
	await _frames(3)
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
		print("FRONTEND_PASSED: title, no idle save, actual settings clicks, seed validation, loading, pause nesting, failed save retention, world teardown, campaign isolation, reload and backup/version handling.")
	tree.quit(0 if failures.is_empty() else 1)

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
	_expect(get_node("/root/SessionFlow").controls_text().contains("R   Untersuchungsmodus"), "Help still showed the old binding.")
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
