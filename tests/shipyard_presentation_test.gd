extends SceneTree
## INT30-15: real pointer/key actions against the standalone production shipyard.
const Ship = preload("res://space/ships/ship_blueprint.gd")
const Yard = preload("res://space/ships/shipyard.tscn")
const Present = preload("res://space/ships/shipyard_presentation.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []
var checks: int = 0
var capture_directory: String = ""
var expected: Dictionary = {}
var case_filter: String = "all"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--case"): case_filter = args[args.find("--case") + 1]
	if args.has("--restart"):
		expected = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://shipyard-presentation-restart.json"))
		for role: String in ["expedition", "lander"]:
			var entry: Dictionary = expected[role]
			var original: Dictionary = Ship.load_design(entry.original)
			var copy: Dictionary = Ship.load_design(entry.copy)
			_expect(original.ok and copy.ok, role + " original and copy reopen in fresh process")
			_expect(FileAccess.get_file_as_string(entry.original).sha256_text() == entry.original_sha256, role + " original bytes unchanged after copy/reopen/restart")
			if original.ok and copy.ok:
				_expect(original.blueprint.design_id == entry.original_id and copy.blueprint.design_id == entry.copy_id, role + " independent design IDs survive restart")
				_expect(_uids(original.blueprint) == entry.original_uids and _uids(copy.blueprint) == entry.copy_uids, role + " all module IDs survive restart")
	else:
		if FileAccess.file_exists("user://shipyard-presentation-restart.json"):
			expected = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://shipyard-presentation-restart.json"))
		if args.has("--capture"): capture_directory = args[args.find("--capture") + 1]
		root.gui_embed_subwindows = true
		root.content_scale_size = Vector2i.ZERO
		root.content_scale_factor = 1.0
		root.size = Vector2i(1280, 720)
		var editor: Control = Yard.instantiate()
		root.add_child(editor)
		await _frames(4)
		# Deferred display defaults are now applied; use actual pixel layouts.
		root.content_scale_size = Vector2i.ZERO
		root.content_scale_factor = 1.0
		root.get_node("LocaleManager")._apply("de")
		if case_filter in ["all", "presentation"]:
			print("SHIPYARD_STAGE model")
			_model_checks()
		for role: String in ["expedition", "lander"]:
			if case_filter not in ["all", role]: continue
			print("SHIPYARD_STAGE input " + role)
			await _input_checks(editor, role)
		if case_filter in ["all", "presentation"]:
			print("SHIPYARD_STAGE language")
			await _language_checks(editor)
			print("SHIPYARD_STAGE issue")
			await _issue_checks(editor)
			print("SHIPYARD_STAGE fit")
			await _fit_checks(editor)
		if case_filter in ["all", "layout"]:
			print("SHIPYARD_STAGE layout")
			await _layout_checks(editor)
		Atomic.write("user://shipyard-presentation-restart.json", expected)
		editor.queue_free()
		await process_frame
	print(JSON.stringify({"test": "shipyard_presentation", "case": case_filter, "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _exchange_checks(editor: Control, role: String) -> void:
	var before: Dictionary = editor.blueprint.duplicate(true)
	var before_path: String = editor.current_path
	var source: Dictionary = Ship.template(role)
	source.revision = 1
	var package_api := preload("res://assembly/exchange/ship_blueprint_package.gd")
	var exported: Dictionary = package_api.export_blueprint(source)
	_expect(exported.ok, role + " received design fixture is valid")
	if not exported.ok: return
	var source_path: String = "user://int30-ship-ui-package-" + role + ".json"
	_expect(package_api.write_file(source_path, exported.package).ok, role + " received design fixture is written")
	await _click(_button(editor, "SHIP_EXCHANGE_IMPORT"))
	_expect(editor._exchange_dialog.visible and editor._exchange_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE, role + " import button opens input file dialog")
	editor._exchange_dialog.file_selected.emit(source_path)
	editor._exchange_dialog.hide()
	_expect(editor.blueprint == before and editor.current_path == before_path, role + " receiving a design leaves the open draft untouched")
	var imported: Dictionary = editor.import_portable_design(source_path)
	_expect(imported.ok and imported.code == "already_present", role + " duplicate revision import is a no-op")
	if not imported.ok: return
	var original_bytes: String = FileAccess.get_file_as_string(imported.path)
	_expect(editor.load_path(imported.path), role + " imported revision opens through the existing reader")
	editor._rename("INT30 changed received " + role)
	_expect(not editor.save_current() and FileAccess.get_file_as_string(imported.path) == original_bytes, role + " Save cannot overwrite an imported original")
	_expect(not editor.export_portable_design("user://int30-unsaved-ship-" + role + ".json").ok, role + " unsaved edits cannot export as a committed revision")
	await _click(_button(editor, "SY_COPY"))
	_expect(editor.current_path != imported.path and editor.blueprint.design_id != source.design_id and FileAccess.get_file_as_string(imported.path) == original_bytes, role + " Copy separates the editable design and preserves imported bytes")
	var destination: String = "user://int30-ship-ui-export-" + role + ".json"
	await _click(_button(editor, "SHIP_EXCHANGE_EXPORT"))
	_expect(editor._exchange_dialog.visible and editor._exchange_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE, role + " export button opens output file dialog")
	editor._exchange_dialog.file_selected.emit(destination)
	editor._exchange_dialog.hide()
	var received: Dictionary = package_api.read_file(destination)
	_expect(received.ok and received.package.design_id == editor.blueprint.design_id, role + " confirmed output dialog exports the copied committed revision")
	editor.load_path(before_path)
	_expect(_same_saved(editor.blueprint, before), role + " exchange test restores the pre-import authoring state")

func _model_checks() -> void:
	var host: Dictionary = Ship.template("expedition")
	var guest: Dictionary = Ship.template("lander")
	var a: Dictionary = host.duplicate(true)
	var b: Dictionary = guest.duplicate(true)
	var report: Dictionary = Present.hangar_report(host, guest)
	_expect(report.ok and report.result == Ship.find_hangar_fit(host, guest), "Fit report agrees with the production fit authority")
	_expect(report.text.contains("12,0 × 8,0 × 16,0") and report.text.contains("0°") and report.text.contains("90°"), "Report exposes interior axes and both unique orientations")
	_expect(host == a and guest == b, "Fit report leaves both source designs unchanged")
	for x in [4, 8, 12]: _add(guest, "cargo_s", Vector3(x, -2, 0))
	report = Present.hangar_report(host, guest)
	_expect(report.ok and report.result.yaw == 90 and report.text.contains("Überschreitung"), "Wide valid lander explains zero-degree rejection and quarter-turn success")
	# Both unique orientations fail for this connected but taller legal lander.
	var tall: Dictionary = Ship.template("lander")
	for y in [4, 6, 8]: _add(tall, "battery_s", Vector3(1, y, 0))
	_expect(Ship.evaluate(tall).ok, "Oversize hangar probe is a complete legal lander")
	report = Present.hangar_report(host, tall)
	_expect(not report.ok and report.code == "ship.hangar_too_small" and report.text.contains("Überschreitung"), "Failure explains excess dimensions without granting a fit")
	Ship.Assembly.remove_part(host, 6)
	report = Present.hangar_report(host, guest)
	_expect(not report.ok and report.text.contains("Entwurfsfehler") and report.text.contains("Hangar fehlt"), "Invalid counterpart reports concrete blocking design issues")
	var details: String = Present.module_details(Ship.Catalog.all().hangar)
	_expect(details.contains("100 t") and details.contains("15") and details.contains("12,0 × 8,0 × 16,0"), "Module details derive mass, draw and bay size from real catalogue")
	_expect(Present.error("ship.not_known").contains("ship.not_known"), "Unknown failure remains understandable and retains diagnostic code")

func _input_checks(editor: Control, role: String) -> void:
	editor.new_template(role)
	await _frames(3)
	var before: Dictionary = editor.blueprint.duplicate(true)
	var catalog_index: int = editor._module_ids.find("cargo_s")
	await _click_item(editor._catalog, catalog_index)
	_expect(editor._catalog_details.text.contains("12") and editor._ghost.visible, role + " pointer catalogue selection reveals cargo values and preview")
	await _click(editor._symmetry)
	_expect(editor._symmetry.button_pressed, role + " pointer enables symmetric build")
	# Hull's right face is clear for lander cargo; battery on a clear upper face for expedition.
	if role == "expedition":
		await _click_item(editor._catalog, editor._module_ids.find("battery_s"))
		await _click_item(editor._installed, 4)
	else:
		await _click_item(editor._installed, 0)
	var count: int = editor.blueprint.parts.size()
	await _click(editor._add_button)
	_expect(editor.blueprint.parts.size() == count + 2, role + " real Add installs a symmetric pair")
	var added: Dictionary = editor.blueprint.duplicate(true)
	await _click(_button(editor, "SY_UNDO"))
	_expect(editor.blueprint == before, role + " one real Undo removes the complete pair preserving identities")
	await _click(_button(editor, "SY_REDO"))
	_expect(editor.blueprint == added, role + " real Redo restores both exact modules")
	var index: int = editor.blueprint.parts.size() - 1
	await _click_item(editor._installed, index)
	var uid: String = editor.blueprint.parts[index].uid
	var previous_yaw: float = editor.blueprint.parts[index].rotation.y
	await _click(_button(editor, "SY_ROTATE"))
	_expect(editor.blueprint.parts[index].rotation.y == fposmod(previous_yaw + 90, 360) and editor.blueprint.parts[index].uid == uid, role + " real Rotate preserves module identity")
	await _key(KEY_Z, true)
	_expect(editor.blueprint.parts[index].rotation.y == previous_yaw, role + " Ctrl-Z restores rotation")
	await _key(KEY_Y, true)
	_expect(editor.blueprint.parts[index].rotation.y != previous_yaw, role + " Ctrl-Y reapplies rotation")
	await _key(KEY_DELETE)
	_expect(editor.blueprint.parts.size() == added.parts.size() - 1, role + " Delete removes the selected module")
	await _key(KEY_Z, true)
	_expect(editor.blueprint.parts.size() == added.parts.size() and editor.blueprint.parts[index].uid == uid, role + " Undo restores removed module ID")
	# Edit the real SpinBox LineEdit using typed text and Enter.
	await _click_item(editor._installed, index)
	var position: Vector3 = editor.blueprint.parts[index].position
	var line: LineEdit = editor._position_fields[0].get_line_edit()
	await _click(line)
	await _key(KEY_A, true)
	await _type(str(int(position.x) + 1))
	await _key(KEY_ENTER)
	_expect(editor.blueprint.parts[index].position.x == position.x + 1 and editor.blueprint.parts[index].uid == uid, role + " typing position moves the same module")
	line.release_focus()
	await _key(KEY_Z, true)
	_expect(editor.blueprint.parts[index].position == position, role + " Undo restores typed movement")
	# Save this edited design, then make a distinct copy using visible buttons.
	await _click(_button(editor, "SY_SAVE"))
	var original_path: String = editor.current_path
	var original_bytes: String = FileAccess.get_file_as_string(original_path)
	var original: Dictionary = editor.blueprint.duplicate(true)
	await _click(_button(editor, "SY_COPY"))
	var copy_path: String = editor.current_path
	var copy: Dictionary = editor.blueprint.duplicate(true)
	_expect(original_path != copy_path and original.design_id != copy.design_id and not editor.dirty, role + " real Copy creates its own saved design")
	_expect(FileAccess.get_file_as_string(original_path) == original_bytes and not editor.history.can_undo(), role + " copy preserves original bytes and separates history")
	for part: Dictionary in copy.parts: _expect(not _uids(original).has(part.uid), role + " copy module ID is independent")
	await _exchange_checks(editor, role)
	if DisplayServer.get_name() == "headless":
		# Headless Window has no client area; the native run covers picker input.
		var loaded_ok: bool = editor.load_path(original_path)
		_expect(loaded_ok and _same_saved(editor.blueprint, original), role + " reader reopens intact original (headless)")
	else:
		print("SHIPYARD_STAGE open picker " + role)
		await _click(_button(editor, "SY_OPEN"))
		await _library_ready(editor)
		var entry_index: int = -1
		for i in range(editor._library_entries.size()):
			if editor._library_entries[i].path == original_path: entry_index = i
		_expect(entry_index >= 0, role + " original is listed after copy")
		if entry_index >= 0:
			await _click_item(editor._library_list, entry_index)
			print("SHIPYARD_STAGE use picker " + role)
			await _click(_button(editor._library, "SY_USE"))
			print("SHIPYARD_STAGE used picker " + role)
			_expect(_same_saved(editor.blueprint, original) and editor.current_path == original_path, role + " real picker reopens original with all parts intact")
	expected[role] = {"original": original_path, "copy": copy_path, "original_id": original.design_id,
		"copy_id": copy.design_id, "original_uids": _uids(original), "copy_uids": _uids(copy), "original_sha256": original_bytes.sha256_text()}
	print("SHIPYARD_STAGE dirty guard " + role)
	# Failed opening or switching must not replace a dirty source.
	await _click_item(editor._installed, 0)
	await _click(_button(editor, "SY_ROTATE"))
	var dirty_source: Dictionary = editor.blueprint.duplicate(true)
	await _click(_button(editor, "SY_NEW_LANDER" if role == "expedition" else "SY_NEW_EXPEDITION"))
	_expect(editor._confirmation.visible and editor.blueprint == dirty_source, role + " new design click protects dirty draft")
	if DisplayServer.get_name() == "headless":
		editor._confirmation.canceled.emit()
		editor._confirmation.hide()
	else:
		await _click(editor._confirmation.get_cancel_button())
	_expect(not editor._confirmation.visible and editor.blueprint == dirty_source, role + " real Cancel keeps dirty draft")
	print("SHIPYARD_STAGE input complete " + role)

func _language_checks(editor: Control) -> void:
	editor.new_template("expedition")
	await _click_item(editor._catalog, editor._module_ids.find("hangar"))
	await _click_item(editor._installed, 6)
	var before: Dictionary = editor.blueprint.duplicate(true)
	var builds: int = editor.mesh_build_count
	var evaluations: int = editor.evaluation_count
	for locale: String in ["en", "de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		await _frames(3)
		_expect(editor.blueprint == before and editor.selected == 6 and not editor.dirty, "Language " + locale + " leaves draft and module selection untouched")
		_expect(editor.mesh_build_count == builds and editor.evaluation_count == evaluations, "Language " + locale + " does not rebuild full ship or capabilities")
		_expect(_button(editor, "SY_COPY").text == Text.text("SY_COPY") and editor._category.get_item_text(3) == Text.text("SY_CATEGORY_POWER"), "Language " + locale + " updates controls and filter captions")
		_expect(editor._module_title.text.contains(Present.module_name("hangar")) and editor._module_details.text.contains(Text.format_text("SY_STAT_MASS", {"value": 100})), "Language " + locale + " updates module name and real values")
		await _capture("shipyard-details-" + locale)
	# Picking empty space clears selection without editing the draft.
	await _click_at(editor._viewport_container.global_position + Vector2(5, 5), root)
	_expect(editor.selected == -1 and editor._module_details.text.is_empty(), "Empty-space pointer selection clears module details")
	_expect(editor._selection_actions.all(func(button: Button) -> bool: return button.disabled) and editor._position_fields.all(func(field: SpinBox) -> bool: return not field.editable), "No selection disables transforms and removal")
	_expect(editor.blueprint == before and not editor.dirty, "Clearing selection never edits the draft")
	# Filter must use the model category, not the translated caption.
	editor._category.select(3)
	editor._category.item_selected.emit(3)
	_expect(editor._module_ids.has("reactor_l") and editor._module_ids.has("battery_s") and not editor._module_ids.has("hangar"), "English power filter retains the catalogue category mapping")
	editor._search.text = "battery"
	editor._search.text_changed.emit("battery")
	_expect(editor._module_ids == ["battery_s"], "Search uses the localized English module name")
	root.get_node("LocaleManager")._apply("de")
	await _frames(2)
	_expect(editor._module_ids.is_empty() and editor._add_button.disabled, "Language change with no search match cannot add a stale module")
	await _click(_button(editor, "SY_COPY"))
	var bytes: String = FileAccess.get_file_as_string(editor.current_path)
	root.get_node("LocaleManager")._apply("en")
	await _frames(2)
	_expect(FileAccess.get_file_as_string(editor.current_path) == bytes, "Language change never writes stored names, IDs or revisions")

func _issue_checks(editor: Control) -> void:
	root.get_node("LocaleManager")._apply("en")
	editor.new_template("lander")
	await _click_item(editor._installed, 3)
	await _click(_button(editor, "SY_REMOVE"))
	_expect(not editor._evaluation.ok and editor._issue_count.text.contains("1"), "Real reactor removal produces an unresolved power issue")
	await _click_item(editor._issues, 0)
	_expect(editor._issue_details.text.contains("Power generation") and editor._issue_details.text.contains("Compare generated"), "Issue click shows cause and actionable guidance")
	await _capture("shipyard-issue-power-en")
	await _click(_button(editor, "SY_UNDO"))
	_expect(editor._evaluation.ok and editor._issue_details.text.is_empty(), "Undo clears obsolete issue details")
	editor.select_part(1)
	var candidate: Dictionary = editor.blueprint.duplicate(true)
	candidate.parts[1].position = Vector3.ZERO
	editor._edit(candidate, "SY_EDIT_MOVE")
	var overlap_index: int = -1
	for i in range(editor._issues.item_count):
		var issue: Dictionary = editor._issues.get_item_metadata(i)
		if issue.code == "ship.overlap": overlap_index = i
	_expect(overlap_index >= 0, "Overlap remains an editable draft issue")
	if overlap_index >= 0:
		await _click_item(editor._issues, overlap_index)
		_expect(editor.selected == 0 and editor._issue_details.text.contains("#01") and editor._issue_details.text.contains("#02"), "Issue click selects affected module and identifies both overlapping parts")
		await _capture("shipyard-issue-overlap-en")
	# Failed IO retains the whole active draft.
	var before: Dictionary = editor.blueprint.duplicate(true)
	_expect(not editor.load_path("user://missing-shipyard-int30.json") and editor.blueprint == before, "Failed open keeps current draft")
	await _click(_button(editor, "SY_SAVE"))
	var original_bytes: String = FileAccess.get_file_as_string(editor.current_path)
	var path: String = editor.current_path
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	await _click(_button(editor, "SY_SAVE"))
	_expect(FileAccess.get_file_as_string(path) == original_bytes and editor._status.text.contains("Save failed"), "Failed writer preserves bytes and displays translated error")
	DirAccess.remove_absolute(path + ".tmp")

func _fit_checks(editor: Control) -> void:
	editor.new_template("lander")
	await _click(_button(editor, "SY_SAVE"))
	var guest_path: String = editor.current_path
	editor.new_template("expedition")
	var before: Dictionary = editor.blueprint.duplicate(true)
	await _click(_button(editor, "SY_CHECK_FIT"))
	await _library_ready(editor)
	var found: int = -1
	for i in range(editor._library_entries.size()):
		if editor._library_entries[i].path == guest_path: found = i
	_expect(found >= 0, "Real hangar picker lists the saved opposite-role design")
	if found >= 0:
		if DisplayServer.get_name() == "headless":
			editor._activate_library(found)
		else:
			await _click_item(editor._library_list, found)
			await _click(_button(editor._library, "SY_USE"))
		await _frames(3)
		_expect(editor.blueprint == before and not editor.dirty, "Real fit picker does not open or mutate the host")
		_expect(editor._fit.text.contains("fits in") and editor._fit.text.contains("12.0 × 8.0 × 16.0") and editor._fit.text.contains("Clearance per side"), "Real fit explains interior, orientation and per-side clearance")
		var scroll := editor._fit.get_parent().get_parent() as ScrollContainer
		_expect(editor._fit.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "Completed hangar report is revealed after layout")
		await _capture("shipyard-fit-en")
		root.get_node("LocaleManager")._apply("de")
		await _frames(2)
		_expect(editor._fit.text.contains("passt in") and editor._fit.text.contains("Freiraum je Seite"), "Live language change retains and translates completed fit report")
		await _capture("shipyard-fit-de")
	await _click_item(editor._installed, 6)
	await _click(_button(editor, "SY_REMOVE"))
	_expect(editor._fit_pair.is_empty() and not editor._fit.text.contains("passt in"), "Geometry edit invalidates stale successful fit")

func _layout_checks(editor: Control) -> void:
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		for dimensions: Vector2i in [Vector2i(960, 640), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = dimensions
			for role: String in ["expedition", "lander"]:
				editor.new_template(role)
				await _frames(5)
				editor.frame_design()
				_expect(editor.size.x <= dimensions.x + 1 and editor._status.get_global_rect().end.y <= dimensions.y + 1, "Layout fits " + locale + " " + str(dimensions))
				_expect(editor._viewport_container.size.x >= 220, "Viewport usable " + locale + " " + str(dimensions))
				await _capture("shipyard-%s-%s-%dx%d" % [role, locale, dimensions.x, dimensions.y])

func _button(node: Node, key: String) -> Button:
	if node is Button and node.get_meta("shipyard_text_key", "") == key: return node
	for child: Node in node.get_children():
		var found: Button = _button(child, key)
		if found != null: return found
	return null

func _reveal(control: Control) -> void:
	# Wait for template/language reflow before computing scroll and hit positions.
	await _frames(2)
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await _frames(2)

func _click(control: Control) -> void:
	_expect(control != null, "Requested input control exists")
	if control == null: return
	await _reveal(control)
	var position: Vector2 = control.get_global_rect().get_center()
	if control.get_window() != root: position += Vector2(control.get_window().position)
	await _click_at(position, root)

func _click_at(position: Vector2, viewport: Viewport) -> void:
	for pressed: bool in [true, false]:
		var motion := InputEventMouseMotion.new()
		motion.position = position
		viewport.push_input(motion, true)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		viewport.push_input(event, true)
		await process_frame
	await _frames(2)

func _click_item(list: ItemList, index: int) -> void:
	_expect(index >= 0 and index < list.item_count, "Requested item is available")
	if index < 0 or index >= list.item_count: return
	await _reveal(list)
	# Scroll first, then send actual pointer events to the visible row.
	var rect: Rect2 = list.get_item_rect(index)
	list.get_v_scroll_bar().value = maxf(rect.position.y - 20, 0)
	await _frames(2)
	rect = list.get_item_rect(index)
	var position: Vector2 = list.global_position + rect.get_center() - Vector2(0, list.get_v_scroll_bar().value)
	_expect(list.get_item_at_position(position - list.global_position) == index, "Pointer target matches requested row")
	if list.get_window() != root: position += Vector2(list.get_window().position)
	_expect(root.get_visible_rect().has_point(position), "Requested pointer row lies inside the root viewport")
	await _click_at(position, root)

func _key(code: Key, ctrl: bool = false, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		event.ctrl_pressed = ctrl
		event.shift_pressed = shift
		root.push_input(event, true)
		await process_frame
	await _frames(2)

func _type(value: String) -> void:
	for character: String in value:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = character.unicode_at(0)
		root.push_input(event, true)
		await process_frame
	await process_frame

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _library_ready(editor: Control) -> void:
	for i in range(120):
		await process_frame
		if not editor._library_loading: break
	_expect(not editor._library_loading, "Bounded library query completes")
	await _frames(3)

func _capture(name: String) -> void:
	if capture_directory.is_empty(): return
	_expect(DisplayServer.get_name() != "headless", "Capture uses a real renderer")
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_directory.path_join(name + ".png")) == OK, "Rendered view saved " + name)

func _uids(data: Dictionary) -> Array:
	var result: Array = []
	for part: Dictionary in data.parts: result.append(part.uid)
	return result

func _add(data: Dictionary, id: String, position: Vector3) -> void:
	var index: int = Ship.Assembly.add_part(data, id, position)
	data.parts[index].part_revision = Ship.Catalog.REVISION

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _same_saved(a: Dictionary, b: Dictionary) -> bool:
	# JSON readers represent integers as doubles. Compare the complete persisted
	# representation; do not change the released codec or weaken ID/content checks.
	return Atomic.parse_dictionary(Atomic.stringify(Ship.Assembly.serialize(a))) == Atomic.parse_dictionary(Atomic.stringify(Ship.Assembly.serialize(b)))
