extends "tribal_age_test.gd"
## Real village/controller + GUI commands. Language-only changes must be read-only.
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")
var checks: int = 0

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Could not establish tribe locale fixture")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	if not tribe.is_active():
		_expect(false, "Village did not activate")
		await _cleanup()
		_finish()
		return
	var panel: CanvasLayer = tribe.panel
	var locale: Node = root.get_node("LocaleManager")
	tribe.village().members[0].name = "TRIBE_BOOK {count}"
	tribe.select_all()
	locale._apply("en")
	await _frames(4)
	await _click(panel._buttons.wood)
	_expect(tribe.village().members.all(func(m: Dictionary) -> bool: return m.order == "wood"), "English gather button did not issue real order")
	_expect("Order saved for 3 residents" in panel._message.text, "English receipt missing")
	await _until(func() -> bool: return _has_cargo(), 650)
	_expect(_has_cargo(), "Real worker did not pick up wood")
	await _click(panel._buttons.wait)
	_expect(_has_cargo(), "Translated stop discarded cargo")
	# One successful saved command is displayed in each language without replay.
	paused = true
	panel._owns_pause = true
	panel.refresh()
	await _frames(3)
	var selected: Array = tribe.selected.duplicate()
	var records: Dictionary = tribe.village().duplicate(true)
	var campaign: Dictionary = state.campaign.export_state()
	var progression: Dictionary = root.get_node("ProgressionService").export_state()
	var bytes: String = FileAccess.get_file_as_string(SAVE)
	var actors: Array = tribe.actors.values()
	var rows: Array = panel._residents.get_children()
	panel._tabs.current_tab = 1
	panel._jobs.select(2)
	panel._jobs.grab_focus()
	await _frames(3)
	panel._scroll.scroll_vertical = 30
	await _frames(3)
	var old_scroll: int = panel._scroll.scroll_vertical
	var receipt: Dictionary = panel._feedback._receipt.duplicate(true)
	for language: String in ["de", "en", "de", "en"]:
		locale._apply(language)
		await _frames(6)
		_expect(panel._tabs.current_tab == 1 and panel._jobs.selected == 2 and panel._jobs.has_focus(), "Language lost tab, profession or focus")
		_expect(panel._scroll.scroll_vertical == old_scroll, "Language lost scroll position")
		_expect(tribe.selected == selected and panel._residents.get_children() == rows and tribe.actors.values() == actors, "Language rebuilt selection, rows or actors")
		_expect(tribe.village() == records and state.campaign.export_state() == campaign and root.get_node("ProgressionService").export_state() == progression, "Language mutated gameplay")
		_expect(FileAccess.get_file_as_string(SAVE) == bytes and panel._feedback._receipt == receipt, "Language rewrote save or replayed receipt")
		_expect(paused and panel._owns_pause, "Language released pause")
		_expect(panel._buttons.wood.text == ("Gather wood" if language == "en" else "Holz sammeln"), "Order label not translated")
		_expect(panel._jobs.get_item_text(2) == ("Woodworker" if language == "en" else "Holzarbeiter"), "Profession not translated")
		_expect(panel._stock.text.begins_with("TRIBE" if language == "en" else "STAMM"), "Stock not translated")
		_expect(panel._residents.get_child(0).text.begins_with("TRIBE_BOOK {count} · "), "Literal resident name translated or interpolated")
		_expect(("Order saved for 3 residents" if language == "en" else "Auftrag für 3 Bewohner gespeichert") in panel._message.text, "Receipt did not change language")
		for mapping: Dictionary in [Presentation.ORDERS, Presentation.JOBS, Presentation.RESOURCES, Presentation.ACTIVITIES, Presentation.PROJECTS, Presentation.LEGACY]:
			for key: String in mapping.values():
				_expect(TranslationServer.translate(key) != key, "Missing message " + key)
		_expect(Presentation.legacy_status("Dorfwachstum: Halte je 8 Nahrung und Wasser im Lager bereit.") == ("Village growth: keep 8 units each of food and water in storage." if language == "en" else "Dorfwachstum: Halte je 8 Nahrung und Wasser im Lager bereit."), "Growth parameter not translated")
		_expect(Presentation.legacy_status("Es fehlen eingelagerte Materialien: 3 Holz.") == ("Required stored materials: 3 wood." if language == "en" else "Es fehlen eingelagerte Materialien: 3 Holz."), "Resource parameter not translated")
		_expect(Presentation.legacy_status("TRIBE_BOOK {name} gehört jetzt zu deinem Stamm. Wähle einen Beruf oder Auftrag.").begins_with("TRIBE_BOOK {name}"), "Status adapted inside resident name")
		_expect(Presentation.legacy_status("unrecognized diagnostic") == "unrecognized diagnostic", "Unknown diagnostic hidden")
	await _layouts()
	# A real failed save must retain the old order/cargo and its translated reason.
	panel._owns_pause = false
	paused = false
	root.size = Vector2i(1280, 800)
	root.get_node("DisplaySettings").ui_scale = 1.0
	panel._tabs.current_tab = 0
	panel.refresh()
	await _frames(3)
	var old: Dictionary = tribe.village().duplicate(true)
	var block := FileAccess.open("user://tribe-locale-blocked", FileAccess.WRITE)
	block.store_string("not a directory")
	block.close()
	saves.save_path = "user://tribe-locale-blocked/save.json"
	_expect(not tribe.issue_order("resume"), "Failed save reported success")
	_expect(tribe.village() == old and FileAccess.get_file_as_string(SAVE) == bytes, "Failed save changed orders/cargo or previous save")
	paused = true
	panel._owns_pause = true
	for language: String in ["en", "de"]:
		locale._apply(language)
		await _frames(3)
		_expect(("Saving failed" if language == "en" else "Speichern fehlgeschlagen") in panel._message.text, "Failed save reason did not translate")
		_expect(tribe.village() == old, "Translating failure retried command")
	saves.save_path = SAVE
	# Restore the saved stopped transport through the real persistence consumer.
	_expect(saves.load_now(), "Saved transport did not load")
	panel._owns_pause = false
	paused = false
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	_expect(tribe.village().members[0].name == "TRIBE_BOOK {count}" and _has_cargo(), "Reload lost literal name or in-transit cargo")
	tribe.select_all()
	locale._apply("en")
	panel._tabs.current_tab = 0
	panel.refresh()
	await _frames(3)
	await _click(panel._buttons.resume)
	_expect(tribe.village().members.all(func(m: Dictionary) -> bool: return m.order == "wood"), "Translated resume did not restore saved order")
	panel._tabs.current_tab = 1
	panel._jobs.select(2)
	panel.refresh()
	await _frames(3)
	var assign: Button
	for button: Button in panel._work_page.find_children("*", "Button", true, false):
		if button.get_meta("tribe_text_key", "") == "TRIBE_ASSIGN_PROFESSION":
			assign = button
	await _click(assign)
	_expect(tribe.village().members.all(func(m: Dictionary) -> bool: return m.profession == "forester" and m.order == "wood"), "Translated profession action changed the wrong job ID")
	await _cleanup()
	_finish()

