extends SceneTree
## Integration requires the delivered editor/catalog/registry owner patches.
const Edits = preload("res://creatures/editor/creature_appearance_edits.gd")
const SkinStyle = preload("res://creatures/editor/creature_skin_style.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
var editor: Node
var panel: Control
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args: capture_dir = args[args.find("--capture") + 1]
	call_deferred("_restart" if "--restart" in args else ("_baseline" if "--before" in args else "_run"))

func _settle() -> void:
	for frame in range(8): await process_frame

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _show(control: Control) -> void:
	var scroll: ScrollContainer = editor._right_panel.get_child(0)
	scroll.ensure_control_visible(control)
	await _settle()

func _click(control: Control) -> void:
	if is_instance_valid(panel) and (control.is_ancestor_of(panel) or panel.is_ancestor_of(control)): await _show(control)
	var position: Vector2 = control.get_global_rect().get_center()
	root.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()

func _key(keycode: Key, unicode: int = 0, ctrl: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.unicode = unicode
		event.pressed = pressed
		event.ctrl_pressed = ctrl
		root.push_input(event, true)
		await process_frame

func _start() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("de")
	print("APPEARANCE_START create")
	editor = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	print("APPEARANCE_START scene_ready")
	await _settle()
	print("APPEARANCE_START first_frames")
	editor.blueprint.appearance = SkinStyle.PALETTES[2].duplicate()
	editor.blueprint.appearance.erase("name")
	editor.blueprint.appearance.skin_type = "scales"
	editor.blueprint.appearance.skin_strength = 0.65
	editor.blueprint.appearance.skin_scale = 1.0
	editor._refresh_all()
	print("APPEARANCE_START refreshed")
	await _click(editor._mode_buttons.paint)
	print("APPEARANCE_START paint_clicked")
	editor._inspector_open = true
	editor._queue_workshop_layout()
	await _settle()
	panel = editor.find_child("CreatureAppearancePanel", true, false)

func _baseline() -> void:
	await _start()
	await _capture("before-de-1280x720")
	editor.free()
	await _finish()

func _run() -> void:
	_model_checks()
	await _start()
	_expect(panel != null and panel.visible, "Paint tab did not open appearance panel")
	if panel == null:
		editor.free()
		await _finish()
		return
	print("APPEARANCE_STAGE ready")
	var cosmetic_before: Dictionary = editor.blueprint.duplicate(true)
	await _capture("after-de-1280x720")
	var initial_body: Dictionary = editor.blueprint.body.duplicate(true)
	var initial_parts: Array = editor.blueprint.parts.duplicate(true)
	var initial_stats: Dictionary = Assembly.BaseBlueprint.calculate_stats(editor.blueprint)
	var before_palette: Dictionary = editor.blueprint.duplicate(true)
	panel.palette.select(1)
	panel.palette.item_selected.emit(1)
	_expect(editor.blueprint == before_palette, "Palette preview changed draft before Apply")
	await _click(panel.apply_button)
	_expect(Edits.palette_index(Edits.read(editor.blueprint)) == 1, "Palette Apply did not set all five channels")
	await _click(editor._undo_button)
	_expect(editor.blueprint.appearance == cosmetic_before.appearance, "Palette undo did not restore all colors")
	await _click(editor._redo_button)
	_expect(Edits.palette_index(Edits.read(editor.blueprint)) == 1, "Palette redo lost channels")
	print("APPEARANCE_STAGE palette")
	# Type a real hex draft and submit with Enter through the viewport.
	var before_color: Dictionary = editor.blueprint.appearance.duplicate(true)
	var hex: LineEdit = panel.hex_fields.eye_color
	await _click(hex)
	await _key(KEY_A, 0, true)
	for character: String in "#11AACC": await _key(KEY_NONE, character.unicode_at(0))
	await _key(KEY_ENTER)
	await _settle()
	_expect(editor.blueprint.appearance.eye_color == "11aacc", "Keyboard hex color was not applied")
	for field: String in Edits.COLORS:
		if field != "eye_color": _expect(editor.blueprint.appearance[field] == before_color[field], "Single color changed " + field)
	_expect("eigene" in panel.palette_status.text, "Custom palette status missing")
	await _click(editor._undo_button)
	_expect(editor.blueprint.appearance == before_color, "One undo did not restore single color")
	await _click(editor._redo_button)
	print("APPEARANCE_STAGE hex")
	# Invalid entry leaves draft/history intact.
	var invalid_before: Dictionary = editor.blueprint.duplicate(true)
	panel._submit_hex("#zzzzzz", "eye_color")
	_expect(editor.blueprint == invalid_before, "Invalid hex mutated draft")
	# One color popup gesture with intervening global mouse releases.
	var popup_before: Dictionary = editor.blueprint.appearance.duplicate(true)
	await _click(panel.pickers.base_color)
	for color: Color in [Color("112233"), Color("445566"), Color("778899")]:
		panel.pickers.base_color.color_changed.emit(color)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		root.push_input(release, true)
		await process_frame
	_expect(not panel.color_status.visible, "Successful color edit retained old validation error")
	panel.pickers.base_color.get_popup().hide()
	await _settle()
	await _click(editor._undo_button)
	_expect(editor.blueprint.appearance == popup_before, "Color popup required more than one undo")
	await _click(editor._redo_button)
	_expect(editor.blueprint.appearance.base_color == "778899", "Color popup redo lost final color")
	print("APPEARANCE_STAGE popup")
	# All supported types, deterministic material path, no geometry replacement.
	for index: int in SkinStyle.TYPES.size():
		panel.skin_choice.select(index)
		panel.skin_choice.item_selected.emit(index)
		_expect(editor.blueprint.appearance.skin_type == SkinStyle.TYPES.keys()[index], "Skin type mismatch")
		_expect(panel.ranges.skin_strength.editable == (index != 0), "Smooth controls are misleading")
	var before_drag: Dictionary = editor.blueprint.appearance.duplicate(true)
	panel.ranges.pattern_size.drag_started.emit()
	for amount: float in [1.2, 1.5, 2.0]: panel.ranges.pattern_size.value = amount
	panel.ranges.pattern_size.drag_ended.emit(true)
	_expect(is_equal_approx(editor.blueprint.appearance.skin_scale, 0.5), "Larger pattern failed inverse scale mapping")
	await _click(editor._undo_button)
	_expect(editor.blueprint.appearance == before_drag, "Skin drag required more than one undo")
	await _click(editor._redo_button)
	_expect(is_equal_approx(editor.blueprint.appearance.skin_scale, 0.5), "Skin drag redo failed")
	panel.ranges.skin_strength.value = 40.0
	_expect(is_equal_approx(editor.blueprint.appearance.skin_strength, 0.4), "Skin percentage did not map to existing value")
	panel.target.select(4)
	await _click(panel.find_child("AppearanceSwatch_f3ead6", true, false))
	_expect(editor.blueprint.appearance.horn_color == "f3ead6", "Swatch used wrong color target")
	print("APPEARANCE_STAGE skin")
	# Reset cosmetics, preserve extensions and all gameplay fields.
	editor.blueprint.appearance.future_extension = {"keep": 42}
	var reset_before: Dictionary = editor.blueprint.appearance.duplicate(true)
	await _click(panel.reset_button)
	for field: String in Edits.FIELDS: _expect(not editor.blueprint.appearance.has(field), "Reset retained " + field)
	_expect(editor.blueprint.appearance.future_extension.keep == 42, "Reset removed unknown extension")
	var reset_state: Dictionary = Edits.read(editor.blueprint)
	await _click(editor._undo_button)
	_expect(editor.blueprint.appearance == reset_before, "Reset undo lost cosmetics/extensions")
	await _click(editor._redo_button)
	_expect(Edits.read(editor.blueprint) == reset_state and editor.blueprint.appearance.future_extension.keep == 42, "Reset redo lost cosmetic defaults/extensions")
	for field: String in Edits.COLORS: _expect(not editor.blueprint.appearance.has(field), "Reset redo retained custom color")
	await _click(editor._undo_button)
	_expect(editor.blueprint.body == initial_body and editor.blueprint.parts == initial_parts, "Cosmetics altered geometry or part identities")
	_expect(Assembly.BaseBlueprint.calculate_stats(editor.blueprint) == initial_stats, "Cosmetics changed gameplay stats")
	print("APPEARANCE_STAGE reset")
	# DE/EN preserve unfinished hex text and gesture; narrow view uses real scroll.
	await _click(panel.hex_fields.belly_color)
	panel.hex_fields.belly_color.text = "#AB"
	root.get_node("LocaleManager")._apply("en")
	await _settle()
	_expect(panel.hex_fields.belly_color.text == "#AB", "Language switch erased unfinished color")
	_expect("Colors" in panel.get_child(0).text, "Panel did not translate")
	panel.hex_fields.belly_color.release_focus()
	panel.sync(editor.blueprint)
	await _capture("after-en-1280x720")
	root.size = Vector2i(800, 600)
	root.get_node("DisplaySettings").ui_scale = 1.5
	root.content_scale_factor = 1.5
	editor._inspector_open = true
	editor._queue_workshop_layout()
	await _settle()
	await _show(panel.reset_button)
	_expect(root.get_visible_rect().encloses(panel.reset_button.get_global_rect()), "Reset not reachable at 800x600/150%")
	await _capture("after-en-800x600-150-top")
	await _show(panel.ranges.pattern_size)
	_expect(root.get_visible_rect().encloses(panel.ranges.pattern_size.get_global_rect()), "Skin control not reachable at 800x600/150%")
	await _capture("after-en-800x600-150-skin")
	print("APPEARANCE_STAGE layout")
	# Real design persistence and a fresh process using identical isolated userdata.
	editor._save_blueprint()
	_expect(editor._last_save_ok, "Cosmetic editor save failed")
	var expected: Dictionary = Edits.read(editor.blueprint)
	var expected_file := FileAccess.open("user://appearance_expected.json", FileAccess.WRITE)
	expected_file.store_string(JSON.stringify(expected))
	expected_file.close()
	editor._load_blueprint()
	_expect(Edits.read(editor.blueprint) == expected, "Load lost appearance")
	var output: Array = []
	print("APPEARANCE_STAGE restarting")
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/int30_creature_appearance_test.gd", "--", "--restart"], output, true)
	_expect(code == 0 and "APPEARANCE_RESTART_OK" in "\n".join(output), "Fresh process lost appearance: " + "\n".join(output))
	print("APPEARANCE_STAGE restarted")
	editor.free()
	await _finish()

func _model_checks() -> void:
	var blueprint: Dictionary = Assembly.create_default()
	var before: Dictionary = blueprint.duplicate(true)
	Edits.read(blueprint)
	_expect(before == blueprint, "Reading cosmetics mutated draft")
	for command: Dictionary in [{"body": {}}, {"skin_type": "unknown"}, {"eye_color": "bad"}, {"skin_strength": NAN}, {"skin_scale": INF}]:
		_expect(Edits.apply(blueprint, command).is_empty(), "Invalid cosmetic command accepted")
	var future: Dictionary = blueprint.duplicate(true)
	future.version = 999
	_expect(Edits.apply(future, {"reset": true}).is_empty(), "Future design allowed reset")
	blueprint._protected_design_source = {}
	_expect(Edits.apply(blueprint, {"base_color": "112233"}).is_empty(), "Protected original allowed edit")

func _restart() -> void:
	await _settle()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://appearance_expected.json"))
	var loaded: Dictionary = Assembly.load_from_file(Assembly.SAVE_PATH)
	_expect(Edits.read(loaded) == expected, "Fresh design read lost cosmetics")
	editor = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	await _settle()
	editor._load_blueprint()
	_expect(Edits.read(editor.blueprint) == expected, "Fresh editor load lost cosmetics")
	editor.free()
	if failures.is_empty(): print("APPEARANCE_RESTART_OK")
	await _finish()

func _capture(label: String) -> void:
	if capture_dir.is_empty(): return
	# A neutral pointer removes transient hover tooltips from comparison images.
	root.warp_mouse(Vector2(400, 35))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(400, 35)
	root.push_input(motion, true)
	await _settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _finish() -> void:
	await process_frame
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("INT30_APPEARANCE_OK checks=", checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
