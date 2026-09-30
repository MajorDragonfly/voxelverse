extends SceneTree
## Real scene, GUI mouse/key dispatch, canonical persistence and fresh process.
const Blueprint = preload("res://civilization/buildings/building_blueprint.gd")
const Assembly = preload("res://assembly/core/modular_assembly.gd")
const Text = preload("res://civilization/buildings/building_editor_text.gd")
var editor: Node
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
	call_deferred("_restart" if "--building-restart" in args else "_run")

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _frames(count: int = 8) -> void:
	for frame in range(count):
		await process_frame

func _reveal(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await _frames(3)
		ancestor = ancestor.get_parent()
	await _frames()

func _click(control: Control) -> void:
	await _reveal(control)
	var point := control.get_global_rect().get_center()
	root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()

func _key(code: Key, control: bool = false, character: int = 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.unicode = character if pressed else 0
		event.ctrl_pressed = control
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _type(line: LineEdit, value: String, submit: bool = true) -> void:
	await _click(line)
	await _key(KEY_A, true)
	for character: String in value:
		await _key(character.to_upper().unicode_at(0), false, character.unicode_at(0))
	if submit:
		await _key(KEY_ENTER)
	await _frames()

func _field(field: String, axis: int, value: String) -> void:
	var spin: SpinBox = editor._transform_fields[field + "_%d" % axis]
	await _type(spin.get_line_edit(), value)

func _action(name: String) -> void:
	await _click(editor.find_child(name, true, false) as Control)

func _select(index: int) -> void:
	await _click(editor._assembly_list.get_child(index))
	_expect(editor.selected_part_index == index, "Mouse selection did not reach part %d" % index)

func _run() -> void:
	await _frames()
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("de")
	_expect(Text.render("BEDITOR_TITLE") == "VOXELVERSE · GEBÄUDEEDITOR", "Chat 1 catalog patch is missing")
	editor = load("res://civilization/buildings/building_builder.tscn").instantiate()
	root.add_child(editor)
	await _frames(15)
	print("BUILDING_EDITOR_STAGE ready")
	var original: Dictionary = editor.blueprint.duplicate(true)
	_expect(editor.selected_part_index == -1 and not editor._transform_fields.position_0.editable, "Empty selection is editable")
	await _select(3)
	var uid: String = editor.blueprint.parts[3].uid
	_expect(uid in editor._identity_label.text and "Kleines Fenster" in editor._selection_label.text, "Selection does not identify the exact repeated part")
	var old_position: Vector3 = editor.blueprint.parts[3].position
	await _field("rotation", 1, "35")
	_expect(editor.blueprint.parts[3].rotation.y == 35 and editor.blueprint.parts[3].position == old_position, "Rotation relocated an unsnapped legacy window")
	await _field("scale", 0, "1.5")
	_expect(editor.blueprint.parts[3].scale == Vector3(1.5, 1, 1) and editor.blueprint.parts[3].position == old_position, "Scale changed another axis or the legacy position")
	await _field("position", 0, "2.38")
	_expect(editor.blueprint.parts[3].position == Vector3(2.5, old_position.y, old_position.z), "Position input bypassed grid or changed untouched axes")
	var moved: Dictionary = editor.blueprint.duplicate(true)
	await _click(editor._undo_button)
	_expect(editor.blueprint.parts[3].position == old_position, "Mouse undo failed to restore position")
	await _click(editor._redo_button)
	_expect(editor.blueprint == moved, "Mouse redo failed to restore numeric edit exactly")
	await _click(editor._snap_button)
	await _field("position", 2, "-1.13")
	_expect(is_equal_approx(editor.blueprint.parts[3].position.z, -1.13), "Snap OFF still quantized the entered position")
	print("BUILDING_EDITOR_STAGE transforms")
	var stable: Dictionary = editor.blueprint.duplicate(true)
	var line: LineEdit = editor._transform_fields.rotation_2.get_line_edit()
	await _type(line, "27", false)
	var caret := line.caret_column
	var scroll: ScrollContainer = editor.find_child("InspectorScroll", true, false)
	var scroll_before := scroll.scroll_vertical
	var autosave_before := Blueprint.Store.read_text(Blueprint.AUTOSAVE_PATH)
	root.get_node("LocaleManager")._apply("en")
	await _frames()
	_expect(line.text == "27" and line.has_focus() and line.caret_column == caret, "Language switch lost numeric draft or focus")
	_expect(scroll.scroll_vertical == scroll_before and editor.blueprint == stable, "Language switch moved scroll or mutated design")
	_expect(Blueprint.Store.read_text(Blueprint.AUTOSAVE_PATH) == autosave_before, "Language switch rewrote autosave")
	_expect("Small Window" in editor._selection_label.text and editor.find_child("BackToWorld", true, false).text == "Back to World", "Selected part/navigation failed to translate")
	await _key(KEY_ENTER)
	await _frames()
	_expect(editor.blueprint.parts[3].rotation.z == 27, "Translated numeric draft did not commit")
	await _action("Duplicate")
	var copy_index: int = editor.selected_part_index
	var copy_uid: String = editor.blueprint.parts[copy_index].uid
	_expect(copy_uid != uid and editor.blueprint.parts[3].uid == uid and editor.blueprint.parts[copy_index].part_id == "opening_window_small", "Duplicate replaced existing IDs or shared a UID")
	var duplicated: Dictionary = editor.blueprint.duplicate(true)
	await _action("Delete")
	_expect(editor.blueprint.parts.size() == duplicated.parts.size() - 1, "Mouse delete did not remove exactly one part")
	await _click(editor._undo_button)
	_expect(editor.blueprint == duplicated, "Undo delete failed to restore duplicate UID")
	await _click(editor._redo_button)
	_expect(editor.blueprint.parts.size() == duplicated.parts.size() - 1, "Redo delete failed")
	await _click(editor.find_child("Category_tower", true, false))
	var before_add: int = editor.blueprint.parts.size()
	await _click(editor._part_buttons.tower_square)
	_expect(editor.blueprint.parts.size() == before_add + 1 and editor.blueprint.parts.back().part_id == "tower_square", "Mouse palette did not add a tower")
	# A name is user text even if it looks like a translation key or shortcut.
	await _type(editor._name_edit, "D G Q Z BEDITOR_SAVE {file} %s")
	_expect(editor.blueprint.parts.size() == before_add + 1 and not editor.blueprint.grid_snap, "Typing a name triggered builder shortcuts")
	var named: Dictionary = editor.blueprint.duplicate(true)
	root.get_node("LocaleManager")._apply("de")
	await _frames()
	_expect(editor.blueprint == named and editor._name_edit.text == named.name, "Language switch translated authored name or stable IDs")
	print("BUILDING_EDITOR_STAGE persistence")
	await _action("Save")
	var saved: Dictionary = editor.blueprint.duplicate(true)
	var filename: String = Blueprint.list_designs()[0]
	var save_text: String = Blueprint.Store.read_text(Blueprint.get_design_path(filename))
	_expect(not save_text.is_empty() and int(saved.revision) > int(original.revision), "Mouse save did not persist a revision")
	root.get_node("LocaleManager")._apply("en")
	await _frames()
	_expect(filename in editor._status_label.text and not "BEDITOR_SAVED" in editor._status_label.text, "Save receipt did not translate")
	_expect(Blueprint.Store.read_text(Blueprint.get_design_path(filename)) == save_text, "Translation rewrote saved design")
	await _action("New")
	_expect(editor.blueprint.design_id != saved.design_id, "New design reused the old design ID")
	await _action("Load")
	_expect(editor.blueprint == saved and editor._name_edit.text == saved.name, "Mouse load changed saved design, IDs or transforms")
	await _click(editor._undo_button)
	_expect(editor.blueprint.design_id != saved.design_id, "Undo load did not restore previous draft")
	await _click(editor._redo_button)
	_expect(editor.blueprint == saved, "Redo load did not restore saved IDs")
	print("BUILDING_EDITOR_STAGE restart")
	# Confirm the canonical draft from a separate engine process.
	var expected_path := "user://building-editor-restart-expected.json"
	var expected_file := FileAccess.open(expected_path, FileAccess.WRITE)
	expected_file.store_string(JSON.stringify(Assembly.serialize(saved)))
	expected_file.close()
	if "--external-restart" in OS.get_cmdline_user_args():
		# The native runner starts the second process after this renderer exits.
		print("BUILDING_EDITOR_RESTART_REQUEST ", JSON.stringify([filename, saved.design_id, expected_path]))
	else:
		var output: Array = []
		var exit_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/building_editor_input_test.gd", "--", "--building-restart", filename, saved.design_id, expected_path], output, true)
		_expect(exit_code == 0 and "BUILDING_EDITOR_RESTART_OK" in "\n".join(output), "Fresh process did not restore canonical design: " + "\n".join(output))
	print("BUILDING_EDITOR_STAGE layouts")
	await _layouts()
	# Delete every part through the UI: empty draft remains editable and undoable.
	await _select(editor.blueprint.parts.size() - 1)
	while not editor.blueprint.parts.is_empty():
		await _action("Delete")
	_expect(editor.selected_part_index == -1 and not editor._transform_fields.scale_0.editable, "Empty assembly kept a stale selection")
	_expect("no parts" in editor._stats_label.text or "keine Bauteile" in editor._stats_label.text, "Empty assembly validation is missing")
	await _capture("building-empty")
	await _click(editor._undo_button)
	_expect(editor.blueprint.parts.size() == 1, "Empty draft could not undo its last deletion")
	editor.free()
	await _frames()
	_finish()

func _layouts() -> void:
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = dimensions
			await _frames(15)
			await _select(3)
			var scroll: ScrollContainer = editor.find_child("InspectorScroll", true, false)
			scroll.scroll_vertical = 0
			await _frames()
			_expect(not editor._left_panel.get_global_rect().intersects(editor._right_panel.get_global_rect()), "Palette overlaps inspector at " + str(dimensions))
			for field: String in editor._transform_fields:
				var spin: SpinBox = editor._transform_fields[field]
				_expect(spin.get_global_rect().end.x <= editor._right_panel.get_global_rect().end.x + 1, "Numeric field clipped: " + field + str(dimensions))
			_expect("BEDITOR_" not in editor._stats_label.text and "BEDITOR_" not in editor._selection_label.text, "Untranslated keys remain on screen")
			await _capture("building-%s-%dx%d" % [locale, dimensions.x, dimensions.y])

func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		_expect(false, "Render capture requires a real graphical viewport")
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(not image.is_empty() and image.save_png(capture_dir.path_join(name + ".png")) == OK, "Could not capture " + name)

func _restart() -> void:
	await _frames()
	var args := OS.get_cmdline_user_args()
	var index := args.find("--building-restart")
	var loaded := Blueprint.load_from_file(Blueprint.get_design_path(args[index + 1]))
	_expect(not loaded.is_empty() and loaded.get("design_id") == args[index + 2], "Restart lost saved design ID")
	_expect(JSON.parse_string(JSON.stringify(Assembly.serialize(loaded))) == JSON.parse_string(FileAccess.get_file_as_string(args[index + 3])), "Restart changed saved part IDs/transforms/metadata")
	if failures.is_empty():
		print("BUILDING_EDITOR_RESTART_OK")
	_finish()

func _finish() -> void:
	print("BUILDING_EDITOR_INPUT_RESULT ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
