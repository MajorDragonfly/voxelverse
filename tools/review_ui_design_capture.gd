extends SceneTree
## Bounded visual review of the real frontend. No generated campaign or save fixtures.
## Use a fresh XDG_DATA_HOME, --isolated-review and optionally --capture.
## VOXELVERSE_CAPTURE_DIR selects the screenshot directory. The same helper works
## on the original UI: new design resources are deliberately not preloaded here.

var failures: Array[String] = []
var captures: Array[Dictionary] = []
var checks: int = 0
var output_dir: String = ""
var capture_enabled: bool = false
var locale_id: String = "de"
var review_size := Vector2i(1280, 720)
var settings: Node
var saves: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	output_dir = OS.get_environment("VOXELVERSE_CAPTURE_DIR")
	if output_dir.is_empty(): output_dir = "user://ui_design_review"
	var data_root := OS.get_environment("XDG_DATA_HOME").trim_suffix("/")
	var user_path := OS.get_user_data_dir()
	if "--isolated-review" not in OS.get_cmdline_user_args() or data_root.is_empty() or not user_path.begins_with(data_root + "/"):
		push_error("UI_DESIGN_REVIEW requires --isolated-review and a fresh explicit XDG_DATA_HOME containing the Godot user directory.")
		quit(2)
		return
	if capture_enabled and DisplayServer.get_name() == "headless":
		push_error("UI_DESIGN_REVIEW --capture requires a real rendering display server.")
		quit(2)
		return
	settings = root.get_node("DisplaySettings")
	saves = root.get_node("SaveGameService")
	root.get_node("SessionFlow").enter_frontend()
	root.get_node("GameState").set_process(false)
	if not saves.list_slots().is_empty():
		push_error("UI_DESIGN_REVIEW needs fresh empty isolated storage; existing saves are left untouched.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for language: String in ["de", "en"]:
			review_size = extent
			locale_id = language
			await _review_frontend()
	_write_manifest()
	for failure: String in failures: push_error(failure)
	print("UI_DESIGN_REVIEW: checks=", checks, " failures=", failures.size(), " authentic_captures=", captures.size(), " output=", ProjectSettings.globalize_path(output_dir))
	await load("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _review_frontend() -> void:
	settings.close_menu()
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	root.get_node("LocaleManager")._apply(locale_id)
	_set_extent()
	await _frames(8)
	_expect(current_scene.scene_file_path == "res://ui/frontend/main_menu.tscn", "Review did not instantiate the actual title scene")
	_expect(not saves.session_active and not root.get_node("SessionFlow").loading, "Review title started a campaign")
	_expect(current_scene.find_child("Continue", true, false).disabled, "Empty isolated storage exposed a loadable Continue")
	for id: String in ["NewGame", "Saves", "Settings", "Controls", "Quit", "TribalPlaytest", "FleetTrial"]:
		var action := current_scene.find_child(id, true, false) as Control
		await _reveal(action)
		_assert_bounds(action, "home/" + id)
	await _return_to_top(current_scene)
	await _capture("home", "actual main_menu.tscn; empty real save storage")
	await _activate(current_scene.find_child("NewGame", true, false))
	_expect(current_scene._page == "new", "NewGame action did not open the real form")
	for id: String in ["AdventureName", "WorldSeed", "ChooseStartingCreature", "Begin", "Back"]:
		var control := current_scene.find_child(id, true, false) as Control
		await _reveal(control)
		_assert_bounds(control, "new/" + id)
	await _return_to_top(current_scene)
	await _capture("new_game", "actual new-game form; unchanged blank name and random seed fields")
	await _activate(current_scene.find_child("ChooseStartingCreature", true, false))
	await _frames(8)
	var library := current_scene.find_child("CreatureLibrary", true, false)
	_expect(library != null, "Starting-creature route did not open the actual library")
	if library != null:
		await _capture("creature_library", "actual built-in creature library reached from ChooseStartingCreature")
		await _activate(library.find_child("CloseLibrary", true, false))
	await _frames(3)
	await _activate(current_scene.find_child("Back", true, false))
	await _activate(current_scene.find_child("Controls", true, false))
	_expect(current_scene._page == "help", "Controls action did not open the help page")
	await _return_to_top(current_scene)
	await _capture("help", "actual SessionFlow control help; real active bindings")
	await _activate(current_scene.find_child("Back", true, false))
	await _activate(current_scene.find_child("Saves", true, false))
	var browser := current_scene.find_child("SaveBrowser", true, false)
	_expect(browser != null, "Saves action did not open the actual browser")
	if browser != null:
		for frame in range(256):
			if not browser.is_loading(): break
			await process_frame
		_expect(not browser.is_loading() and browser._slots.is_empty(), "Empty genuine save scan did not complete")
		for id: String in ["SearchSaves", "SavePhase", "SaveState", "SaveSort", "ResetSaveFilters", "BackFromSaves"]:
			_assert_bounds(browser.find_child(id, true, false), "saves/" + id)
		await _capture("save_browser", "actual async save browser with real empty-storage state; no fabricated campaigns")
		await _activate(browser.find_child("BackFromSaves", true, false))
	await _activate(current_scene.find_child("Settings", true, false))
	_expect(settings.is_menu_open() and paused, "Settings action did not open the paused shared menu")
	if settings.is_menu_open():
		await _frames(4)
		await _capture("settings_display", "actual shared DisplaySettings opened from title Settings")
		var tabs: TabContainer = settings._tabs
		for entry: Dictionary in [{"index": 1, "id": "controls"}, {"index": 2, "id": "language"}, {"index": 3, "id": "graphics"}]:
			await _activate_tab(tabs, int(entry.index))
			await _capture("settings_" + str(entry.id), "actual shared settings tab via TabBar input: " + str(entry.id))
		if tabs.get_tab_count() > 4:
			await _activate_tab(tabs, 4)
			await _frames(4)
			_expect(is_instance_valid(settings._audio_modal) and not settings._menu_panel.visible, "Audio tab did not open the actual shared audio modal")
			await _capture("settings_audio", "actual AudioManager panel opened by shared settings Audio TabBar input")
			await _key(KEY_ESCAPE)
		await _key(KEY_ESCAPE)
	_expect(not settings.is_menu_open() and not paused, "Settings return retained pause or the settings overlay")
	_expect(saves.list_slots().is_empty() and not saves.session_active, "UI review wrote save records or started a session")


func _set_extent() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(review_size)
	root.content_scale_factor = 1.0
	root.content_scale_size = review_size
	root.size = review_size


func _reveal(control: Control) -> void:
	if control == null:
		_expect(false, "Missing source UI action")
		return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _frames(3)


func _return_to_top(parent: Node) -> void:
	_reset_scrolls(parent)
	await _frames(3)


func _reset_scrolls(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is ScrollContainer: child.scroll_vertical = 0
		_reset_scrolls(child)


func _assert_bounds(control: Control, route: String) -> void:
	if control == null:
		_expect(false, "Missing " + route)
		return
	var rect: Rect2 = control.get_global_rect()
	_expect(control.is_visible_in_tree() and root.get_visible_rect().grow(2).encloses(rect) and rect.size.x > 0.0 and rect.size.y > 0.0,
		"Unreachable action " + route + " rect=" + str(rect) + " screen=" + str(root.get_visible_rect()))
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			_expect(ancestor.get_global_rect().grow(2).encloses(rect), "Action is clipped by scroll: " + route)
		ancestor = ancestor.get_parent()


func _activate(control: Control) -> void:
	if control == null:
		_expect(false, "Cannot activate missing source UI control")
		return
	await _reveal(control)
	_assert_bounds(control, "activate/" + control.name)
	await _click_position(control.get_global_rect().get_center())
	await _frames(3)


func _activate_tab(tabs: TabContainer, index: int) -> void:
	var bar := tabs.get_tab_bar()
	await _click_position(bar.get_global_rect().position + bar.get_tab_rect(index).get_center())
	await _frames(3)
	_expect(tabs.current_tab == index, "Actual TabBar input did not select tab " + str(index))


func _click_position(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event, true)
		await process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await _frames(3)


func _capture(page: String, provenance: String) -> void:
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var filename := "%s_%dx%d_%s.png" % [locale_id, review_size.x, review_size.y, page]
	var path := output_dir.path_join(filename)
	var error: Error = image.save_png(path)
	_expect(error == OK and image.get_width() == review_size.x and image.get_height() == review_size.y, "Capture failed or extent differs: " + filename)
	captures.append({"file": filename, "page": page, "locale": locale_id, "width": image.get_width(), "height": image.get_height(), "source": provenance, "sha256": FileAccess.get_sha256(path) if error == OK else ""})
	print("UI_DESIGN_CAPTURE: ", ProjectSettings.globalize_path(path), " source=", provenance)


func _write_manifest() -> void:
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		_expect(false, "Cannot write UI review manifest")
		return
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "source_scene": "res://ui/frontend/main_menu.tscn", "source_script": "res://tools/review_ui_design_capture.gd", "save_fixture": "empty isolated genuine storage", "checks": checks, "failures": failures, "captures": captures}, "\t"))
	file.close()


func _frames(count: int) -> void:
	for frame in range(count): await process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s/%dx%d: %s" % [locale_id, review_size.x, review_size.y, message])
