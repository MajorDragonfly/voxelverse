extends "res://tests/tribal_age_test.gd"
## Real GUI, two occupied sites and in-transit care supplies. Isolated by the runner.
const Lab = preload("res://world/tribe/lab/husbandry_lab.gd")
const H = preload("res://world/tribe/village_husbandry.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")
var checks: int = 0
var _reload_delta: Dictionary = {}
var _lab: Node3D
var _egg_actor: Node3D
const EGG_ID := "locale-egg-animal"
const EGG_SPECIES := "locale-egg-species"

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	Engine.time_scale = 3.0
	root.size = Vector2i(1280, 800)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	_lab = load("res://world/tribe/lab/husbandry_lab.tscn").instantiate()
	scene = _lab
	root.add_child(scene)
	current_scene = scene
	await _until(func() -> bool: return _lab.ready_for_entry, 300)
	tribe = _lab.tribe
	home = _lab.home
	player = _lab.player
	if not _lab.ready_for_entry:
		_expect(false, "Husbandry fixture did not initialize")
		await _cleanup()
		_finish()
		return
	# Remove the lab's diagnostic overlay from product screenshots and click paths.
	_lab.banner.get_parent().hide()
	await _confirmation_checks()
	root.size = Vector2i(1280, 800)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.get_node("LocaleManager")._apply("en")
	await _click(tribe.panel.entry)
	await _frames(4)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return _lab.ready_for_work and tribe.is_active() and tribe.navigation.is_ready(), 1600)
	if not _lab.ready_for_work:
		_expect(false, "Confirmed transition did not enter working village")
		await _cleanup()
		_finish()
		return
	# Explicit test-only D1/D2 source, with distinct milk/egg identities.
	var a: Dictionary = Lab.D2.individual(EGG_ID, EGG_SPECIES, tribe.village().body_id, {"id": "locale-eggs-body", "revision": 1}, Vector3(7, 100.06, 7))
	a.merge({"status": "tamed", "trust": 100.0, "owner_faction_id": tribe.village().faction_id}, true)
	_lab.registry().animals[EGG_ID] = a
	_egg_actor = Node3D.new()
	scene.add_child(_egg_actor)
	_egg_actor.position = Vector3(7, 100.06, 7)
	_lab.box(_egg_actor, Vector3(0, 0.6, 0), Vector3(1, 1, 1), Color("ba995f"))
	tribe.husbandry.configure(_lab.registry,
		func(identity: String) -> Dictionary: return Lab.D1.suitability("eggs") if identity == EGG_SPECIES else _lab.traits(identity),
		func(identity: String) -> Node3D: return _egg_actor if identity == EGG_ID else _lab.live_actor(identity))
	tribe.select_all()
	tribe.panel._tabs.current_tab = 2
	for index in range(2):
		var kind: String = "pen" if index == 0 else "laying_site"
		tribe.panel.refresh()
		await _frames(3)
		await _click(tribe.panel._buttons[kind])
		_expect(tribe.placement == kind, "Translated build button issued wrong order")
		await _world_click(tribe.camera.unproject_position(Vector3(index * 7, 100.06, 7)), MOUSE_BUTTON_RIGHT)
		await _until(func() -> bool: return tribe.village().husbandry.pens.size() == index + 1 and tribe.navigation.is_ready(), 2000)
		if tribe.village().husbandry.pens.size() != index + 1:
			_expect(false, "Site construction failed: " + tribe.status)
			await _cleanup()
			_finish()
			return
		tribe.issue_order("wait")
		tribe.panel._pens.select(index)
		tribe.panel.refresh()
		await _frames(3)
		await _click(tribe.panel._bind_animal)
		_expect(tribe.village().husbandry.pens[index].animal_id == (Lab.ANIMAL if index == 0 else EGG_ID), "Translated assign button bound wrong animal")
	# The published member contract permits at most 32 characters.
	tribe.village().members[0].name = "HUSBANDRY_ASSIGN {count} LangeNa"
	tribe.panel.refresh()
	await _click(tribe.panel._buttons.tend)
	await _until(func() -> bool: return _care_cargo(), 600)
	_expect(_care_cargo(), "Real care order did not collect feed or water")
	paused = true
	tribe.panel._owns_pause = true
	tribe.panel.refresh()
	await _frames(3)
	await _locale_checks()
	await _layouts()
	# Restore real saved care cargo through the existing save consumer.
	paused = false
	tribe.panel._owns_pause = false
	root.size = Vector2i(1280, 800)
	root.get_node("DisplaySettings").ui_scale = 1.0
	_expect(saves.save_now(), "Care transport could not save")
	var snapshot: Dictionary = tribe.village().duplicate(true)
	_expect(saves.load_now(), "Care transport could not reload")
	for key: String in snapshot:
		if not _same_saved_value(snapshot[key], tribe.village().get(key)):
			_reload_delta[key] = {"before": snapshot[key], "after": tribe.village().get(key)}.duplicate(true)
	_expect(_reload_delta.is_empty() and _care_cargo(), "Reload changed site identities or care cargo")
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 1200)
	tribe.panel._tabs.current_tab = 2
	tribe.panel._pens.select(1)
	tribe.panel.refresh()
	await _frames(3)
	await _click(tribe.panel._release_animal)
	_expect(tribe.village().husbandry.pens[1].animal_id == "", "Translated release button did not release selected site")
	await _click(tribe.panel._change_site)
	_expect(tribe.village().husbandry.pens[1].kind == "pen", "Translated convert button did not convert empty site")
	await _cleanup()
	_finish()

