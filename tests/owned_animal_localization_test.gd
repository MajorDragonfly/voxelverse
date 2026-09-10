extends "owned_animal_register_test.gd"
## Real D2 transactions plus a copied, validated collection for paging/layout.
const Display = preload("res://ui/discovery/owned_animal_presentation.gd")
const Animal = preload("res://world/domestication/animal_state.gd")
var checks: int = 0

func _run() -> void:
	root.get_node("LocaleManager")._apply("de")
	await super._run()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: print("FAIL: ", message)
	super._expect(condition, message)

func _capture(label: String) -> void:
	if label != "animals_1280x720": return
	var d2: RefCounted = fixture.lab.controller
	var original: Dictionary = d2.registry.duplicate(true)
	var saved: String = FileAccess.get_file_as_string(fixture.lab.store.path)
	var fixture_registry: Dictionary = original.duplicate(true)
	fixture_registry.schema = Animal.SCHEMA
	var template: Dictionary = fixture_registry.animals[fixture.lab.fixture.ANIMAL]
	template.surface_mode = Animal.Home.Cube.MODE
	for field: String in ["position", "home", "wait_position"]:
		var place: Dictionary = Animal.Home.Cube.address(template.body_id, 0, 0.25, 0.5, 12.5)
		place.radius = 6371000.0
		template[field] = place
	for i in range(125):
		var animal: Dictionary = template.duplicate(true)
		animal.object_id = "locale-%03d" % i
		fixture_registry.animals[animal.object_id] = animal
	var dead: Dictionary = template.duplicate(true)
	dead.object_id = "locale-dead"
	dead.status = "dead"
	dead.health = 0.0
	dead.order = "wait"
	dead.handler_id = ""
	fixture_registry.animals[dead.object_id] = dead
	_expect(Animal.validate(fixture_registry).is_empty(), "Paging fixture violates D2 contract")
	d2.registry = fixture_registry
	journal.bind_owned_animals(d2, fixture._context, _names)
	journal._heading.get_child(0).text = "Entdeckungsbuch"
	await _language_checks(saved)
	await _layouts()
	await _empty_and_dead(saved)
	d2.registry = original
	journal.bind_owned_animals(d2, fixture._context, fixture._names)
	journal._search.clear()
	journal._filter.select(0)
	journal._page = 0
	journal._apply_filters()
	await _display(Vector2i(1280, 720), 1.0, "de")
	_expect(FileAccess.get_file_as_string(fixture.lab.store.path) == saved, "Presentation wrote the original D2 save")

func _names(kind: String, id: String) -> String:
	if kind == "animal": return "Eigene Tiere" if id == "locale-dead" else "Tier {name} · " + id
	if kind == "species": return "Schließen {species}"
	if kind == "faction": return "Eigener Stamm mit langem Namen"
	if kind == "body": return "Heimatplanet mit langem Namen"
	return fixture._names(kind, id)

func _language_checks(saved: String) -> void:
	journal._filter.select(2)
	journal._search.text = "Heimkehr"
	journal._apply_filters()
	var absolute: int = -1
	for i in journal._rows.size():
		if journal._rows[i].key == "locale-110": absolute = i
	_expect(absolute >= journal.PAGE_SIZE, "Fixture does not reach page two")
	if absolute < 0: return
	journal._page = absolute / journal.PAGE_SIZE
	journal._selected_key = "locale-110"
	journal._apply_filters()
	await _display(Vector2i(800, 600), 1.5, "de")
	journal._search.grab_focus()
	journal._search.caret_column = 4
	journal._search.select(1, 4)
	journal._list.get_v_scroll_bar().value = 80
	journal._detail_scroll.scroll_vertical = 60
	await _frames(4)
	var detail_scroll: int = journal._detail_scroll.scroll_vertical
	var list_scroll: float = journal._list.get_v_scroll_bar().value
	var labels: Array = journal._owned_register._entries.get_children()
	var selected: PackedInt32Array = journal._list.get_selected_items()
	var keys: Array = journal._rows.map(func(row: Dictionary): return row.key)
	var d2: RefCounted = fixture.lab.controller
	var registry: Dictionary = d2.registry.duplicate(true)
	var progression: Dictionary = root.get_node("ProgressionService").export_state()
	var writes: int = commits
	for language: String in ["en", "de", "en", "de"]:
		_expect(root.get_node("LocaleManager").save_preference(language) == OK, "Could not persist language preference")
		await _frames(6)
		_expect(journal.is_open and paused and journal._owns_pause and get_nodes_in_group(&"discovery_journal").size() == 1, "Language change lost the shared book/pause")
		_expect(journal._tabs.current_tab == journal.ANIMALS_TAB and journal._page == 1 and journal._selected_key == "locale-110" and journal._list.get_selected_items() == selected, "Language change reset tab/page/animal selection")
		_expect(journal._filter.get_item_metadata(journal._filter.selected) == "all" and journal._search.text == "Heimkehr", "Language change reset filter/query")
		_expect(journal._search.has_focus() and journal._search.caret_column == 4 and journal._search.get_selected_text() == "eim", "Language change reset search focus/caret/selection")
		_expect(journal._detail_scroll.scroll_vertical == detail_scroll and journal._list.get_v_scroll_bar().value == list_scroll, "Language change reset a scroll position: " + language)
		_expect(journal._owned_register._entries.get_children() == labels and journal._rows.map(func(row: Dictionary): return row.key) == keys, "Language change rebuilt detail controls or reordered animals")
		_expect(d2.registry == registry and commits == writes and FileAccess.get_file_as_string(fixture.lab.store.path) == saved, "Language change mutated, commanded or saved D2")
		_expect(root.get_node("ProgressionService").export_state() == progression, "Animal translation awarded progression")
		_expect(journal._title.text == "Tier {name} · locale-110" and "Schließen {species}" in labels[0].text, "Names were translated or interpolated")
		_expect(("Return home" if language == "en" else "Heimkehr") in labels[1].text, "Order did not refresh")
		_expect(("Latitude" if language == "en" else "Breite") in labels[1].text and ("12.5 m" if language == "en" else "12,5 m") in labels[1].text, "Spherical location or decimal separator did not refresh")
		_expect(journal._owned_reader.read("Heimkehr", "all").rows.size() == keys.size() and journal._owned_reader.read("Return home", "all").rows.size() == keys.size(), "Query results depend on current display language")