func _layouts() -> void:
	var panel: CanvasLayer = tribe.panel
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = resolution
		for scale: float in [1.0, 1.5]:
			root.get_node("DisplaySettings").ui_scale = scale
			for language: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(language)
				for tab in [0, 1, panel._build_page.get_index()]:
					panel._tabs.current_tab = tab
					panel.refresh()
					await _frames(5)
					panel._scroll.scroll_vertical = 0
					await _frames(3)
					_expect(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(_physical_rect(panel._hud)), "HUD outside screen %s/%s/%s: %s" % [resolution, language, tab, _physical_rect(panel._hud)])
					if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
						await _capture("tribe-%s-%dx%d-tab%d-scale%d-top" % [language, resolution.x, resolution.y, tab, roundi(scale * 100)])
					var page: Control = panel._tabs.get_current_tab_control()
					for button: Button in page.find_children("*", "Button", true, false):
						if not button.is_visible_in_tree(): continue
						panel._scroll.ensure_control_visible(button)
						await _frames(2)
						_expect(_physical_rect(panel._scroll).grow(1).encloses(_physical_rect(button)), "Unreachable translated action %s/%s/%s rect=%s scroll=%s" % [resolution, language, button.name, _physical_rect(button), _physical_rect(panel._scroll)])
					if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
						await _capture("tribe-%s-%dx%d-tab%d-scale%d-actions" % [language, resolution.x, resolution.y, tab, roundi(scale * 100)])

func _finish() -> void:
	print("TRIBE_LOCALIZATION_CHECKS: ", checks)
	await super._finish()