func _confirmation_checks() -> void:
	var panel: CanvasLayer = tribe.panel
	await _click(panel.entry)
	_expect(panel.confirmation_open and paused and not panel.confirm.disabled, "Confirmation not available")
	var token: String = tribe._token
	var prepared: Dictionary = tribe._prepared.duplicate(true)
	var campaign: Dictionary = state.campaign.export_state()
	var path: String = saves.save_path
	var saved: String = FileAccess.get_file_as_string(path)
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		for scale: float in [1.0, 1.5]:
			root.get_node("DisplaySettings").ui_scale = scale
			for language: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(language)
				panel._layout()
				await _frames(8)
				_expect(tribe._token == token and tribe._prepared == prepared and state.campaign.export_state() == campaign, "Locale prepared or committed a new transition")
				_expect(FileAccess.get_file_as_string(path) == saved and paused and panel._owns_pause, "Locale wrote save or released confirmation pause")
				_expect(panel.confirm.text == ("Advance to the tribal age now" if language == "en" else "Jetzt ins Stammeszeitalter fortschreiten"), "Confirmation untranslated")
				var screen := Rect2(Vector2.ZERO, Vector2(dimensions)).grow(1)
				for control: Control in [panel._dialog, panel.confirm, panel.cancel]:
					_expect(screen.encloses(_physical_rect(control)), "Confirmation escaped screen %s/%s/%s: %s" % [dimensions, scale, language, _physical_rect(control)])
				panel._dialog_scroll.scroll_vertical = 9999
				await _frames(3)
				_expect(_physical_rect(panel._dialog_scroll).has_point(_physical_rect(panel._detail).end - Vector2(5, 5)), "End of confirmation text unreachable")
				if scale == 1.5:
					await _capture_view("husbandry-confirm-%s-%dx%d" % [language, dimensions.x, dimensions.y])
	# Actual confirmation save failure; changing language must retain failure/disabled action.
	var block := FileAccess.open("user://husbandry-locale-block", FileAccess.WRITE)
	block.store_string("not a directory")
	block.close()
	saves.save_path = "user://husbandry-locale-block/campaign.json"
	await _click(panel.confirm)
	_expect(panel.confirm.disabled and state.current_phase == 0 and panel.confirmation_open, "Failed confirmation changed phase or allowed retry")
	for language: String in ["en", "de"]:
		root.get_node("LocaleManager")._apply(language)
		await _frames(4)
		_expect(("could not be saved" if language == "en" else "konnte nicht gespeichert") in panel._detail.text, "Failure not retranslated")
		_expect(panel.confirm.disabled and FileAccess.get_file_as_string(path) == saved and state.current_phase == 0, "Language retried failed confirmation")
	saves.save_path = path
	await _click(panel.cancel)
	_expect(not paused and not panel.confirmation_open and state.current_phase == 0, "Cancel failed to restore creature phase")
	# A blocked confirmation is rendered from the original captured reason.
	player.position.x = 10
	await _frames(2)
	await _click(panel.entry)
	_expect(panel.confirm.disabled, "Far-away player allowed confirmation")
	root.get_node("LocaleManager")._apply("en")
	await _frames(3)
	_expect("Return home" in panel._detail.text, "Preparation blocker untranslated")
	await _click(panel.cancel)
	player.position.x = 0

