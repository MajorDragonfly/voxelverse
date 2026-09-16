extends "world_map_test.gd"
## Real Controls and Viewport events; legacy profiles and fresh-engine restart.
const Keys = preload("res://core/input_preferences.gd")
var checks: int = 0
var settings: Node
var journal: CanvasLayer
var skills: CanvasLayer

func _run() -> void:
	settings = root.get_node("DisplaySettings")
	if "--menu-rebind-restart" in OS.get_cmdline_user_args():
		var prefs: RefCounted = settings.input_preferences
		_expect(prefs.bindings.open_journal == [KEY_L, KEY_3] and prefs.bindings.open_development == [KEY_B, KEY_4] and prefs.bindings.open_world_map == [KEY_O, KEY_2], "Fresh engine lost menu bindings")
		_expect(Keys.binding_label("open_world_map") == "O / 2", "Fresh engine did not apply InputMap")
		print("MENU_REBIND_RESTART_OK" if failures.is_empty() else "MENU_REBIND_RESTART_FAILED")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
		return
	root.get_node("LocaleManager")._apply("de")
	root.size = Vector2i(1280, 720)
	_test_profiles()
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://menu-rebind-campaign.json"
	state = root.get_node("GameState")
	state.start_world_with_seed(15838)
	state.set_process(false)
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	player = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	player.fall_acceleration = 0
	scene.add_child(player)
	await _frames(5)
	map = get_first_node_in_group(&"world_map")
	journal = get_first_node_in_group(&"discovery_journal")
	skills = player.find_child("PlayerProgression", true, false)
	_expect(map != null and journal != null and skills != null, "Player did not install all three menus")
	if map == null or journal == null or skills == null: await _finish(); return
	await _settings_route()
	await _menu_route()
	await _hints()
	# Saving preferences must be isolated from the campaign save and its data.
	_expect(not FileAccess.file_exists(saves.save_path), "Changing shortcuts wrote a campaign")
	settings.input_preferences.bindings = Keys.defaults()
	settings.input_preferences.apply_runtime()
	print("MENU_REBIND_CHECKS: ", checks)
	await _finish()

func _test_profiles() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("bindings", "move_forward", [KEY_M, KEY_UP])
	legacy.set_value("bindings", "inspection_mode", [KEY_R, 0])
	legacy.set_value("camera", "sensitivity", 1.75)
	legacy.set_value("camera", "invert_y", true)
	legacy.set_value("display", "fps_limit", 144)
	var path := "user://menu-legacy.cfg"
	_expect(legacy.save(path) == OK, "Cannot create legacy preference fixture")
	var original := FileAccess.get_file_as_string(path)
	var prefs := Keys.new()
	prefs.load_saved(path)
	_expect(prefs.bindings.move_forward == [KEY_M, KEY_UP] and prefs.bindings.inspection_mode == [KEY_R, 0], "Migration discarded old game bindings")
	_expect(prefs.bindings.open_world_map[0] != KEY_M and not prefs.load_message.is_empty(), "Legacy M collision was not explained and resolved")
	_expect(Keys.validate(prefs.bindings).is_empty(), "Migrated profile contains a duplicate or invalid binding")
	_expect(prefs.sensitivity == 1.75 and prefs.invert_y and prefs.fps_limit == 144, "Migration reset comfort settings")
	_expect(FileAccess.get_file_as_string(path) == original, "Reading preferences rewrote the old profile")
	var migrated := prefs.bindings.duplicate(true)
	prefs.load_saved(path)
	_expect(prefs.bindings == migrated, "Legacy migration chose nondeterministic shortcuts")
	var candidate := Keys.defaults()
	candidate.open_journal = [KEY_L, KEY_3]
	candidate.open_development = [KEY_B, KEY_4]
	candidate.open_world_map = [KEY_O, KEY_2]
	candidate.jump = [KEY_J, KEY_K]
	candidate.move_forward = [KEY_M, 0]
	_expect(Keys.validate(candidate).is_empty(), "Former menu keys cannot be reused for game actions")
	_expect(prefs.save_and_apply(candidate, 1.0, false, 0, path).is_empty(), "Cannot save remapped profile")
	var saved := FileAccess.get_file_as_string(path)
	for code: int in [KEY_S, KEY_L, KEY_3, KEY_F, KEY_H, KEY_N, KEY_P, KEY_UP, KEY_SPACE, KEY_F8, -8]:
		var invalid := candidate.duplicate(true)
		invalid.open_world_map = [code, 0]
		_expect(not prefs.save_and_apply(invalid, 1.0, false, 0, path).is_empty(), "Invalid or conflicting menu key accepted: " + str(code))
	_expect(not prefs.save_and_apply(candidate, 1.5, true, 60, "user://missing-menu-dir/input.cfg").is_empty(), "Failed write reported success")
	_expect(prefs.bindings == candidate and prefs.sensitivity == 1.0 and FileAccess.get_file_as_string(path) == saved, "Rejected write changed file or active settings")
	settings.input_preferences.bindings = Keys.defaults()
	settings.input_preferences.apply_runtime()

