extends "species_comparison_test.gd"
## Full production journal/comparison, including inherited real save-failure cases.
const Copy = preload("res://ui/discovery/journal_presentation.gd")
var checks: int = 0
var layouts: int = 0
var captures: Array[String] = []
var _tested: bool = false

func _run() -> void:
	root.get_node("LocaleManager")._apply("de")
	await super._run()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: print("FAIL: ", message)
	super._check(condition, message)

func _capture(label: String) -> void:
	if label != "comparison" or _tested: return
	_tested = true
	var saved := FileAccess.get_file_as_string(saves.save_path)
	var source: Dictionary = progression.export_state()
	await _comparison_languages()
	# A copied synthetic collection reaches page three without writing the campaign.
	var original_species: Dictionary = progression.discovered_species
	var original_regions: Dictionary = progression.discovered_regions
	var entries: Dictionary = original_species.duplicate(true)
	for index in range(205):
		var row: Dictionary = original_species[species_key].duplicate(true)
		row.name = "Entdeckungsbuch {name} %03d" % index
		row.journal.location = "Schließen {world}"
		entries["locale-%03d" % index] = row
	progression.discovered_species = entries
	progression.discovered_regions = {"region-a": {"world_seed": 15838, "x": -2, "z": 7},
		"region-b": {"world_seed": 999, "x": 3, "z": 8, "journal": {"location": "Entdeckungsbuch {world}"}}}
	journal._comparison_mode = false
	journal.refresh()
	journal._search.text = "Entdeckungsbuch"
	journal._selected_key = "locale-150"
	journal._page = 1
	journal._apply_filters()
	await _settle()
	_check(journal._page == 1 and journal._selected_key == "locale-150", "Synthetic collection reaches second page")
	journal._search.grab_focus()
	journal._search.caret_column = 8
	journal._search.select(1, 5)
	journal._list.get_v_scroll_bar().value = 100
	journal._detail_scroll.scroll_vertical = 60
	journal._preview._angle = 1.8
	journal._preview._zoom = 0.8
	journal._preview._frame_camera()
	journal._animal_roles.show()
	await _settle()
	var list_scroll: float = journal._list.get_v_scroll_bar().value
	var detail_scroll: int = journal._detail_scroll.scroll_vertical
	var model: Node = journal._preview._model
	var tiles: Array = journal._parts_grid.get_children()
	var rows: Array = journal._rows.duplicate(true)
	var state: Dictionary = progression.export_state()
	var queries: int = journal._catalog.queries
	var reads: int = journal._catalog.detail_reads
	for language: String in ["en", "de", "en"]:
		await _language(language)
		_check(journal._selected_key == "locale-150" and journal._page == 1 and journal._rows == rows, "Language retains page, order and canonical rows")
		_check(journal._catalog.queries == queries and journal._catalog.detail_reads == reads, "Language does not refilter or reread full discoveries")
		_check(journal._search.text == "Entdeckungsbuch" and journal._search.has_focus() and journal._search.caret_column == 8 and journal._search.get_selected_text() == "ntde", "Search text, focus and caret selection survive")
		_check(journal._list.get_v_scroll_bar().value == list_scroll and journal._detail_scroll.scroll_vertical == detail_scroll, "Both scroll positions survive")
		_check(journal._preview._model == model and journal._preview._angle == 1.8 and journal._preview._zoom == 0.8 and journal._parts_grid.get_children() == tiles, "Language preserves preview model, camera and part controls")
		_check(journal._animal_roles.visible and journal._owns_pause and paused and get_nodes_in_group(&"discovery_journal").size() == 1, "Language preserves role expansion and shared modal")
		_check(journal._title.text == "Entdeckungsbuch {name} 150" and "Schließen {world}" in journal._description.text, "Literal species and location names are neither translated nor substituted")
		_check(("Predator" if language == "en" else "Räuber") in journal._description.text, "Species role is translated")
		_check(progression.export_state() == state and FileAccess.get_file_as_string(saves.save_path) == saved, "Language never mutates or writes progression")
	journal._search.deselect()
	journal._search.clear()
	journal._page = 0
	journal._selected_key = species_key
	journal._apply_filters()
	for word: String in ["Räuber", "Predator"]:
		var result: Dictionary = journal._catalog.page("species", word, "", 0, journal.Suitability.search_roles())
		_check(result.total == entries.size(), "Bilingual species search: " + word)
	_check(journal._catalog.page("regions", "World 15838", "", 0).total == 1, "Generated world names are searchable in English")
	_check(Copy.location({"world_seed": 12}, "en") == "World 12" and Copy.location({"journal": {"location": "Welt 12"}}, "en") == "Welt 12", "Only generated locations are translated")
	for query: String in ["Predator jaws", "Raubkiefer"]:
		_check(not Copy.part_rows(journal._state, query, "", 0).is_empty(), "Bilingual part search: " + query)
	for query: String in ["First encounter", "Erste Begegnung"]:
		_check(Copy.goals(journal._state, query).size() == 1, "Bilingual research search: " + query)
	await _content_and_layouts()
	progression.discovered_species = original_species
	progression.discovered_regions = original_regions
	journal._tabs.current_tab = 0
	journal._search.clear()
	journal._filter.select(0)
	journal._selected_key = species_key
	journal._page = 0
	journal._comparison_mode = true
	journal.refresh()
	await _display(Vector2i(1280, 720), 1.0, "de")
	journal._detail_scroll.scroll_vertical = 0
	_check(progression.export_state() == source and FileAccess.get_file_as_string(saves.save_path) == saved, "Fixture restores all original state and leaves save bytes unchanged")
	print("JOURNAL_LOCALIZATION_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "checks": checks, "layouts": layouts, "screenshots": captures}))

func _comparison_languages() -> void:
	var panel: VBoxContainer = journal._comparison
	var own: Node = panel.own_preview._model
	var species: Node = panel.species_preview._model
	var stats: Array = panel.stats_grid.get_children()
	var parts: Array = panel.part_values.get_children()
	panel.own_preview._angle = 1.2
	panel.species_preview._zoom = 0.75
	var part: String = panel._selected_part
	for language: String in ["en", "de"]:
		await _language(language)
		_check(panel.own_name.text == ("Your creature" if language == "en" else "Deine Kreatur"), "Comparison headings translate")
		_check(panel.own_preview._model == own and panel.species_preview._model == species and panel.own_preview._angle == 1.2 and panel.species_preview._zoom == 0.75, "Comparison models and separate cameras survive")
		_check(panel.stats_grid.get_children() == stats and panel.part_values.get_children() == parts and panel._selected_part == part, "Comparison preserves stats, contribution controls and chosen part")
		_check(panel.stats_grid.get_child(4).get_child(1).text == ("Attack" if language == "en" else "Angriff"), "Comparison metric labels translate")
		_check(Copy.number(2.7, true) == ("+2.7" if language == "en" else "+2,7"), "Decimal separator follows language")

func _content_and_layouts() -> void:
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.5]:
			for language: String in ["de", "en"]:
				await _display(size, scale, language)
				for tab in range(5):
					journal._tabs.current_tab = tab
					journal._search.clear()
					journal._filter.select(0)
					journal._status.select(0)
					journal._selected_key = species_key if tab == 0 else ""
					journal._apply_filters()
					await _settle()
					_layout_check(size, tab, scale, language)
					if tab == 4:
						_check(("First encounter" if language == "en" else "Erste Begegnung") == journal._title.text, "Goal name follows locale")
						_check(("scan mode" if language == "en" else "Scanmodus") in journal._description.text, "Research instructions use active scanner")
					if (size.x == 800 and scale == 1.5) or (size.x == 1920 and scale == 1.0 and tab in [0, 1]):
						await _image("journal-%s-%dx%d-%d-tab%d" % [language, size.x, size.y, roundi(scale * 100), tab])
				journal._tabs.current_tab = 0
				journal._selected_key = species_key
				journal._comparison_mode = true
				journal._apply_filters()
				await _settle()
				_layout_check(size, 6, scale, language)
				_check(journal._comparison.size.x <= journal._detail_scroll.size.x + 1, "Comparison fits horizontally")
				if (size.x == 800 and scale == 1.5) or (size.x == 1920 and scale == 1.0):
					await _image("journal-%s-%dx%d-%d-compare" % [language, size.x, size.y, roundi(scale * 100)])
				journal._comparison_mode = false
	journal._tabs.current_tab = 1
	journal._search.text = "no such part"
	journal._apply_filters()
	for language: String in ["en", "de"]:
		await _language(language)
		_check(journal._title.text == ("No matching entries" if language == "en" else "Keine passenden Einträge"), "Empty result translates")
	journal._research_result({"ok": false, "reason": "save_in_progress"})
	for language: String in ["en", "de"]:
		await _language(language)
		_check(journal._action_message.visible and ("Saving is in progress" if language == "en" else "Es wird gerade gespeichert") in journal._action_message.text, "Existing result translates without repeating the command")
	journal._action_message.hide()

