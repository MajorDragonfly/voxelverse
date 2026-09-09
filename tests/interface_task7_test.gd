extends "res://tests/tribal_age_test.gd"
## Real group/book integration. D1 positive cases use its reviewed validator only.
const Suitability = preload("res://ui/discovery/animal_suitability.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
var d1_checked := false

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
	_expect(home.establish_home()["ok"], "Fixture home failed")
	await _frames(15)
	_expect(tribe.panel.open_confirmation(), "Real confirmation did not open")
	await _click(tribe.panel.confirm)
	await _frames(15)
	_expect(tribe.is_active(), "Confirmed group is not active")
	if not tribe.is_active():
		await _cleanup()
		_finish()
		return
	var journal: Node = player.get_node("ProgressionHUD")._discovery_journal
	var progression: Node = root.get_node("ProgressionService")
	var audio: Node = root.get_node("AudioManager")
	audio.orders.bind_source(tribe)
	var heard: Array[bool] = []
	audio.orders.feedback_played.connect(func(_order: StringName, _id: String, ok: bool): heard.append(ok))
	tribe.select_all()
	_expect(tribe.issue_order("wait"), "Accepted wait missing")
	_expect(tribe.panel._message.text.contains("3 Bewohner gespeichert"), "Accepted receipt lacks affected group size")
	_expect(not tribe.issue_order("hut"), "Invalid build accepted")
	_expect(heard == [true, false], "Immediate failure was masked by success debounce")
	_expect(tribe.panel._message.text.contains("Nicht ausgeführt") and tribe.panel._message.text.contains("Steinwerkzeug"), "Build rejection lacks actual reason")
	tribe.selected.clear()
	_expect(not tribe.issue_order("wood"), "Empty selection accepted")
	_expect(tribe.panel._message.text.contains("Wähle zuerst") and tribe.panel._feedback.selection.text.begins_with("Niemand"), "Empty selection reused stale status")
	tribe.select_all()
	var blocked := FileAccess.open("user://blocked-parent", FileAccess.WRITE)
	blocked.store_string("not a directory")
	blocked.close()
	var before_order: Dictionary = tribe.village().duplicate(true)
	saves.save_path = "user://blocked-parent/campaign.json"
	_expect(not tribe.issue_order("wood"), "Failed save acknowledged success")
	_expect(tribe.village() == before_order and tribe.panel._message.text.contains("Speichern fehlgeschlagen"), "Save failure lost order or feedback")
	saves.save_path = SAVE
	var receipt_count: int = heard.size()
	_expect(not audio.orders.play_result(&"move", "throttled", true), "Rapid success was not suppressed")
	await create_timer(0.25).timeout
	_expect(not audio.orders.play_result(&"move", "throttled", true) and heard.size() == receipt_count, "Suppressed duplicate played later")
	await _test_d1(journal, progression)
	for extent in [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(640, 480)]:
		root.size = extent
		await _frames(5)
		tribe.panel.refresh()
		await _frames(3)
		_expect(tribe.panel._hud.position.y > 0, "Group HUD exceeds window at " + str(extent))
		tribe.panel._orders_scroll.ensure_control_visible(tribe.panel._buttons["wait"])
		await _frames(3)
		await _click(tribe.panel._buttons["wait"])
		_expect(tribe.panel._message.text.contains("gespeichert"), "Scrolled order button unreachable at " + str(extent))
		await _capture("group_%dx%d" % [extent.x, extent.y])
		await _click(tribe.panel._feedback.find_child("OpenGroupJournal", true, false))
		_expect(journal.is_open, "Group book button inaccessible")
		await _frames(3)
		_expect(not tribe.panel._hud.visible, "Group panel covers modal book")
		journal._close.release_focus()
		var frozen: Dictionary = tribe.village().duplicate(true)
		_key(KEY_SPACE)
		_key(KEY_F7)
		await _frames(3)
		_expect(paused and journal.is_open and tribe.village() == frozen and not is_instance_valid(audio._panel), "Modal pause leaked an input or gameplay tick")
		_expect(journal._panel.size.x <= extent.x and journal._panel.size.y <= extent.y, "Book overflow at " + str(extent))
		_expect(journal._close.get_global_rect().end.x <= extent.x and journal._close.get_global_rect().end.y <= extent.y, "Close button outside window")
		if extent.x < 960:
			_expect(journal._compact_tabs.visible, "Compact tab selector unavailable")
			journal._compact_tabs.item_selected.emit(2)
			_expect(journal._tabs.current_tab == 2, "Compact selector did not switch shared book")
			journal._compact_tabs.item_selected.emit(0)
		for tab in journal._tabs.tab_count:
			journal._tabs.current_tab = tab
			await _frames(3)
			_expect(journal._panel.size.x <= extent.x and journal._panel.size.y <= extent.y, "Tab %d overflows %s" % [tab, extent])
		journal._tabs.current_tab = 0
		journal._selected_key = "15838:771338" if d1_checked else "15838:771337"
		journal.refresh()
		await _frames(3)
		await _capture("book_%dx%d" % [extent.x, extent.y])
		await _click(journal._roles_toggle)
		await _frames(3)
		_expect(journal._animal_roles.visible, "Role details toggle unreachable")
		await _capture("roles_%dx%d" % [extent.x, extent.y])
		journal.close_journal()
		await _frames(3)
		_expect(not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and tribe.panel._hud.visible, "Book did not restore group input")
	var before_reload: Dictionary = progression.export_state().duplicate(true)
	_expect(saves.save_now() and saves.load_now(), "Existing campaign save/load failed")
	await _frames(8)
	_expect(JSON.parse_string(JSON.stringify(progression.export_state())) == JSON.parse_string(JSON.stringify(before_reload)) and get_nodes_in_group(&"discovery_journal").size() == 1, "Reload changed discoveries or duplicated book")
	await _cleanup()
	print(JSON.stringify({"test": "interface_task7", "passed": failures.is_empty(), "d1_checked": d1_checked, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _test_d1(journal: Node, progression: Node) -> void:
	var validator: Script = Suitability.contract()
	# Optional external copy of exact contract commit for isolated dependency QA.
	var path := OS.get_environment("VOXELVERSE_D1_CONTRACT")
	if validator == null and not path.is_empty():
		validator = load(path) as Script
	var blueprint: Dictionary = preload("res://creatures/wildlife/species_assembly_factory_v7.gd").create_species(771337, Vector2i(1, -2), "grazer")
	var entry := {"scan": {"version": 1, "complete": true}, "journal": Records.observation(blueprint, "Prüfplanet")}
	_expect(Suitability.read(entry, validator).is_empty(), "Ecological grazer invented animal suitability")
	_expect(Suitability.describe({}).contains("keine lesbaren"), "Legacy entry claims actual measurements")
	progression.register_species_discovery(771337, blueprint, 15838)
	if validator == null:
		return
	d1_checked = true
	for group in ["milk", "work", "companion"]:
		blueprint["species"]["domestication"] = validator.call("suitability", group)
		entry["journal"] = Records.observation(blueprint, "Prüfplanet")
		var serialized := JSON.stringify(entry)
		var unscanned: Dictionary = entry.duplicate(true)
		unscanned["scan"]["complete"] = false
		_expect(Suitability.read(unscanned, validator).is_empty(), "Friendship exposed unscanned roles")
		var profile: Dictionary = Suitability.read(entry, validator)
		_expect(not profile.is_empty(), "Reviewed D1 role rejected: " + group)
		if profile.is_empty():
			continue
		_expect(JSON.stringify(entry) == serialized, "D1 display mutated saved observation")
		var text := Suitability.describe(profile)
		_expect(text.contains("kein Tierbesitz") and text.contains("300 Spielsekunden"), "Suitability lost unit/ownership distinction")
		if group == "milk":
			_expect(text.contains("2 l je 300 aktive Spielsekunden"), "Milk units differ from D1")
		if group == "work":
			_expect(text.contains("1800 N") and text.contains("120 kg"), "Draught/riding units differ from D1")
		blueprint["species"]["domestication"]["schema"] = 2
		entry["journal"] = Records.observation(blueprint, "Prüfplanet")
		_expect(Suitability.read(entry, validator).is_empty(), "Future schema interpreted as v1")
	blueprint["species"]["domestication"] = validator.call("suitability", "milk")
	var discovery: Dictionary = progression.register_species_scan(771338, blueprint, 15838)
	var points: int = progression.discovery_points
	journal._animal_contract = validator
	journal.open_journal()
	journal._selected_key = discovery["species_key"]
	journal.refresh()
	_expect(journal._animal_roles.text.contains("Milchtier"), "Existing book did not render actual D1 observation")
	_expect(journal._species_rows("", "domestic:milk").size() == 1 and journal._species_rows("", "domestic:riding").is_empty(), "Role filter invents catalog records")
	_expect(journal._species_rows("Milchtier", "").size() == 1, "Role label search failed")
	journal.close_journal()
	await _frames(3)
	_expect(progression.discovery_points == points, "Reading suitability rewarded a second discovery")
