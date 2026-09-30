extends SceneTree
const LibraryPanel = preload("res://ui/blueprints/creature_library_panel.gd")
const Library = LibraryPanel.Library
const Package = LibraryPanel.Package
const Starter = LibraryPanel.Starter
const Creature = Package.Creature
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []
var checks: int = 0
var current: Dictionary
var chosen: Array[Dictionary] = []
var capture_dir: String = ""
var preparation_calls: int = 0


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	root.gui_embed_subwindows = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		_expect(DisplayServer.get_name() != "headless", "Render evidence requires a real display")
	# Exact companion catalog rows, until Chat 1 has appended them centrally.
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/int30-design-library/catalog-append.json"))
	for locale: String in ["de", "en"]:
		var translation := Translation.new()
		translation.set_locale(locale)
		for row: Dictionary in rows: translation.add_message(row.key, row[locale])
		TranslationServer.add_translation(translation)
	root.get_node("LocaleManager")._apply("de")
	await _frames(3)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	current = Creature.create_default()
	var original: Dictionary = current.duplicate(true)
	var state: Dictionary = root.get_node("GameState").export_state()
	var progression: Dictionary = root.get_node("ProgressionService").export_state()
	var empty := _panel("user://int30-empty.json")
	await _frames(4)
	_expect(empty._entries.size() == 3 and not FileAccess.file_exists(empty.library_path), "Empty library must retain starters without writing a file")
	empty._filter.select(2)
	empty._filter.item_selected.emit(2)
	_expect(empty._visible_keys.is_empty() and empty._use.disabled and empty._selection_notice.visible, "Empty local filter retained invisible adoption")
	await _capture("empty-local-de")
	empty.queue_free()
	await _frames(3)
	var path := "user://int30-picker.json"
	var a: Dictionary = _package("same-a", "Gleicher {name}")
	var b: Dictionary = _package("same-b", "Gleicher {name}")
	var revision: Dictionary = b.duplicate(true)
	revision.revision = 2
	var locked: Dictionary = _locked_package()
	for package: Dictionary in [b, a, revision, locked]:
		_expect(Library.add(package, path).ok, "Fixture rejected " + str(package.design_id))
	var bytes: String = FileAccess.get_file_as_string(path)
	var panel := _panel(path)
	await _frames(4)
	_expect(LibraryPanel.Presentation.compare(current, current.duplicate(true)).contains(LibraryPanel.Text.text("BP_CHANGE_NONE")), "Identical body reported differences")
	await _click(panel.find_child("Template_3", true, false))
	_expect(panel._selected == "builtin/starter_moss@1", "Default order changed starter mouse selection")
	_expect(panel._comparison.text.contains("→") and not panel._comparison.text.contains("BP_"), "Before-adoption comparison missing or untranslated")
	await _capture("starter-comparison-de")
	panel._select("same-b@2")
	panel._preview._angle = 1.1
	panel._preview._zoom = 1.25
	await _option(panel._sort, 1)
	_expect(panel._sort.selected == 1 and panel._selected == "same-b@2", "Mouse/key sort reset revision selection")
	_expect(panel._preview._angle == 1.1 and panel._preview._zoom == 1.25, "Sort reset preview camera")
	var calls_before: int = preparation_calls
	panel._build_list()
	_expect(preparation_calls == calls_before, "Unchanged search/sort context repeated package preparation")
	var index_a: int = panel._visible_keys.find("same-a@1")
	var index_b: int = panel._visible_keys.find("same-b@1")
	_expect(index_a >= 0 and index_a < index_b, "Equal-title sort lacks stable ID tie break")
	_expect(panel._origin.text.contains("same-b") and panel._origin.text.contains("Revision 2"), "Same names cannot be distinguished by ID/revision")
	await _option(panel._sort, 2)
	_expect(panel._visible_keys[0] == "same-b@2", "Highest revision sort ignored revision")
	await _option(panel._sort, 3)
	_expect(panel._visible_keys.back() == "locked@1", "Usability sort ignored actual locked parts")
	panel._select("locked@1")
	var blocked: Dictionary = Starter.prepare(locked, current)
	print("INT30_LOCKED_DIAGNOSTIC " + JSON.stringify({"result": blocked, "requirements": panel._requirements.text, "disabled": panel._use.disabled}))
	_expect(blocked.code == "locked_parts", "Fixture must exercise real locked parts")
	_expect(panel._use.disabled and panel._requirements.text.contains(LibraryPanel.Presentation.part_name(str(blocked.get("missing_parts", [""])[0]))), "Locked parts were hidden or adoption enabled")
	await _capture("locked-template-de")
	panel._select("same-a@1")
	await _click(panel._favorite)
	await _click(panel._favorites_only)
	_expect(panel._visible_keys == ["same-a@1"], "Sort did not compose with favorites")
	panel._search.text = "unmatched"
	panel._search.text_changed.emit(panel._search.text)
	_expect(panel._use.disabled and panel._selection_notice.visible, "Search retained hidden adoption")
	panel._choose()
	_expect(chosen.is_empty(), "Hidden selection emitted a package")
	panel._search.text = " same-a "
	panel._search.text_changed.emit(panel._search.text)
	_expect(panel._visible_keys == ["same-a@1"] and not panel._use.disabled, "Search by stable identity failed")
	await _click(panel._use)
	_expect(chosen.size() == 1 and Package.same_content(chosen[0], a), "Selected identical name resolved to another design")
	chosen.clear()
	root.get_node("GameState").current_phase = 1
	panel._build_list()
	_expect(panel._use.disabled and panel._requirements.text == LibraryPanel.Text.format_text("BP_COMPLEXITY", {"count": Package.inspect(a).stats.complexity, "limit": Package.inspect(a).stats.complexity_limit}) + "\n" + LibraryPanel.Text.text("BP_ERROR_PHASE"), "Context cache retained previous-phase usability")
	root.get_node("GameState").current_phase = 0
	panel._build_list()
	_expect(not panel._use.disabled, "Context cache retained phase restriction")
	await _click(panel._favorites_only)
	panel._search.clear()
	panel._search.text_changed.emit("")
	panel._variant_name.text = "Eigene Variante"
	await _click(panel.find_child("SaveVariant", true, false))
	var variant_key: String = panel._selected
	print("INT30_VARIANT_DIAGNOSTIC " + JSON.stringify({"key": variant_key, "origin": panel._origin.text, "current_id": current.design_id, "result": panel._last_result}))
	_expect(variant_key != str(current.design_id) + "@1" and panel._origin.text.contains(str(current.design_id)), "Variant overwrote original or omitted actual provenance")
	_expect(current == original, "Saving a variant mutated current design")
	await _reveal(panel._origin)
	await _capture("variant-origin-de")
	# External change of an immutable key is shown again, never silently adopted.
	panel._select("same-a@1")
	var data: Dictionary = Library.read(path)
	for package: Dictionary in data.packages:
		if package.design_id == "same-a": package.description = "Extern geändert"
	Atomic.write(path, {"schema": Library.SCHEMA, "packages": data.packages, "favorites": data.favorites})
	await _click(panel._use)
	_expect(chosen.is_empty() and panel._last_result.code == "selection_changed" and panel._origin.text.contains("Extern geändert"), "Changed revision was adopted before review")
	await _click(panel._use)
	_expect(chosen.size() == 1 and chosen[0].description == "Extern geändert", "Reviewed external template cannot be used")
	chosen.clear()
	current.appearance.base_color = "ff00aa"
	await _click(panel._use)
	_expect(chosen.is_empty() and panel._last_result.code == "selection_changed", "Changed receiver bypassed comparison refresh")
	current = original.duplicate(true)
	panel._select(variant_key)
	bytes = FileAccess.get_file_as_string(path)
	for malformed: Variant in ["{broken", {"schema": 999}, _bad_part_package(a)]:
		var source := "user://int30-bad-import.json"
		var content: String = malformed if malformed is String else JSON.stringify(malformed)
		var file := FileAccess.open(source, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		panel._file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		panel._file_selected(source)
		_expect(not panel._last_result.ok and FileAccess.get_file_as_string(path) == bytes and FileAccess.get_file_as_string(source) == content, "Invalid import changed originals/library")
		if malformed is Dictionary and malformed.has("blueprint"):
			_expect(panel._status.text.contains("absent_part"), "Unavailable part identity is missing from error")
		_expect(current == original, "Invalid package changed current blueprint")
	await _capture("invalid-import-de")
	panel._select("same-b@2")
	await _sizes(panel)
	panel.queue_free()
	await _frames(3)
	# Corrupt/future local libraries are read-only, with usable starter fallback.
	for corrupt: String in ["{broken", '{"schema":99,"packages":[]}']:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(corrupt)
		file.close()
		panel = _panel(path)
		await _frames(3)
		_expect(panel._entries.size() == 3 and panel._favorite.disabled and not panel._use.disabled, "Protected local library disabled starter fallback or allowed metadata write")
		_expect(FileAccess.get_file_as_string(path) == corrupt, "Read repaired a protected original")
		panel.queue_free()
		await _frames(3)
	_expect(root.get_node("GameState").export_state() == state and root.get_node("ProgressionService").export_state() == progression and current == original, "Browsing/sorting/import changed campaign/progression/original")
	for failure: String in failures: push_error(failure)
	print("INT30_DESIGN_LIBRARY_RESULT " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method()}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _panel(path: String) -> Control:
	var panel := LibraryPanel.new()
	panel.library_path = path
	panel.capture_current = func() -> Dictionary: return current.duplicate(true)
	panel.prepare_template = func(package: Dictionary) -> Dictionary:
		preparation_calls += 1
		return Starter.for_editor(Package.prepare_import(package, current, int(root.get_node("GameState").current_phase), Starter.unlocked_parts()))
	panel.template_chosen.connect(func(package: Dictionary): chosen.append(package))
	root.add_child(panel)
	return panel


func _package(id: String, title: String) -> Dictionary:
	var package: Dictionary = Starter.packages()[0].duplicate(true)
	package.design_id = id
	package.title = title
	package.author = "Autor {revision}"
	return JSON.parse_string(JSON.stringify(package))


func _locked_package() -> Dictionary:
	var blueprint: Dictionary = Creature.create_default()
	blueprint.design_id = "locked"
	blueprint.assembly.revision = 1
	for part: Dictionary in Package.Parts.get_parts_for_category("wings"):
		if not part.id in Starter.unlocked_parts():
			Creature.BaseBlueprint.add_part(blueprint, part.id)
			break
	var result: Dictionary = Package.export_blueprint(blueprint, {"title": "Gesperrte Flügel"})
	_expect(result.ok, "Cannot create locked fixture")
	return result.get("package", {})


func _bad_part_package(source: Dictionary) -> Dictionary:
	var bad: Dictionary = source.duplicate(true)
	bad.blueprint.parts[0].part_id = "absent_part"
	bad.required_parts = Package._requirements(bad.blueprint)
	return bad


func _sizes(panel: Control) -> void:
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.25, 1.5]:
			for locale: String in ["de", "en"]:
				print("INT30_LAYOUT " + JSON.stringify({"size": str(dimensions), "scale": scale, "locale": locale}))
				root.get_node("LocaleManager")._apply(locale)
				root.size = dimensions
				root.content_scale_size = dimensions
				root.content_scale_factor = scale
				panel._show_detail = false
				panel._layout()
				await _frames(4)
				_expect(root.size == dimensions, "Requested window size was not applied")
				await _reveal(panel._sort)
				_expect(_onscreen(panel._sort), "Sort unreachable at %s/%s/%s" % [dimensions, scale, locale])
				if dimensions == Vector2i(800, 600) and scale == 1.5:
					await _capture("small-list-%s-150" % locale)
				panel._show_detail = true
				panel._layout()
				await _frames(4)
				_expect(_onscreen(panel._use) and _onscreen(panel._favorite), "Footer unreachable at %s/%s/%s" % [dimensions, scale, locale])
				await _reveal(panel._comparison)
				_expect(not panel._comparison.text.contains("BP_") and panel._origin.text.contains("Autor {revision}"), "Language changed literal data or left untranslated comparison")
				if dimensions == Vector2i(800, 600) and scale == 1.5:
					var scroll: ScrollContainer = panel._comparison.get_parent().get_parent()
					scroll.scroll_vertical = 0
					await _frames(2)
					await _capture("small-detail-%s-150" % locale)
	root.content_scale_factor = 1.0


