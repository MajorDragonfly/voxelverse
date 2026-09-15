extends SceneTree
## The real workshop must translate without recreating or saving its session.
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Text = preload("res://creatures/editor/creature_editor_text.gd")
var editor: Node
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
	call_deferred("_restart" if "--editor-restart" in args else "_run")

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _settle() -> void:
	for frame in range(8):
		await process_frame

func _click(control: Control) -> void:
	root.warp_mouse(control.get_global_rect().get_center())
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()

func _run() -> void:
	await _settle()
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("de")
	editor = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	await _settle()
	# Click through the real scene and edit a coalesced gesture mid-language-change.
	await _click(editor._mode_buttons.body)
	editor.selected_body_segment = 2
	editor._refresh_stats_panel()
	editor._begin_gesture()
	editor._change_shape(1.15, "width_scale")
	await _language_cycles()
	editor._change_shape(1.4, "width_scale")
	editor._end_gesture()
	var shaped: Dictionary = editor.blueprint.duplicate(true)
	await _click(editor._undo_button)
	_expect(editor.blueprint != shaped, "Undo after translated gesture had no effect")
	await _click(editor._redo_button)
	_expect(editor.blueprint == shaped, "Redo lost the translated gesture")
	# A draft containing placeholder-like user text must remain byte-for-byte text.
	editor._creature_name_edit.grab_focus()
	editor._creature_name_edit.text = "M {revision} %s EDITOR_SAVE"
	editor._creature_name_edit.text_changed.emit(editor._creature_name_edit.text)
	editor._creature_name_edit.caret_column = 4
	editor._creature_name_edit.select(2, 9)
	await _language_cycles()
	_expect(editor._creature_name_edit.caret_column == 4 and editor._creature_name_edit.get_selected_text() == "{revisi", "Locale lost name caret/selection")
	await _click(editor.find_child("SaveCreature", true, false))
	_expect(editor._last_save_ok, "Real save button failed")
	var saved := FileAccess.get_file_as_string(Assembly.SAVE_PATH)
	await _language_cycles()
	_expect(editor.blueprint.name in editor._builder_status_label.text, "Saved name was translated or interpolated recursively")
	_expect(saved == FileAccess.get_file_as_string(Assembly.SAVE_PATH), "Language cycle rewrote the design")
	# Fail the existing atomic writer without mocks; keep the draft and old save.
	var absolute := ProjectSettings.globalize_path(Assembly.SAVE_PATH)
	_expect(DirAccess.rename_absolute(absolute, absolute + ".held") == OK, "Could not hold isolated save")
	_expect(DirAccess.make_dir_absolute(absolute) == OK, "Could not block isolated save target")
	editor._save_blueprint()
	_expect(not editor._last_save_ok, "Directory-blocked save unexpectedly succeeded")
	await _language_cycles()
	_expect("Save failed" in editor._builder_status_label.text, "Failed save receipt did not translate")
	DirAccess.remove_absolute(absolute)
	DirAccess.rename_absolute(absolute + ".held", absolute)
	await _catalogs()
	# Existing limb/terminal transform controls keep identity and numeric input.
	editor._set_mode("parts")
	var leg := -1
	for index in editor.blueprint.parts.size():
		if editor.blueprint.parts[index].category == "legs": leg = index; break
	_expect(leg >= 0, "Fixture has no leg")
	editor._select_part_by_index(leg)
	editor._choose_transform_target(1)
	editor._inspector_open = true
	editor._queue_workshop_layout()
	await _settle()
	var spin: SpinBox = editor._part_fields.rotation_1
	spin.get_line_edit().grab_focus()
	await _settle()
	spin.get_line_edit().select_all()
	for character: String in ["2", "7"]:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = character.unicode_at(0)
		event.keycode = character.unicode_at(0)
		root.push_input(event, true)
	await _settle()
	_expect(spin.get_line_edit().text == "27", "Typing did not prepare number draft: " + spin.get_line_edit().text)
	await _language_cycles()
	_expect(spin.get_line_edit().text == "27" and editor._editing_terminal, "Translation reset unfinished terminal input")
	spin.get_line_edit().text_submitted.emit("27")
	spin.get_line_edit().release_focus()
	await _settle()
	# Actual F8 modal owns pause; changing its locale must not rebuild the editor.
	var display: Node = root.get_node("DisplaySettings")
	display._toggle_settings_menu()
	await _settle()
	var was_paused := paused
	await _language_cycles()
	_expect(display.is_menu_open() and paused == was_paused, "Translation closed settings or changed pause")
	display._toggle_settings_menu()
	await _settle()
	await _advanced_controls()
	await _layouts()
	# Reload canonical save in a new process; language is a device preference only.
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/editor_localization_test.gd", "--", "--editor-restart"], output, true)
	_expect(code == 0 and "EDITOR_RESTART_OK" in "\n".join(output), "Restart could not restore saved design: " + "\n".join(output))
	editor.free()
	await _settle()
	await _finish()

