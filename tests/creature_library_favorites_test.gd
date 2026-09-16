extends SceneTree
const Library = preload("res://assembly/exchange/creature_design_library.gd")
const Starter = preload("res://assembly/exchange/creature_start_templates.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const LibraryPanel = preload("res://ui/blueprints/creature_library_panel.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	if "--favorites-restart" in OS.get_cmdline_user_args():
		var stored: Dictionary = Library.read("user://favorites-test.json")
		_expect(stored.ok and stored.favorites.size() == 2, "Fresh process lost bookmarks")
		_expect(stored.ok and stored.favorites.has("local-1@1") and stored.favorites.has("builtin/starter_meadow@1"), "Fresh process changed bookmark identities")
		_expect(Library.get_package("local-1@1", "user://favorites-test.json").ok, "Favorite lost its offline package")
	else:
		_model()
		await _ui()
	for failure in failures: push_error(failure)
	print("CREATURE_LIBRARY_FAVORITES_PASSED checks=%d" % checks if failures.is_empty() else "CREATURE_LIBRARY_FAVORITES_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _package(id: String, title: String = "Meine {name} Kreatur") -> Dictionary:
	var package: Dictionary = Starter.packages()[0].duplicate(true)
	package.design_id = id
	package.title = title
	package.description = "Wanderer durch das Nadelöhr"
	package.tags = ["Sumpf", "Wasser"]
	# Schema-1 Library.add canonicalized packages through the portable JSON
	# representation before writing them with AtomicJson's scalar precision.
	return JSON.parse_string(JSON.stringify(package))

func _model() -> void:
	var path := "user://favorites-test.json"
	var first: Dictionary = _package("local-1")
	var second: Dictionary = _package("local-2")
	_expect(Atomic.write(path, {"schema": 1, "packages": [first, second]}, false) == OK, "Cannot write old-format fixture")
	var bytes: String = FileAccess.get_file_as_string(path)
	var stored: Dictionary = Library.read(path)
	_expect(stored.ok and stored.favorites.is_empty() and FileAccess.get_file_as_string(path) == bytes, "Reading old library rewrote it or invented favorites")
	_expect(Library.add(first, path).code == "already_present" and FileAccess.get_file_as_string(path) == bytes, "Idempotent import unexpectedly migrated old file")
	_expect(Library.set_favorite("local-1@1", true, path).ok, "Cannot favorite local revision")
	stored = Library.read(path)
	_expect(stored.ok and stored.packages == JSON.parse_string(bytes).packages and stored.favorites == ["local-1@1"], "Favorite migration changed packages or marked equal titles")
	_expect(Atomic.parse_dictionary(FileAccess.get_file_as_string(path)).schema == 2 and FileAccess.get_file_as_string(path + ".bak") == bytes, "Migration lost schema-1 backup")
	bytes = FileAccess.get_file_as_string(path)
	_expect(Library.set_favorite("local-1@1", true, path).ok and FileAccess.get_file_as_string(path) == bytes, "Repeated bookmark rewrote file")
	var revised: Dictionary = first.duplicate(true)
	revised.revision = 2
	_expect(Library.add(revised, path).ok and Library.read(path).favorites == ["local-1@1"], "New revision inherited old bookmark")
	_expect(Library.set_favorite("builtin/starter_meadow@1", true, path).ok, "Cannot favorite built-in starter")
	var starter: Dictionary = Starter.packages()[0]
	_expect(Library.add(starter, path).ok and not Library.read(path).favorites.has("starter_meadow@1"), "Local starter copy stole built-in bookmark")
	# ':' is valid in downloaded design IDs; '/' is not. This used to collide
	# with the UI's built-in prefix, so exercise an otherwise valid local ID.
	var named_like_builtin: Dictionary = _package("builtin:starter_meadow")
	_expect(Library.add(named_like_builtin, path).ok and Library.set_favorite("builtin:starter_meadow@1", true, path).ok, "Valid colon-containing local ID collided with a built-in")
	_expect(Library.read(path).favorites.has("builtin/starter_meadow@1") and Library.read(path).favorites.has("builtin:starter_meadow@1"), "Built-in and local favorite identities alias")
	Library.set_favorite("builtin:starter_meadow@1", false, path)
	_expect(Library.set_favorite("missing@1", true, path).code == "template_missing" and Library.set_favorite("builtin/starter_meadow@999", true, path).code == "template_missing", "Missing revision accepted favorite")
	var exported_before: Dictionary = Library.get_package("local-1@1", path).package
	_expect(Package.write_file("user://favorite-export.json", exported_before).ok, "Cannot export favorite")
	_expect(Package.read_file("user://favorite-export.json").package == exported_before and not exported_before.has("favorites"), "Favorite leaked into portable package")
	var imported := "user://other-installation.json"
	_expect(Library.import_file("user://favorite-export.json", imported).ok and Library.read(imported).favorites.is_empty(), "Import copied device favorites")
	DirAccess.remove_absolute("user://favorite-export.json")
	var variant: Dictionary = Library.save_variant(Package.inspect(first).preview, "Favorite variant", path)
	_expect(variant.ok and not Library.read(path).favorites.has(variant.get("key", "")), "Variant inherited source bookmark")
	bytes = FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(path + ".tmp")
	_expect(not Library.set_favorite("local-2@1", true, path).ok and FileAccess.get_file_as_string(path) == bytes, "Failed write published favorite or damaged library")
	_expect(not Library.remove("local-1@1", path).ok and FileAccess.get_file_as_string(path) == bytes, "Failed removal separated template from favorite")
	DirAccess.remove_absolute(path + ".tmp")
	_expect(Library.set_favorite("local-2@1", true, path).ok and Library.remove("local-2@1", path).ok, "Cannot remove bookmarked local template")
	_expect(not Library.read(path).favorites.has("local-2@1") and not Library.get_package("local-2@1", path).ok, "Removal left orphan metadata")
	_expect(Library.add(second, path).ok and not Library.read(path).favorites.has("local-2@1"), "Reimport revived deleted bookmark")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/creature_library_favorites_test.gd", "--", "--favorites-restart"], output, true)
	_expect(code == 0 and str(output).contains("CREATURE_LIBRARY_FAVORITES_PASSED") and not str(output).contains("ERROR:"), "Favorite restart failed: " + str(output).right(1000))
	# Bad metadata and future originals block every library mutation, even with
	# an older valid backup. The caller can still use authored starter templates.
	for record: Dictionary in [
		{"schema": true, "packages": []},
		{"schema": "2", "packages": [first], "favorites": []},
		{"schema": 99, "packages": [first], "favorites": []},
		{"schema": 2, "packages": [first], "favorites": ["local-1@1", "local-1@1"]},
		{"schema": 2, "packages": [first], "favorites": ["missing@1"]},
		{"schema": 2, "packages": [first], "favorites": {"local-1@1": true}},
		{"schema": 2, "packages": [first], "favorites": ["builtin/starter_meadow@-1"]},
		{"schema": 2, "packages": [first], "favorites": ["builtin/starter_meadow@01"]},
		{"schema": 2, "packages": [first], "favorites": [], "campaign": {}},
	]:
		var bad := "user://bad-favorites.json"
		Atomic.write(bad + ".bak", {"schema": 1, "packages": [first]}, false)
		Atomic.write(bad, record, false)
		bytes = FileAccess.get_file_as_string(bad)
		_expect(not Library.read(bad).ok and not Library.set_favorite("local-1@1", true, bad).ok and not Library.add(second, bad).ok and not Library.remove("local-1@1", bad).ok, "Protected library accepted mutation")
		_expect(FileAccess.get_file_as_string(bad) == bytes, "Invalid/future original overwritten or restored from backup")
	var empty_path := "user://starter-only-favorites.json"
	_expect(Library.set_favorite("builtin/starter_moss@1", true, empty_path).ok and Library.read(empty_path).packages.is_empty(), "Starter bookmark imported a local package")
	_expect(Library.set_favorite("builtin/starter_moss@1", false, empty_path).ok and Library.read(empty_path).favorites.is_empty(), "Cannot unmark starter")

func _ui() -> void:
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	var state_before: Dictionary = state.export_state()
	var progress_before: Dictionary = progression.export_state()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var first: Dictionary = _package("ui-local-1")
	var path := "user://favorites-ui.json"
	Library.add(first, path)
	var panel := LibraryPanel.new()
	panel.library_path = path
	panel.start_mode = true
	panel.prepare_template = func(package: Dictionary) -> Dictionary: return Starter.prepare(package, Creature.create_default())
	root.add_child(panel)
	await _frames(4)
	panel._select("ui-local-1@1")
	panel._preview._angle = 1.1
	panel._preview._zoom = 1.25
	await _click(panel._favorite)
	_expect(Library.read(path).favorites == ["ui-local-1@1"] and panel._favorite.button_pressed, "Favorite control did not persist local selection")
	_expect(panel._preview._angle == 1.1 and panel._preview._zoom == 1.25 and panel._selected == "ui-local-1@1", "Bookmark reset preview or selection")
	await _click(panel._favorites_only)
	_expect(_buttons(panel).size() == 1 and _buttons(panel)[0].get_meta("template_key") == "ui-local-1@1", "Favorites view contains unmarked templates")
	for term: String in ["  SUMPF ", "Nadelöhr", "{name}"]:
		panel._search.text = term
		panel._search.text_changed.emit(term)
		_expect(_buttons(panel).size() == 1, "Extended search missed tag/description/literal title: " + term)
	panel._search.text = "Sumpf"
	panel._search.text_changed.emit("Sumpf")
	for language: String in ["de", "en", "de"]:
		root.get_node("LocaleManager")._apply(language)
		await _frames(3)
		_expect(panel._favorites_only.button_pressed and panel._search.text == "Sumpf" and panel._selected == "ui-local-1@1", "Language change reset filters/selection")
		_expect(panel._name.text == first.title and panel._preview._angle == 1.1 and panel._preview._zoom == 1.25, "Language change rewrote name or camera")
		_expect(not panel._favorite.text.begins_with("BP_") and not panel._favorites_only.text.begins_with("BP_"), "Favorite controls untranslated")
	panel._filter.select(1)
	panel._filter.item_selected.emit(1)
	_expect(_buttons(panel).is_empty(), "Favorites ignored source filter")
	panel._filter.select(2)
	panel._filter.item_selected.emit(2)
	_expect(_buttons(panel).size() == 1, "Local favorite cannot be found with combined filters")
	# A write failure must revert the pressed state and leave preview/use intact.
	DirAccess.make_dir_absolute(path + ".tmp")
	await _click(panel._favorite)
	_expect(not panel._last_result.ok and panel._favorite.button_pressed and panel._favorites.has("ui-local-1@1") and not panel._use.disabled, "Failed favorite toggle lied or disabled template use")
	DirAccess.remove_absolute(path + ".tmp")
	await _click(panel._favorite)
	_expect(panel._last_result.ok and not panel._favorite.button_pressed and _buttons(panel).is_empty(), "Unmark did not update active favorites filter")
	await _click(panel._favorite)
	await _sizes(panel)
	panel.queue_free()
	await _frames(3)
	var reopened := LibraryPanel.new()
	reopened.library_path = path
	reopened.prepare_template = func(package: Dictionary) -> Dictionary: return Starter.prepare(package, Creature.create_default())
	root.add_child(reopened)
	await _frames(3)
	_expect(reopened._favorites.has("ui-local-1@1"), "Reopened picker lost favorite")
	reopened._select("builtin/starter_meadow@1")
	await _click(reopened._favorite)
	_expect(Library.read(path).favorites.has("builtin/starter_meadow@1") and not reopened._use.disabled, "Starter favorite bypassed or broke preparation")
	var chosen: Array[Dictionary] = []
	reopened.template_chosen.connect(func(package: Dictionary) -> void: chosen.append(package))
	await _click(reopened._use)
	_expect(chosen.size() == 1 and chosen[0] == Starter.packages()[0], "Using favorite changed portable design")
	# Future local metadata disables bookmark writes, never the built-in fallback.
	Atomic.write(path, {"schema": 99, "packages": []}, false)
	reopened.reload("builtin/starter_meadow@1")
	_expect(reopened._favorite.disabled and not reopened._use.disabled and reopened._status.visible, "Future library disabled starter use or allowed favorites write")
	reopened.queue_free()
	await _frames(3)
	_expect(state.export_state() == state_before and progression.export_state() == progress_before, "Library preferences changed campaign or progression")

func _sizes(panel: Control) -> void:
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.5]:
			for language: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(language)
				root.size = size
				root.content_scale_size = size
				root.content_scale_factor = scale
				panel._show_detail = false
				await _frames(4)
				panel._layout()
				await _frames(3)
				await _reveal(panel._favorites_only)
				_expect(_onscreen(panel._favorites_only), "Favorite filter unreachable: %s/%s/%s" % [size, scale, language])
				panel._show_detail = true
				panel._layout()
				await _frames(3)
				_expect(_onscreen(panel._favorite) and _onscreen(panel._use), "Favorite/use actions unreachable: %s/%s/%s" % [size, scale, language])
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _frames(3)

func _buttons(panel: Control) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in panel._list.get_children():
		if child is Button: result.append(child)
	return result

func _reveal(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _frames(2)

func _click(control: Control) -> void:
	await _reveal(control)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await _frames(2)

func _onscreen(control: Control) -> bool:
	return control.is_visible_in_tree() and root.get_visible_rect().encloses(control.get_global_rect())

func _frames(count: int) -> void:
	for frame in range(count): await process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