func _layout_check(size: Vector2i, tab: int, scale: float, language: String) -> void:
	layouts += 1
	var context := "%s %s tab%d @%s" % [size, language, tab, scale]
	_check(Rect2(Vector2.ZERO, Vector2(size)).grow(1).encloses(_physical(journal._panel)), "Panel stays on screen: " + context)
	_check(_physical(journal._panel).grow(1).encloses(_physical(journal._close)), "Close remains reachable: " + context)
	_check(_physical(journal._detail_scroll).size.y >= 80, "Details retain useful scrolling space: " + context)
	if tab in [0, 1, 2, 4]:
		_check(_physical(journal._list).size.y >= 60, "List retains useful scrolling space: " + context)
		for control in [journal._search, journal._filter, journal._status, journal._previous_page, journal._next_page]:
			if control.is_visible_in_tree(): _check(_physical(journal._panel).grow(1).encloses(_physical(control)), "Filter or page control stays inside: " + context)
	_check(journal._detail.size.x <= journal._detail_scroll.size.x + 1, "Details do not overflow horizontally: " + context)

func _physical(control: Control) -> Rect2:
	return Rect2(control.get_global_transform_with_canvas().origin, control.size * control.get_global_transform_with_canvas().get_scale())

func _display(size: Vector2i, scale: float, language: String) -> void:
	root.get_node("DisplaySettings").ui_scale = scale
	root.content_scale_size = size
	root.content_scale_factor = 1.0
	root.size = size
	await _language(language)
	journal._layout_catalog()
	await _settle()

func _language(language: String) -> void:
	root.get_node("LocaleManager")._apply(language)
	await _settle()

func _settle() -> void:
	for frame in range(5): await process_frame

func _image(label: String) -> void:
	var args := OS.get_cmdline_user_args()
	if not "--capture" in args: return
	var path := args[args.find("--capture") + 1].path_join(label + ".png")
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(path) == OK, "Screenshot saved: " + label)
	captures.append(label + ".png")