func _advanced_controls() -> void:
	editor._set_mode("body")
	editor._inspector_open = true
	editor._toggle_fittings(true)
	editor._check_fit_now()
	await _settle()
	var report: Dictionary = editor._fit_report.duplicate(true)
	var findings: Array = editor._fit_findings.get_children()
	await _language_cycles()
	_expect(editor._fit_report == report and editor._fit_findings.get_children() == findings, "Language reran fit checks or rebuilt collision actions")
	_expect("Fixed test rider size" in editor._attachment_status.text and "Support" in editor._attachment_status.text, "Fit or seat report stayed in German")
	editor._find_seat_proposal()
	var proposal: Dictionary = editor._seat_proposal.duplicate(true)
	await _language_cycles()
	_expect(editor._seat_proposal == proposal, "Language replaced the pending seat proposal")
	_expect("Seat proposal" in editor._attachment_status.text or "No supported seat" in editor._attachment_status.text, "Seat proposal did not translate")
	editor._start_motion_review()
	var review: RefCounted = editor._review
	await _language_cycles()
	_expect(editor._review == review, "Language cancelled or restarted the motion review")
	if editor._review.report.status == "running": editor._start_motion_review()
	await _settle()
	var result_controls: Array = editor._review_results.get_children()
	await _language_cycles()
	_expect(editor._review_results.get_children() == result_controls, "Language rebuilt completed motion results")
	_expect("Check cancelled" in editor._review_label.text or "poses checked" in editor._review_label.text, "Motion result did not translate")
	editor._toggle_fittings(false)

func _language_cycles() -> void:
	var snapshot: Dictionary = editor.blueprint.duplicate(true)
	var history: Array = [editor._history._undo_stack.duplicate(true), editor._history._redo_stack.duplicate(true)]
	var selection: Array = [editor._studio_mode, editor.current_category, editor.selected_body_segment, editor.selected_part_index, editor._editing_terminal, editor._motion_choice, editor._gesture, editor._gesture_recorded, editor._active_color_field]
	var focus: Control = root.gui_get_focus_owner()
	var palette: Array = editor._part_grid.get_children()
	var categories: Array = editor._category_grid.get_children()
	var preview: Node = editor._preview
	var draft: String = editor._creature_name_edit.text
	var pivot: Transform3D = editor._preview_pivot.transform
	var file_before := FileAccess.get_file_as_string(Assembly.SAVE_PATH) if FileAccess.file_exists(Assembly.SAVE_PATH) else ""
	for language: String in ["de", "en"]:
		var scroll: ScrollContainer = editor._right_panel.get_child(0)
		var offset := scroll.scroll_vertical
		root.get_node("LocaleManager")._apply(language)
		await _settle()
		_expect(editor.blueprint == snapshot, "Language changed blueprint")
		_expect(editor._history._undo_stack == history[0] and editor._history._redo_stack == history[1], "Language changed undo history")
		_expect(selection == [editor._studio_mode, editor.current_category, editor.selected_body_segment, editor.selected_part_index, editor._editing_terminal, editor._motion_choice, editor._gesture, editor._gesture_recorded, editor._active_color_field], "Language changed editing context")
		_expect(root.gui_get_focus_owner() == focus, "Language lost focus")
		_expect(editor._part_grid.get_children() == palette and editor._category_grid.get_children() == categories and editor._preview == preview, "Language rebuilt live controls or preview")
		_expect(editor._creature_name_edit.text == draft and editor._preview_pivot.transform == pivot, "Language changed draft name or view")
		var bar := scroll.get_v_scroll_bar()
		_expect(scroll.scroll_vertical == mini(offset, maxi(0, int(bar.max_value - bar.page))), "Language lost inspector scroll")
		_expect((FileAccess.get_file_as_string(Assembly.SAVE_PATH) if FileAccess.file_exists(Assembly.SAVE_PATH) else "") == file_before, "Language saved gameplay")
		_expect(editor.find_child("SaveCreature", true, false).text == ("Speichern" if language == "de" else "Save"), "Save action did not translate")