func _option(control: OptionButton, index: int) -> void:
	await _click(control)
	var popup: PopupMenu = control.get_popup()
	await _frames(2)
	var style: StyleBox = popup.get_theme_stylebox("panel")
	var top: float = style.get_content_margin(SIDE_TOP)
	var bottom: float = style.get_content_margin(SIDE_BOTTOM)
	var row_height: float = (float(popup.size.y) - top - bottom) / popup.item_count
	var point := Vector2(popup.position) + Vector2(popup.size.x * 0.5, top + row_height * (index + 0.5))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await _frames(3)
	print("INT30_SORT_DIAGNOSTIC " + JSON.stringify({"expected": index, "actual": control.selected, "popup": popup.visible}))


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)


func _reveal(control: Control) -> void:
	await _frames(2)
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _frames(3)


func _click(control: Control) -> void:
	await _reveal(control)
	if control.name == "SaveVariant":
		print("INT30_CLICK_DIAGNOSTIC " + JSON.stringify({"rect": str(control.get_global_rect()), "viewport": str(root.get_visible_rect()), "visible": control.is_visible_in_tree()}))
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await _frames(3)


func _onscreen(control: Control) -> bool:
	return control.is_visible_in_tree() and root.get_visible_rect().encloses(control.get_global_rect())


func _frames(count: int) -> void:
	for frame in range(count): await process_frame


func _capture(label: String) -> void:
	if capture_dir.is_empty(): return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await _frames(3)
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "Capture failed")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
