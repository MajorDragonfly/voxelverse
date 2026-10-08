extends RefCounted
## Presentation assertions on copies supplied to the real D2 controller.
## No production fixture, commands, or alternate animal persistence.
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const State = preload("res://world/domestication/animal_state.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Display = preload("res://ui/discovery/owned_animal_presentation.gd")

static func run(test: SceneTree) -> void:
	var journal: CanvasLayer = test.journal
	var controller: RefCounted = test.fixture.lab.controller
	var original: Dictionary = controller.registry.duplicate(true)
	var original_persist: Callable = controller.persist
	var original_suitability: Callable = controller.suitability
	var original_discoveries: Dictionary = test.root.get_node("ProgressionService").discovered_species.duplicate(true)
	var progression: String = JSON.stringify(test.root.get_node("ProgressionService").export_state())
	var save: String = FileAccess.get_file_as_string(test.fixture.lab.store.path)
	var events: int = test.commits
	var registry: Dictionary = original.duplicate(true)
	registry.animals.clear()
	var template: Dictionary = original.animals.values()[0].duplicate(true)
	for index in range(6):
		var animal: Dictionary = template.duplicate(true)
		animal.object_id = "browser-%d" % index
		animal.species_id = "browser-species-%d" % (index % 2)
		animal.design_ref = {"id": "browser-design-%d" % (index % 2), "revision": 1}
		animal.order = ["wait", "follow", "home"][index % 3]
		animal.handler_id = test.fixture.lab.fixture.ACTOR if animal.order == "follow" else ""
		if index >= 4:
			animal.status = "dead"
			animal.health = 0.0
			animal.trust = 20.0 if index == 4 else 80.0
			animal.order = "wait"
			animal.handler_id = ""
		registry.animals[animal.object_id] = animal
	var foreign: Dictionary = template.duplicate(true)
	foreign.object_id = "foreign-owned"
	foreign.owner_faction_id = "other-tribe"
	registry.animals[foreign.object_id] = foreign
	test._expect(State.validate(registry).is_empty(), "Browser fixture violates D2")
	controller.configure(registry, Callable())
	var names := func(kind: String, id: String) -> String:
		if kind == "animal": return "Milo" if id in ["browser-0", "browser-1"] else "Tier " + id
		if kind == "species": return "Zebra" if id == "browser-species-0" else "Alpaka"
		return test.fixture._names(kind, id)
	journal.bind_owned_animals(controller, test.fixture._context, names)
	journal._filter.select(2)
	journal._search.clear()
	journal._apply_filters()
	var reader: RefCounted = journal._owned_reader
	test._expect(reader.read("mIlO", "all").rows.size() == 2, "Name search/case/duplicate names failed")
	test._expect(reader.read("alpaka", "all").rows.size() == 3, "Species search failed")
	test._expect(reader.read("", "all").rows.size() == 6, "Foreign animal leaked into register")
	test._expect(reader.read("", "all").rows[0].key == "browser-0", "Duplicate names lost stable ID tie break")
	test._expect(reader.read("", "all", "species").rows[0].species == "Alpaka", "Species sorting ignored actual name")
	var trust_rows: Array = reader.read("", "all", "trust").rows
	test._expect(trust_rows[-1].key == "browser-4" and trust_rows[-2].key == "browser-5", "Trust sort uses text instead of D2 units")
	test._expect(reader.read("", "all", "order").rows[0]._display_data.order_code == "follow", "Command grouping failed")
	test._expect(reader.read("", "all", "name", "wait").rows.size() == 2 and reader.read("", "all", "name", "none").rows.size() == 2, "Dead animals mistaken for active waiting orders")
	test._expect(reader.read("", "living").order_codes == ["follow", "home", "wait"], "Order choices not derived from living records")
	# A species observation grants display evidence only for exact stable IDs/body.
	var observed := {"id": "browser-species-0", "body_id": template.body_id,
		"scan": {"version": 1, "complete": true},
		"journal": Records.observation({"body": {}, "parts": [], "design_id": "browser-design-0",
			"species": {"domestication": D1.suitability("milk")}}, "Observed test site")}
	var observations := {"a": observed}
	var known: Array = reader.read("", "all", "name", "", observations).rows
	test._expect(known[0]._display_data.roles == ["milk"] and known[1]._display_data.roles.is_empty(), "Suitability invented for an unscanned species")
	for failure: String in ["scan", "body", "id", "future"]:
		var unsupported: Dictionary = observed.duplicate(true)
		match failure:
			"scan": unsupported.scan.complete = false
			"body": unsupported.body_id = "another-body"
			"id": unsupported.id = "another-species"
			"future": unsupported.journal.visual.species.domestication.schema = 999
		test._expect(reader.read("", "all", "name", "", {"a": unsupported}).rows[0]._display_data.roles.is_empty(), "Unsupported observation granted role: " + failure)
	for code: String in ["name", "species", "trust", "order"]:
		await _choose(test, journal._owned_controls._sort, code)
		test._expect(journal._owned_controls.sort_code == code and journal._rows.size() == 6, "Sort control lost animals: " + code)
	await _choose(test, journal._owned_controls._order, "follow")
	test._expect(journal._rows.size() == 1 and journal._rows[0].key == "browser-1", "Order dropdown not connected to shared book")
	journal._search.text = "Milo"
	journal._apply_filters()
	journal._search.grab_focus()
	var selected: String = journal._selected_key
	for language: String in ["en", "de"]:
		await test._display(Vector2i(800, 600), 1.5, language)
		test._expect(journal._owned_controls.order_filter == "follow" and journal._owned_controls.sort_code == "order" and journal._search.text == "Milo" and journal._selected_key == selected and journal._search.has_focus(), "Language switch reset browser state")
		test._expect(journal._owned_controls._sort.get_item_text(3) == Display.text("OWNED_SORT_ORDER"), "Sort label not translated")
		for control: Control in [journal._owned_controls._order, journal._owned_controls._sort]:
			test._expect(test._physical(journal._panel).encloses(test._physical(control)), "New controls escape 800x600/150%")
		test._expect(test._physical(journal._panel).encloses(test._physical(journal._heading_title)), "Journal heading escapes after browser/language input: " + language)
		await _image(test, "owned-browser-%s-800x600-150-follow" % language)
	# Silent configure/load and removal while open must not retain the selected ID.
	var changed: Dictionary = controller.registry.duplicate(true)
	changed.animals.erase("browser-1")
	controller.configure(changed, Callable())
	journal.refresh_owned_animals()
	test._expect(journal._owned_controls.order_filter == "" and journal._rows.size() == 1 and journal._selected_key == "browser-0", "Removed follow target left stale filter/selection")
	changed.animals.clear()
	controller.configure(changed, Callable())
	journal.refresh_owned_animals()
	test._expect(journal._rows.is_empty() and journal._selected_key.is_empty() and journal._animals_result_code == "owned.empty", "Silent empty load retained prior animals")
	await _image(test, "owned-browser-de-empty")
	controller.configure(registry, Callable())
	journal.refresh_owned_animals()
	test._expect(journal._rows.size() == 2 and journal._owned_controls.sort_code == "order", "Silent reload lost query/sort or failed to restore animals")
	journal._search.clear()
	journal._apply_filters()
	# Loss is a D2 tombstone, never an active order or a manufactured arrival.
	changed = registry.duplicate(true)
	changed.animals["browser-2"].status = "dead"
	changed.animals["browser-2"].health = 0.0
	changed.animals["browser-2"].order = "wait"
	changed.animals["browser-2"].handler_id = ""
	controller.configure(changed, Callable())
	controller.animal_changed.emit("browser-2", "died")
	test._expect(reader.read("", "living").rows.size() == 3 and reader.read("", "dead").rows.size() == 3, "Loss failed to refresh life states")
	test.root.get_node("ProgressionService").discovered_species = observations
	controller.configure(registry, Callable())
	journal.refresh_owned_animals()
	journal._selected_key = "browser-0"
	journal._apply_filters()
	for language: String in ["de", "en"]:
		await test._display(Vector2i(1280, 720), 1.0, language)
		test._expect(journal._selected_row._display_data.roles == ["milk"], "Book did not use completed observation for owned animal")
		await _image(test, "owned-browser-%s-known-role" % language)
		journal._detail_scroll.ensure_control_visible(journal._owned_register._entries.get_child(3))
		await test._frames(3)
		await _image(test, "owned-browser-%s-role-detail" % language)
		test._expect(("not observed" if language == "en" else "nicht beobachtet") in journal._owned_register._entries.get_child(3).text, "Role display claims actual production")
	test._expect(FileAccess.get_file_as_string(test.fixture.lab.store.path) == save and test.commits == events + 1, "Browsing wrote or invoked a D2 action")
	# Restore every synthetic presentation input; retain the real saved lab for cold restart.
	controller.configure(original, original_persist, original_suitability)
	test.root.get_node("ProgressionService").discovered_species = original_discoveries
	journal.bind_owned_animals(controller, test.fixture._context, test._names)
	journal._owned_controls.sort_code = "name"
	journal._owned_controls._sort.select(0)
	journal._owned_controls.order_filter = ""
	journal._search.clear()
	journal._page = 0
	journal._apply_filters()
	await test._display(Vector2i(800, 600), 1.5, "de")
	test._expect(JSON.stringify(test.root.get_node("ProgressionService").export_state()) == progression, "Browser changed saved discovery/progress")
	print("OWNED_BROWSING_CHECKS_COMPLETED")

static func _choose(test: SceneTree, button: OptionButton, code: String) -> void:
	# Drive the real dropdown with mouse opening and keyboard confirmation.
	var index := -1
	for i in button.item_count:
		if button.get_item_metadata(i) == code: index = i
	test._expect(index >= 0, "Requested unavailable dropdown value: " + code)
	if index < 0: return
	if DisplayServer.get_name() == "headless":
		button.select(index)
		button.item_selected.emit(index)
	else:
		await test._click(button)
		var popup := button.get_popup()
		test._expect(popup.visible, "Mouse did not open dropdown")
		popup.grab_focus()
		popup.set_focused_item(0)
		for i in index: await _key(test, button.get_popup(), KEY_DOWN)
		await _key(test, button.get_popup(), KEY_ENTER)
	await test._frames(3)

static func _key(test: SceneTree, window: Window, key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.window_id = window.get_window_id()
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await test._frames(2)

static func _image(test: SceneTree, label: String) -> void:
	# Keep the existing review helper's 20-image contract unchanged.
	if "--browser-capture" in OS.get_cmdline_user_args(): await test._image(label)