func _catalogs() -> void:
	for language: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(language)
		for category: String in ["body", "mouth", "eyes", "legs", "arms", "feet", "hands", "tail", "horns", "plates", "spikes", "decor", "paint"]:
			for part: Dictionary in Parts.get_parts_for_category(category):
				var source: Dictionary = part.duplicate(true)
				for field: String in ["name", "description"]:
					var key := "EDITOR_PART_" + str(part.id).to_upper() + "_" + field.to_upper()
					_expect(Text.text(key) != key and Text.part(part, field) == Text.text(key), "Missing catalog translation: " + key)
				_expect(part == source, "Part translation changed canonical definition")
		# Locked and available cards display their actual localized description.
		editor._set_mode("parts")
		editor._on_category_button_pressed("mouth")
		await _settle()
		for card in editor._part_grid.get_children():
			_expect(Text.part(card.definition) == card._title.text and Text.part(card.definition, "description") in card.tooltip_text, "Live card not translated")
		await _language_cycles()

func _layouts() -> void:
	for size_value: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale_value: float in [1.0, 1.5]:
			root.size = size_value
			root.get_node("DisplaySettings").ui_scale = scale_value
			for language: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(language)
				for mode: String in ["body", "parts", "paint", "test"]:
					editor._set_mode(mode)
					editor._inspector_open = mode in ["parts", "paint"]
					if mode == "parts": editor._select_part_by_index(0)
					editor._queue_workshop_layout()
					await _settle()
					var viewport := Rect2(Vector2.ZERO, Vector2(size_value))
					for control: Control in [editor._header, editor._bottom_panel, editor.find_child("PlayCreature", true, false), editor.find_child("SaveCreature", true, false)]:
						_expect(viewport.encloses(control.get_global_rect()), "Control leaves viewport: %s %s %s %.1f %s" % [control.name, size_value, language, scale_value, mode])
					var pane: Control = editor._right_panel if editor._inspector_open else editor._left_panel
					_expect(pane.size.y >= 90 and pane.get_global_rect().end.y <= editor._bottom_panel.get_global_rect().position.y, "Side pane has no usable scrolling area")
					_expect(not editor._header.get_global_rect().intersects(pane.get_global_rect()), "Header overlaps side pane")
					_expect(editor._compact_workshop == editor._pane_toggle.visible, "Missing compact pane navigation")
					if editor._compact_workshop:
						_expect(editor._right_panel.visible != editor._left_panel.visible, "Compact sidebars overlap")
						var before: bool = editor._inspector_open
						await _click(editor._pane_toggle)
						_expect(editor._inspector_open != before, "Pane toggle is unreachable")
						await _click(editor._pane_toggle)
					for tab: Button in editor._mode_buttons.values():
						_expect(viewport.encloses(tab.get_global_rect()), "Mode tab leaves viewport")
					if not capture_dir.is_empty() and ((size_value.x == 800 and scale_value == 1.5) or (size_value.x == 1920 and scale_value == 1.0)):
						await RenderingServer.frame_post_draw
						var name := "editor-%s-%dx%d-%d-%s.png" % [language, size_value.x, size_value.y, roundi(scale_value * 100), mode]
						root.get_texture().get_image().save_png(capture_dir.path_join(name))

func _restart() -> void:
	await _settle()
	root.get_node("LocaleManager")._apply("en")
	var saved := Assembly.load_from_file(Assembly.SAVE_PATH)
	_expect(not saved.is_empty() and saved.name == "M {revision} %s EDITOR_SAVE", "Saved user name changed across restart")
	print("EDITOR_RESTART_OK" if failures.is_empty() else "EDITOR_RESTART_FAILED")
	await _finish()

func _finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print("EDITOR_LOCALIZATION_RESULT ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