func _layouts() -> void:
	journal._search.deselect()
	journal._search.clear()
	journal._page = 0
	journal._selected_key = "locale-000"
	journal._apply_filters()
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		for scale: float in [1.0, 1.5]:
			for language: String in ["de", "en"]:
				await _display(size, scale, language)
				journal._list.ensure_current_is_visible()
				_expect(Rect2(Vector2.ZERO, Vector2(size)).encloses(_physical(journal._panel)), "Animal panel escaped screen: %s / %s / %s" % [size, scale, language])
				for action: Control in [journal._close, journal._search, journal._filter, journal._previous_page, journal._next_page]:
					_expect(_physical(journal._panel).encloses(_physical(action)), "Animal action escaped panel: " + action.name)
				_expect(_physical(journal._list).size.y >= 60 and _physical(journal._detail_scroll).size.y >= 80, "Animal browser/detail is too small")
				journal._detail_scroll.scroll_vertical = 0
				await _frames(3)
				await _image("owned-%s-%dx%d-%d" % [language, size.x, size.y, roundi(scale * 100)])
				var last: Control = journal._owned_register._entries.get_child(2)
				journal._detail_scroll.ensure_control_visible(last)
				await _frames(3)
				_expect(_physical(journal._detail_scroll).grow(1).encloses(_physical(last)), "Animal identity cannot be reached")
				if size == Vector2i(800, 600) and scale == 1.5: await _image("owned-%s-800x600-150-detail" % language)
	await _click(journal._next_page)
	_expect(journal._page == 1, "Translated next-page button cannot be clicked")
	await _click(journal._previous_page)
	_expect(journal._page == 0, "Translated previous-page button cannot be clicked")

func _empty_and_dead(saved: String) -> void:
	journal._filter.select(1)
	journal._search.clear()
	journal._apply_filters()
	for language: String in ["de", "en"]:
		await _display(Vector2i(800, 600), 1.5, language)
		_expect(journal._title.text == "Eigene Tiere" and journal._rows.size() == 1 and journal._rows[0].dead, "Deceased animal's literal name/selection changed")
		_expect(("Last owner" if language == "en" else "Letzter Besitzer") in journal._owned_register._entries.get_child(0).text, "Death history claims current ownership")
		await _image("owned-%s-800x600-150-dead" % language)
	journal._search.text = "no matching animal"
	journal._apply_filters()
	for language: String in ["de", "en"]:
		await _display(Vector2i(800, 600), 1.5, language)
		_expect(journal._description.is_visible_in_tree() and ("No matching" if language == "en" else "Keine passenden") in journal._description.text, "Empty search feedback is hidden/untranslated")
		await _image("owned-%s-800x600-150-empty" % language)
	var d2: RefCounted = fixture.lab.controller
	d2.registry.schema = 99
	journal._owned_reader.check_context()
	for language: String in ["de", "en"]:
		await _display(Vector2i(800, 600), 1.5, language)
		_expect(journal._rows.is_empty() and journal._animals_result_code == "owned.invalid" and d2.registry.schema == 99 and FileAccess.get_file_as_string(fixture.lab.store.path) == saved, "Unsupported register was translated into valid ownership or saved")
		await _image("owned-%s-800x600-150-invalid" % language)

func _display(size: Vector2i, scale: float, language: String) -> void:
	root.size = size
	root.get_node("DisplaySettings").ui_scale = scale
	root.get_node("LocaleManager")._apply(language)
	journal._layout_catalog()
	await _frames(6)

func _physical(control: Control) -> Rect2:
	return root.get_final_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _image(label: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(label + ".png"))

func _finish(d2_checked: bool) -> void:
	if "--verify-reload" not in OS.get_cmdline_user_args() and d2_checked:
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--verify-reload"], output, true)
		_expect(code == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Cold D2 restart failed: " + str(output))
	print("OWNED_LOCALIZATION_CHECKS: ", checks, " PASSED: ", failures.is_empty())
	await super._finish(d2_checked)