func _locale_checks() -> void:
	var panel: CanvasLayer = tribe.panel
	var saved: String = FileAccess.get_file_as_string(saves.save_path)
	var campaign: Dictionary = state.campaign.export_state()
	var data: Dictionary = tribe.village().duplicate(true)
	var selected: Array = tribe.selected.duplicate()
	var rows: Array = panel._residents.get_children()
	var receipt: Dictionary = panel._feedback._receipt.duplicate(true)
	panel._pens.select(1)
	panel._animals.grab_focus()
	panel.refresh()
	await _frames(3)
	var animal_ids: Array = panel._animal_ids.duplicate()
	for language: String in ["de", "en", "de", "en"]:
		root.get_node("LocaleManager")._apply(language)
		await _frames(5)
		_expect(tribe.village() == data and state.campaign.export_state() == campaign and FileAccess.get_file_as_string(saves.save_path) == saved, "Language changed production, cargo or save")
		_expect(panel._pens.selected == 1 and panel._animals.selected == 0 and panel._animal_ids == animal_ids and panel._animals.has_focus(), "Language lost place/animal selection or focus")
		_expect(panel._tabs.current_tab == 2 and tribe.selected == selected and panel._residents.get_children() == rows and panel._feedback._receipt == receipt, "Language rebuilt controls or replayed command")
		_expect(panel._pens.get_item_text(0).begins_with("Dairy pen" if language == "en" else "Milchtierplatz") and panel._pens.get_item_text(1).begins_with("Laying site" if language == "en" else "Legestelle"), "Place kinds not translated")
		_expect(panel._animals.get_item_text(0).begins_with("Egg-laying animal" if language == "en" else "Eierlieferant"), "Animal selector not translated")
		_expect(panel._residents.get_child(0).text.begins_with(data.members[0].name), "Literal long name translated/interpolated")
		for p: Dictionary in data.husbandry.pens:
			var view: Dictionary = tribe.husbandry.describe(p)
			_expect(Presentation.husbandry_detail(view).begins_with("Feed" if language == "en" else "Futter"), "Live occupied place detail not translated")
		for legacy: String in Presentation.LEGACY:
			var translated: String = Presentation.legacy_status(legacy)
			_expect(translated != Presentation.LEGACY[legacy] and (language == "de" or translated != legacy), "Missing status translation: " + legacy)
		for resource: String in ["milk", "eggs"]:
			for status: String in ["producing", "supplies", "storage"]:
				var view: Dictionary = {"food": 1.5, "water": 2.5, "error": "", "state": status, "resource": resource, "seconds": 21, "yield": 2}
				var text: String = Presentation.husbandry_detail(view)
				_expect(("1.5" if language == "en" else "1,5") in text and "HUSBANDRY_" not in text and "{" not in text, "Production state/number not formatted")
	_expect(Presentation.legacy_status("Unknown diagnostic {count}") == "Unknown diagnostic {count}", "Unknown diagnostic altered")

func _layouts() -> void:
	var panel: CanvasLayer = tribe.panel
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		for scale: float in [1.0, 1.5]:
			root.get_node("DisplaySettings").ui_scale = scale
			for language: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(language)
				panel.refresh()
				await _frames(6)
				_expect(Rect2(Vector2.ZERO, Vector2(dimensions)).grow(1).encloses(_physical_rect(panel._hud)), "Husbandry panel outside viewport")
				for button: Button in panel._husbandry_page.find_children("*", "Button", true, false):
					if not button.is_visible_in_tree(): continue
					panel._scroll.ensure_control_visible(button)
					await _frames(2)
					_expect(_physical_rect(panel._scroll).grow(1).encloses(_physical_rect(button)), "Unreachable husbandry action %s/%s/%s: %s" % [dimensions, scale, language, button.name])
				if scale == 1.5:
					await _capture_view("husbandry-actions-%s-%dx%d" % [language, dimensions.x, dimensions.y])

func _care_cargo() -> bool:
	return tribe.village().members.any(func(m: Dictionary) -> bool: return not m.care_pen_id.is_empty() and m.cargo in ["food", "water"])

func _same_saved_value(a: Variant, b: Variant) -> bool:
	# JSON reads numbers as floats. Compare every key/value, allowing only numeric
	# representation and round-trip precision, never a missing ID/order/unit of cargo.
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) <= 1e-9 * maxf(1.0, absf(float(a)))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same_saved_value(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _same_saved_value(a[i], b[i]): return false
		return true
	return a == b

func _capture_view(label: String) -> void:
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await _capture(label)

func _finish() -> void:
	var report: Dictionary = {"checks": checks, "passed": failures.is_empty(), "failures": failures, "reload_delta": _reload_delta}
	var file := FileAccess.open("user://husbandry-localization-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("HUSBANDRY_LOCALIZATION_RESULT ", JSON.stringify(report))
	await super._finish()
