extends SceneTree
const Library = preload("res://assembly/exchange/creature_design_library.gd")
const Starter = preload("res://assembly/exchange/creature_start_templates.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
var failures: Array[String] = []
var capture_dir: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture-dir" in args: capture_dir = args[args.find("--capture-dir") + 1]
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	root.get_node("LocaleManager")._apply("de")
	await _frames(2)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var slot: String = saves.create_slot("Library UI", 15838, "cube_sphere_m1_v1", Starter.packages()[0])
	_expect(not slot.is_empty(), "UI campaign setup failed")
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	await _frames(12)
	var before: Dictionary = _form(editor.blueprint)
	var design_id: String = editor.blueprint.design_id
	var progress: Dictionary = root.get_node("ProgressionService").export_state()
	var open: Button = editor.find_child("OpenBlueprintLibrary", true, false)
	await _click(open)
	var panel: Control = editor._library_panel
	_expect(is_instance_valid(panel), "Workshop library button did not open")
	if is_instance_valid(panel):
		await _click(panel.find_child("Template_3", true, false))
		_expect(not panel._use.disabled and panel._preview._model != null, "Selected template has no usable actual preview")
		await _capture("editor-templates-de")
		if not capture_dir.is_empty():
			for width in [1920, 2560]:
				root.size = Vector2i(width, 1080)
				root.content_scale_size = Vector2i(width, 1080)
				await _frames(4)
				await _capture("desktop-%d-de" % width)
			root.size = Vector2i(1280, 720)
			root.content_scale_size = Vector2i(1280, 720)
			await _frames(4)
		await _click(panel._use)
		_expect(not is_instance_valid(editor._library_panel), "Adoption did not close library")
		_expect(editor.blueprint.design_id == design_id and root.get_node("ProgressionService").export_state() == progress, "Adoption changed identity/progression")
		var adopted: Dictionary = _form(editor.blueprint)
		_expect(adopted != before and editor.blueprint.parts.size() == 5, "Template body was not applied")
		_key(KEY_Z, true)
		await _frames(2)
		_expect(_form(editor.blueprint) == before, "One undo did not restore the previous complete body")
		_key(KEY_Y, true)
		await _frames(2)
		_expect(_form(editor.blueprint) == adopted, "Redo did not restore the template")
		await _click(editor.find_child("SaveCreature", true, false))
		_expect(editor._last_save_ok and _form(Creature.load_best_available()) == adopted, "Editor could not save adopted body")
		await _click(open)
		panel = editor._library_panel
		panel._variant_name.text = "Meine Mooskreatur"
		await _click(panel.find_child("SaveVariant", true, false))
		_expect(Library.read().packages.size() == 1 and panel._name.text == "Meine Mooskreatur", "Save-variant control did not store/select current body")
		var key: String = panel._selected
		await _click(panel.find_child("ExportBlueprint", true, false))
		_expect(panel._file.visible and panel._file.file_mode == FileDialog.FILE_MODE_SAVE_FILE, "Export file chooser did not open")
		panel._file.hide()
		panel._file.file_selected.emit(ProjectSettings.globalize_path("user://ui-transfer.json"))
		await _frames(2)
		_expect(panel._last_result.ok and Package.read_file("user://ui-transfer.json").ok and Package.read_file("user://ui-transfer.json").package == Library.get_package(key).package, "Export chooser result did not create the selected portable file")
		await _click(panel.find_child("ImportBlueprint", true, false))
		_expect(panel._file.visible and panel._file.file_mode == FileDialog.FILE_MODE_OPEN_FILE, "Import file chooser did not open")
		panel._file.hide()
		panel._file.file_selected.emit(ProjectSettings.globalize_path("user://ui-transfer.json"))
		await _frames(2)
		_expect(Library.read().packages.size() == 1 and panel._selected == key, "Import created a duplicate immutable revision")
		var invalid := FileAccess.open("user://invalid-template.json", FileAccess.WRITE)
		invalid.store_string("{broken")
		invalid.close()
		await _click(panel.find_child("ImportBlueprint", true, false))
		panel._file.hide()
		panel._file.file_selected.emit(ProjectSettings.globalize_path("user://invalid-template.json"))
		await _frames(2)
		_expect(panel._status.visible and not panel._last_result.ok and _form(editor.blueprint) == adopted and Library.read().packages.size() == 1, "Rejected import changed editor/library or hid its error")
		await _capture("invalid-import-de")
		panel._status.hide()
		panel._last_result.clear()
		panel._search.text = "Meine"
		panel._preview._angle = 1.1
		panel._preview._zoom = 1.25
		root.get_node("LocaleManager")._apply("en")
		await _frames(2)
		_expect(panel._selected == key and panel._search.text == "Meine" and panel._name.text == "Meine Mooskreatur", "Language change lost selection/search or translated a custom name")
		_expect(is_equal_approx(panel._preview._angle, 1.1) and is_equal_approx(panel._preview._zoom, 1.25), "Language change reset preview camera")
		await _capture("local-variant-en")
		root.size = Vector2i(800, 600)
		root.content_scale_size = Vector2i(800, 600)
		root.content_scale_factor = 1.5
		await _frames(4)
		panel._show_detail = false
		panel._layout()
		await _frames(2)
		await _capture("narrow-list-en-150")
		await _click(panel.find_child("Template_1", true, false))
		await _capture("narrow-detail-en-150")
		_expect(panel._detail.visible and not panel._side.visible and _onscreen(panel._use), "Narrow detail did not keep adoption reachable")
		_key(KEY_ESCAPE)
		await _frames(2)
		_expect(is_instance_valid(editor._library_panel) and panel._side.visible, "Escape did not return from detail to list")
		await _click(panel.find_child("RemoveBlueprint", true, false))
		_expect(panel._delete.visible and Library.get_package(key).ok, "Remove did not require a choice")
		panel._delete.hide()
		_expect(Library.get_package(key).ok, "Cancelling removal deleted the template")
		await _click(panel.find_child("RemoveBlueprint", true, false))
		panel._delete.hide()
		panel._delete.confirmed.emit()
		await _frames(2)
		_expect(Library.read().packages.is_empty() and _form(editor.blueprint) == adopted, "Confirmed removal changed the editor or retained the template")
		_key(KEY_ESCAPE)
		await _frames(2)
		_expect(not is_instance_valid(editor._library_panel), "Second Escape did not close library")
		_expect(root.get_viewport().gui_get_focus_owner() == open, "Closing the library did not restore workshop focus")
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	editor.queue_free()
	await _frames(3)
	await _new_game_menu()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("CREATURE_LIBRARY_UI_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _new_game_menu() -> void:
	root.get_node("LocaleManager")._apply("de")
	var menu: Control = load("res://ui/frontend/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(4)
	await _click(menu.find_child("NewGame", true, false))
	menu._title_input.text = "Mein neues Abenteuer"
	menu._seed_input.text = "18842"
	# The menu column is scrollable; reveal its template selector.
	var choose: Button = menu.find_child("ChooseStartingCreature", true, false)
	choose.grab_focus()
	await _frames(3)
	await _click(choose)
	var panel: Control = menu._library_panel
	_expect(is_instance_valid(panel), "New game did not expose template picker")
	if is_instance_valid(panel):
		await _click(panel.find_child("Template_2", true, false))
		await _click(panel._use)
		_expect(menu._creature_template.design_id == "starter_dune", "New game did not retain chosen starting body")
		_expect(menu._title_input.text == "Mein neues Abenteuer" and menu._seed_input.text == "18842", "Template selection lost adventure input")
		await _capture("new-game-selected-de")
		var expected: Dictionary = _form(Starter.prepare(menu._creature_template, Creature.create_default()).blueprint)
		var flow: Node = root.get_node("SessionFlow")
		var launched: Array[bool] = [false]
		flow.world_started.connect(func(): launched[0] = true, CONNECT_ONE_SHOT)
		await _click(menu.find_child("Begin", true, false))
		var deadline: int = Time.get_ticks_msec() + 90000
		while not launched[0] and Time.get_ticks_msec() < deadline: await process_frame
		_expect(launched[0], "Selected template did not launch through the real menu")
		var player: Node = get_first_node_in_group(&"player")
		_expect(player != null, "Template adventure has no playable creature")
		if player != null:
			var visual: Node = player.get_node("CreatureRuntimeVisual")
			_expect(_form(visual.blueprint) == expected and _form(player.creature_design) == expected, "Runtime changed the selected template's authored form")
			_expect(visual.blueprint.design_id != "starter_dune" and root.get_node("ProgressionService").get_unlocked_part_ids() == Starter.unlocked_parts(), "Template launch inherited identity or extra progression")
			_expect(int(root.get_node("GameState").world_seed) == 18842, "Template selection lost the new-world seed")
			print("CREATURE_LIBRARY_WORLD_STARTED")
		await flow._release_world()
		await _frames(2)
	elif is_instance_valid(menu):
		current_scene = null
		menu.queue_free()
		await _frames(2)


func _form(blueprint: Dictionary) -> Dictionary:
	var data: Dictionary = Package.Schema.project(Creature.serialize_snapshot(blueprint), Package.Schema.BLUEPRINT)
	return JSON.parse_string(JSON.stringify(data))


func _click(control: Control) -> void:
	if not is_instance_valid(control):
		_expect(false, "Missing clickable control")
		return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _frames(2)
	var point: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames(2)


func _key(code: Key, control: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.ctrl_pressed = control
		event.pressed = pressed
		root.push_input(event, true)


func _onscreen(control: Control) -> bool:
	return root.get_visible_rect().encloses(control.get_global_rect())


func _frames(count: int) -> void:
	for index in range(count): await process_frame


func _capture(name: String) -> void:
	if capture_dir.is_empty(): return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Could not save UI capture")


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