func _settings_route() -> void:
	settings.open_menu()
	settings._tabs.current_tab = 1
	var controls: Node = settings._control_settings
	await _frames(3)
	# Existing and new shortcuts must remain capturable while settings own pause.
	await _bind("open_development", 0, KEY_B)
	await _bind("open_development", 1, KEY_4)
	await _bind("open_journal", 0, KEY_L)
	await _bind("open_journal", 1, KEY_3)
	await _bind("open_world_map", 0, KEY_O)
	await _bind("open_world_map", 1, KEY_2)
	_expect(Keys.binding_label("open_world_map") == "M", "Draft edits changed live InputMap before Apply")
	_expect(settings.is_menu_open() and paused and not skills.visible and not journal.is_open and not map.is_open, "Capturing shortcuts opened another menu")
	await _click(settings._menu_panel.find_child("Apply", true, false))
	_expect(Keys.binding_label("open_world_map") == "O / 2", "Apply did not activate both menu shortcuts")
	var persisted := FileAccess.get_file_as_string(Keys.CONFIG_PATH)
	# A draft reset must not save itself when settings are dismissed.
	var reset: Button = controls.find_child("ResetControls", true, false)
	controls.get_parent().ensure_control_visible(reset)
	await _frames(3)
	await _click(reset)
	_expect(controls.draft == Keys.defaults(), "Reset button did not reset the menu draft")
	settings.close_menu()
	await _frames(3)
	_expect(Keys.binding_label("open_world_map") == "O / 2" and FileAccess.get_file_as_string(Keys.CONFIG_PATH) == persisted, "Dismissed draft reset changed active/saved bindings")
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/menu_rebinding_test.gd", "--", "--menu-rebind-restart"], output, true)
	_expect(code == 0 and str(output).contains("MENU_REBIND_RESTART_OK") and not str(output).contains("ERROR:"), "Fresh engine failed: " + str(output).right(1200))

func _bind(action: String, slot: int, key: int) -> void:
	var controls: Node = settings._control_settings
	var button: Button = controls.find_child("Bind_%s_%d" % [action, slot], true, false)
	controls.get_parent().ensure_control_visible(button)
	await _frames(3)
	await _click(button)
	_expect(controls.listening_action == action and controls.listening_slot == slot, "Real binding button click failed: " + button.name)
	await _key(key)
	_expect(controls.listening_action.is_empty() and controls.draft[action][slot] == key, "Key capture failed: " + button.name)

func _menu_route() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mouse_before := Input.mouse_mode
	for old: int in [KEY_J, KEY_K, KEY_M]:
		await _key(old)
		_expect(not paused and not map.is_open and not journal.is_open and not skills.visible, "Old shortcut still opens a menu")
	for modifier: String in ["ctrl_pressed", "alt_pressed", "meta_pressed", "shift_pressed"]:
		await _event_key(KEY_O, 0, modifier)
		_expect(not map.is_open and not paused, "Modified key opened a menu: " + modifier)
	await _event_key(KEY_B, 0, "", true)
	_expect(skills.visible and paused, "Physical-only development shortcut did not open")
	await _key(KEY_L)
	_expect(skills.visible and not journal.is_open and paused, "Journal stole another menu's pause")
	await _key(KEY_4)
	await _frames(2)
	_expect(not skills.visible and not paused, "Secondary development shortcut did not close")
	await _event_key(KEY_L, 0, "", false, true)
	_expect(journal.is_open and paused, "Logical-only journal shortcut did not open")
	journal._search.grab_focus()
	journal._search.clear()
	for code: int in [KEY_L, KEY_B, KEY_O]: await _event_key(code, code + 32)
	_expect(journal.is_open and journal._search.text == "lbo" and not skills.visible and not map.is_open, "Rebound menu letters escaped journal text input")
	journal._close.grab_focus()
	await _key(KEY_3)
	await _frames(2)
	_expect(not journal.is_open and not paused, "Secondary journal shortcut did not close")
	await _key(KEY_2)
	_expect(map.is_open and paused, "Secondary map shortcut did not open")
	map._show_list = true
	map._layout()
	map._place_search.grab_focus()
	map._place_search.clear()
	for code: int in [KEY_L, KEY_B, KEY_O]: await _event_key(code, code + 32)
	_expect(map.is_open and map._place_search.text == "lbo" and not skills.visible and not journal.is_open, "Rebound letters escaped atlas search input")
	await _key(KEY_ESCAPE)
	_expect(map.is_open and not map._place_search.has_focus(), "Escape did not first release atlas search focus")
	await _key(KEY_O)
	await _frames(3)
	_expect(not map.is_open and not paused and Input.mouse_mode == mouse_before, "Rebound map close lost mouse/pause ownership")
	await _key(KEY_B)
	await _key(KEY_ESCAPE)
	await _frames(3)
	_expect(not skills.visible and not paused, "Escape stopped closing a rebound menu")

func _hints() -> void:
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		await _frames(4)
		_expect(player.find_child("OpenPlayerProgression", true, false).text.ends_with("B / 4"), "Development HUD shortcut did not refresh")
		_expect(player.find_child("OpenDiscoveryJournal", true, false).text.ends_with("L / 3"), "Journal HUD shortcut did not refresh")
		_expect(skills._journal_tab.text.ends_with("L / 3"), "Development-to-journal shortcut is stale")
		_expect(map.shortcut_text() == "O / 2", "Minimap shortcut is stale")
		var help: String = root.get_node("SessionFlow").controls_text()
		_expect("L / 3" in help and "B / 4" in help and "O / 2" in help and not "{journal}" in help, "Help contains stale or untranslated shortcuts")
		_expect("L / 3" in Keys.hint("BIND_FIRST_SCAN") and "L / 3" in Keys.hint("BIND_SCAN_RECOGNIZED"), "Scan guidance is stale")
		journal.open_journal()
		journal._tabs.current_tab = 3
		await _frames(3)
		_expect("L / 3" in journal._guide.text and not "{journal}" in journal._guide.text, "Journal guide shortcut is stale")
		journal.close_journal()
		await _frames(3)

func _event_key(code: int, unicode_value: int = 0, modifier: String = "", physical_only: bool = false, logical_only: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = 0 if physical_only else code
		event.physical_keycode = 0 if logical_only else code
		event.unicode = unicode_value
		event.pressed = down
		if not modifier.is_empty(): event.set(modifier, true)
		root.push_input(event, true)
		await process_frame

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)
