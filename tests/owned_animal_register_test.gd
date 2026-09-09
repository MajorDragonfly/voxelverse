extends SceneTree
## Actual D2 controller, lab persistence and shared book; no copied D2 simulation.
const Preview = preload("res://tests/fixtures/owned_animal_d2_preview.gd")
const CAMPAIGN_SENTINEL := "user://task7_campaign_sentinel.json"
var failures: Array[String] = []
var fixture: Node3D
var journal: CanvasLayer
var captures := ""
var commits := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		captures = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(captures)
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = CAMPAIGN_SENTINEL
	var sentinel := FileAccess.open(CAMPAIGN_SENTINEL, FileAccess.WRITE)
	sentinel.store_string("campaign must stay unchanged")
	sentinel.close()
	var before: String = JSON.stringify(root.get_node("ProgressionService").export_state())
	var heard: Array = []
	root.get_node("AudioManager").orders.feedback_played.connect(func(_order, _id, _ok): heard.append(_id))
	fixture = Preview.new()
	root.add_child(fixture)
	journal = fixture.journal
	await _frames(4)
	_expect(journal.is_open and paused and get_nodes_in_group(&"discovery_journal").size() == 1, "Shared book/pause missing")
	if fixture.lab == null:
		_expect(journal._rows.is_empty() and journal._description.text.contains("nicht verfügbar"), "Missing D2 claims animal ownership")
		await _finish(false)
		return
	var lab: Node3D = fixture.lab
	var d2: RefCounted = lab.controller
	var id: String = lab.fixture.ANIMAL
	d2.animal_changed.connect(func(_id: String, _code: String): commits += 1)
	if "--verify-reload" in args:
		_expect(journal._rows.size() == 1 and journal._rows[0]["key"] == id and journal._rows[0]["order"].begins_with("Heimkehr"), "Separate-process load lost ownership/order/ID")
		await _finish(true)
		return
	lab.reset_probe()
	journal.refresh_owned_animals()
	_expect(journal._rows.is_empty(), "Wild animal shown as owned")
	lab._friend()
	journal.refresh_owned_animals()
	_expect(journal._rows.is_empty(), "Friendship shown as ownership")
	journal.close_journal()
	await _frames(3)
	# Freeze only automatic lab simulation; actions still use D2 + real ray/context.
	lab.set_physics_process(false)
	lab.animal.set_physics_process(false)
	for meal in range(4):
		_expect(d2.begin_offer(id, "roots", lab.live_context())["ok"], "D2 offer failed")
		for tick in range(8):
			_expect(d2.advance_offer(id, 0.25, lab.live_context())["ok"], "D2 meal did not advance")
		if meal < 3:
			journal.open_journal()
			_expect(journal._rows.is_empty(), "Unfinished taming counted as own animal")
			journal.close_journal()
			await _frames(3)
	_expect(lab.snapshot["stock"]["roots"] == 8 and d2.record(id)["trust"] == 100.0, "Real D2 food/trust transaction failed")
	journal.open_journal()
	_expect(journal._rows.size() == 1 and journal._rows[0]["trust"] == "100 / 100", "D2 trust unit or ownership projection wrong")
	var initial: String = JSON.stringify(d2.registry)
	var initial_save: String = FileAccess.get_file_as_string(lab.store.path)
	var writes: int = commits
	journal.refresh()
	journal.refresh_owned_animals()
	_expect(JSON.stringify(d2.registry) == initial and commits == writes and heard.is_empty() and FileAccess.get_file_as_string(lab.store.path) == initial_save, "Reading wrote, sounded or emitted D2 actions")
	journal.close_journal()
	await _frames(3)
	_expect(d2.command(id, "follow", lab.live_context())["ok"], "D2 follow failed")
	journal.open_journal()
	_expect(journal._rows[0]["order"].contains("Prüfbetreuer"), "Follow lacks concrete handler")
	_expect(not d2.command(id, "home", lab.live_context())["ok"], "Book pause allowed a D2 command")
	journal.close_journal()
	await _frames(3)
	lab.store.blocked = true
	writes = commits
	_expect(not d2.command(id, "home", lab.live_context())["ok"], "Blocked D2 store accepted order")
	journal.open_journal()
	_expect(commits == writes and journal._rows[0]["order"].begins_with("Folgen"), "Failed save displayed success/new order")
	lab.store.blocked = false
	journal.close_journal()
	await _frames(3)
	_expect(d2.command(id, "wait", lab.live_context())["ok"], "D2 wait failed")
	journal.open_journal()
	_expect(journal._rows[0]["order"].contains("Warten · Ziel:"), "Wait target missing")
	journal.close_journal()
	await _frames(3)
	d2.record_position(id, Vector3(3, 0, 2))
	_expect(d2.command(id, "home", lab.live_context())["ok"], "D2 home failed")
	journal.open_journal()
	_expect(journal._rows[0]["location"].contains("X 3") and journal._rows[0]["order"].begins_with("Heimkehr"), "Home request confused with arrival/current position")
	# Body/faction changes must evict previous entries while the page remains open.
	var scope: Dictionary = fixture._context()
	journal.bind_owned_animals(d2, func(): return scope, fixture._names)
	scope["faction_id"] = "different_faction"
	await _frames(2)
	_expect(journal._rows.is_empty(), "Foreign faction leaked previous animal")
	scope["faction_id"] = ""
	await _frames(2)
	_expect(journal._rows.is_empty() and journal._description.text.contains("aktuell"), "Empty faction queried unowned animals")
	scope["faction_id"] = lab.fixture.FACTION
	scope["body_id"] = "different_body"
	await _frames(2)
	_expect(journal._rows.is_empty() and journal._description.text.contains("aktuell"), "Foreign body reused previous registry")
	scope["body_id"] = lab.fixture.BODY
	scope["campaign_id"] = "different_campaign"
	await _frames(2)
	_expect(journal._rows.is_empty() and journal._description.text.contains("aktuell"), "Foreign campaign reused previous registry")
	scope = fixture._context()
	journal.bind_owned_animals(d2, fixture._context)
	_expect(journal._rows[0]["name"].contains("Unbenanntes Tier") and journal._rows[0]["species"].contains("nicht bekannt"), "Missing names invented data")
	journal.bind_owned_animals(d2, fixture._context, fixture._names)
	var original_registry: Dictionary = d2.registry.duplicate(true)
	d2.registry["schema"] = 2
	await _frames(2)
	_expect(journal._rows.is_empty() and journal._description.text.contains("nicht gelesen"), "Planar positions accepted as spherical D2 registry")
	var animal_state = preload("res://world/domestication/animal_state.gd")
	var spherical: Dictionary = original_registry.duplicate(true)
	spherical.schema = animal_state.SCHEMA
	for record: Dictionary in spherical.animals.values():
		record.surface_mode = animal_state.Home.Cube.MODE
		for field in ["position", "home", "wait_position"]:
			var point: Dictionary = animal_state.Home.Cube.address(record.body_id, 0, 0.25, 0.5, 12.0)
			point.radius = 6371000.0
			record[field] = point
	d2.registry = spherical
	journal.refresh_owned_animals()
	_expect(journal._rows.size() == 1 and journal._rows[0].location.contains("Breite") and journal._rows[0].order.contains("Höhe"), "Shared animal book did not project canonical spherical positions")
	d2.registry.schema = animal_state.SCHEMA + 1
	await _frames(2)
	_expect(journal._rows.is_empty() and journal._description.text.contains("nicht gelesen"), "Future D2 schema interpreted as current")
	d2.registry = original_registry
	await _frames(2)
	_expect(journal._rows.size() == 1, "Valid registry did not return after scope refresh")
	# Same-controller load is silent in D2, so the existing host load hook refreshes.
	var saved: String = FileAccess.get_file_as_string(lab.store.path)
	d2.record_position(id, Vector3(9, 0, 9))
	journal.refresh_owned_animals()
	_expect(journal._rows[0]["location"].contains("X 9"), "Current controller position not read")
	fixture.load_probe()
	lab.animal.set_physics_process(false)
	_expect(journal._rows[0]["location"].contains("X 3") and FileAccess.get_file_as_string(lab.store.path) == saved, "Load hook kept stale position or rewrote save")
	# Exactly one live signal connection after rebinding; confirmed death updates now.
	_expect(d2.get_signal_connection_list("animal_changed").size() == 2, "Rebinding duplicated readers")
	_expect(d2.damage(id, 100.0)["ok"], "D2 death transaction failed")
	_expect(journal._rows.is_empty(), "Confirmed death did not refresh living list")
	journal._filter.select(1)
	journal._apply_filters()
	_expect(journal._rows.size() == 1 and journal._rows[0]["dead"] and journal._rows[0]["order"] == "Kein aktiver Auftrag", "Death history misrepresents active ownership/order")
	# Restore the real saved snapshot through D2's store for restart verification.
	_expect(lab.store.write_snapshot(JSON.parse_string(saved)), "Could not restore D2 saved fixture")
	fixture.load_probe()
	lab.animal.set_physics_process(false)
	journal._filter.select(0)
	journal._apply_filters()
	journal._search.text = "Heimkehr"
	journal._apply_filters()
	_expect(journal._rows.size() == 1, "Order search failed")
	journal._search.clear()
	journal._apply_filters()
	for extent in [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(640, 480)]:
		root.size = extent
		await _frames(5)
		_expect(journal._panel.size.x <= extent.x and journal._panel.size.y <= extent.y, "Animal tab overflows " + str(extent))
		_expect(journal._owned_register.is_visible_in_tree(), "Register not in shared book")
		journal._detail_scroll.scroll_vertical = 10000
		await _frames(3)
		var last: Control = journal._owned_register._entries.get_child(journal._owned_register._entries.get_child_count() - 1)
		_expect(last.get_global_rect().end.y <= journal._detail_scroll.get_global_rect().end.y + 1, "Animal identity unreachable by scroll")
		await _capture("animals_%dx%d" % [extent.x, extent.y])
		journal._detail_scroll.scroll_vertical = 0
		await _frames(2)
		await _capture("animals_top_%dx%d" % [extent.x, extent.y])
		await _click(journal._close)
		_expect(not journal.is_open and not paused, "Close/pause inaccessible " + str(extent))
		journal.open_journal()
	_expect(JSON.stringify(root.get_node("ProgressionService").export_state()) == before, "Animal display awarded discovery/progression")
	journal.unbind_owned_animals()
	_expect(journal._rows.is_empty() and d2.get_signal_connection_list("animal_changed").size() == 1, "Unbind retained animals or event subscription")
	var temporary: RefCounted = d2.get_script().new()
	temporary.configure(d2.registry, Callable())
	journal.bind_owned_animals(temporary, fixture._context)
	temporary = null
	await _frames(2)
	_expect(journal._rows.is_empty() and journal._description.text.contains("nicht verfügbar"), "Freed controller left stale animals")
	await _finish(true)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _frames(3)

func _capture(label: String) -> void:
	if captures.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(label + ".png"))

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish(d2_checked: bool) -> void:
	fixture.queue_free()
	await _frames(3)
	_expect(FileAccess.get_file_as_string(CAMPAIGN_SENTINEL) == "campaign must stay unchanged", "D2 book preview wrote the campaign save")
	print(JSON.stringify({"test": "owned_animal_register", "passed": failures.is_empty(), "d2_checked": d2_checked, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
