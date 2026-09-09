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
