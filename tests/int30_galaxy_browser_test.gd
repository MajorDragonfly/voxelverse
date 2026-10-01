extends SceneTree
## Real catalogue UI, mouse/key routes, bounded costs and read-only visits.
const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Address = preload("res://world/space/galaxy_address.gd")
const BrowserPanel = preload("res://world/planet_lab/galaxy_catalog_panel.gd")
const P = preload("res://world/planet_lab/galaxy_browser_presentation.gd")
const Journal = preload("res://world/space/galaxy_journal.gd")
var failures: Array[String] = []
var checks: int = 0
var visits_read: int = 0
var visits: Dictionary = {}
var travel_requests: Array = []
var panel: CanvasLayer
var catalog: RefCounted
var capture: bool = false
var translation_fixtures: Array[Translation] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	capture = "--capture" in OS.get_cmdline_user_args()
	root.get_node("LocaleManager")._apply("de")
	root.size = Vector2i(1280, 720)
	catalog = Catalog.new("9007199254740993")
	var sector: Dictionary = catalog.sector_at([0, 0, 0])
	var first: String = sector.systems[0].id
	panel = BrowserPanel.new()
	panel.catalog = catalog
	panel.initial_system_id = first
	panel.journal_directory = "user://int30_galaxy_browser"
	panel.visit_reader = _read_visit
	panel.visit_requested.connect(func(system_id: String, body_id: String): travel_requests.append([system_id, body_id]))
	root.add_child(panel)
	await _frames(5)
	_expect(panel.selected_id == first and panel.system_list.item_count <= P.PAGE_SIZE, "Initial system/page selection")
	var immutable: String = JSON.stringify(catalog.system(first))
	var initial_generations: int = catalog.stats().system_generations
	# Navigating a page opens only the one selected system, never its whole page.
	if sector.systems.size() > P.PAGE_SIZE:
		await _click(panel.next_page)
		_expect(panel._page == 1 and panel.selected_id == sector.systems[P.PAGE_SIZE].id, "Next page mouse route")
		_expect(catalog.stats().system_generations - initial_generations <= 1, "Page eagerly generated every system")
		await _click(panel.previous_page)
		_expect(panel._page == 0 and panel.selected_id == first, "Previous page mouse route")
	await _search("No-such-system")
	_expect(panel.system_list.item_count == 0 and panel.visit_button.disabled and panel.record.is_empty(), "Empty search retained a stale destination")
	await _search(sector.systems[0].name)
	_expect(panel.selected_id == first and panel.system_list.item_count == 1, "Current sector name filter")
	var remote: Dictionary = catalog.sector_at([1000, 0, -700])
	var remote_id: String = remote.systems[-1].id
	await _search(remote_id)
	_expect(panel.selected_id == remote_id and panel.coordinates[0].value == 1000, "Canonical system search failed to navigate sector/page")
	var remote_system: Dictionary = catalog.system(remote_id)
	for body: Dictionary in P.ordered_bodies(remote_system):
		await _search(body.id)
		_expect(panel.inspection_list.get_item_metadata(panel.inspection_list.selected) == body.id and body.name in panel.body_description.text, "Canonical body search did not select detail")
		_expect(panel.visit_button.disabled == not body.landable, "Non-landable inspection allowed travel")
		_expect("km" in panel.body_description.text and "m/s²" in panel.body_description.text, "Body detail lacks physical units")
		if body.kind == "moon":
			_expect(remote_system.bodies[body.parent_id].name in panel.body_description.text, "Moon orbit did not identify its real parent")
	var selected_before: String = panel.selected_id
	for query: String in ["vx2/u1/g0", "vx1/u1/g0/s0,0,0/t0", remote_id + "/b63", "vx1/u9007199254740993/g0/s1000000001,0,0"]:
		await _search(query)
		_expect(panel.selected_id == selected_before, "Invalid or absent address changed selection")
	await _search(remote_system.name)
	_expect(panel.selected_id == remote_id and "Kennung ist ungültig" not in panel.message.text, "Successful name search retained a stale address error")
	await _search(Address.sector_id(catalog.universe_seed, 0, [-1000000000, 1000000000, 1000000000]))
	_expect(panel.systems.is_empty() and panel.coordinates[0].value == -1000000000 and panel.coordinates[2].value == 1000000000, "Large address rounded or invented stars")
	_expect(panel.inspection_list.item_count == 0 and panel.body_description.text.is_empty(), "Empty sector retained body detail")
	_expect(P.resolve(catalog, Address.body_id(first, 63)).is_empty(), "Absent canonical body slot accepted")
	var near: Dictionary = {"sector": ["999999999", "0", "0"], "offset_ly": [15.999999, 0.0, 0.0]}
	var far: Dictionary = {"sector": ["1000000000", "0", "0"], "offset_ly": [0.000001, 0.0, 0.0]}
	var delta: Array = Address.relative_ly(far, near)
	_expect(absf(delta[0] - 0.000002) < 0.000000001, "Large-sector relative distance lost precision")
	_expect("149597870.7" in P.orbit_distance(Catalog.AU_M).replace(",", "."), "AU/km conversion is wrong")
	# Stream many sectors through the actual panel, then return after eviction.
	var saw: Dictionary = {"single": false, "binary": false, "planet": false, "moon": false, "gas_giant": false}
	for index in range(80):
		panel.show_sector([index * 17 - 600, 0, index * 7 - 240])
		_expect(panel.system_list.item_count <= P.PAGE_SIZE, "Unbounded page Controls")
		_expect(catalog.stats().sectors <= Catalog.SECTOR_CACHE_LIMIT and catalog.stats().systems <= Catalog.SYSTEM_CACHE_LIMIT, "Cache limit exceeded")
		for entry: Dictionary in panel.systems:
			saw["binary" if entry.star_count == 2 else "single"] = true
		if not panel._system.is_empty():
			for body: Dictionary in panel._system.bodies.values():
				if saw.has(body.kind): saw[body.kind] = true
	for kind: String in saw:
		_expect(saw[kind], "Fixture did not cover " + kind)
	panel.show_sector([0, 0, 0])
	_expect(JSON.stringify(catalog.system(first)) == immutable and catalog.system(first) == Catalog.new(catalog.universe_seed).system(first), "Navigation/eviction changed deterministic catalogue")
	var landable: String = panel.body_list.get_item_metadata(panel.body_list.selected)
	visits = {"error": OK, "record": {"system_id": first, "bodies": {landable: {"terrain_revision": 3, "location": {"face": 0, "u": 0.25, "v": -0.5, "height": 5.0}, "forward": [0.0, 0.0, 1.0]}}}}
	var original_visits: String = JSON.stringify(visits)
	panel.select_system(0)
	_expect("Rückkehrpunkt" in panel.body_description.text, "Saved visit not shown")
	for index in range(panel.inspection_list.item_count):
		panel.inspection_list.select(index)
		panel._inspect_body()
	_expect(JSON.stringify(visits) == original_visits and travel_requests.is_empty(), "Inspection wrote visits or requested travel")
	var supported_visits: Dictionary = visits.duplicate(true)
	visits = {"error": ERR_UNAVAILABLE}
	panel.select_system(0)
	_expect("nicht verfügbar" in panel.body_description.text, "Unsupported visit data presented as unvisited")
	visits = supported_visits
	panel.travel_in_progress = true
	panel.search.text = remote_id
	panel.search_catalog()
	panel.change_page(1)
	panel.show_sector([1, 0, 1])
	panel.request_visit()
	_expect(panel.selected_id == first and travel_requests.is_empty(), "Navigation or duplicate request while travelling")
	panel.travel_in_progress = false
	panel.select_system(0)
	panel.note.text = "Preserve existing journal contract"
	panel._changed()
	_expect(panel.save_changes(), "Existing note save broke")
	var file_before: String = FileAccess.get_file_as_string(panel.journal.record_path(first))
	panel.show_sector([1000, 0, -700])
	panel.show_sector([0, 0, 0])
	_expect(panel.note.text == "Preserve existing journal contract" and FileAccess.get_file_as_string(panel.journal.record_path(first)) == file_before, "Browsing rewrote or lost saved note")
	panel._select_body()
	await _scroll_to(panel.visit_button)
	await _click(panel.visit_button)
	_expect(travel_requests == [[first, landable]], "Visit click changed existing signal IDs")
	# Real small viewport and whole-page scroll; all actions remain reachable.
	root.size = Vector2i(800, 600)
	for scale: float in [1.0, 1.5]:
		root.get_node("DisplaySettings").ui_scale = scale
		panel._layout()
		await _frames(5)
		_expect(panel._content.vertical, "Small viewport did not stack columns at " + str(scale))
		await _scroll_to(panel.save_button)
		_expect(_physical(panel.save_button).position.y >= 0 and _physical(panel.save_button).end.y <= 600, "Save action unreachable at 800x600 scale=" + str(scale))
	root.get_node("DisplaySettings").ui_scale = 1.0
	panel._layout()
	if capture:
		await _captures()
	print("INT30_GALAXY_BROWSER ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "cache": catalog.stats(), "page_limit": P.PAGE_SIZE, "visit_reads": visits_read, "kinds": saw, "visit_writes": 0, "scope": "standalone catalogue UI, not campaign exploration"}))
	panel.queue_free()
	await _frames(3)
	for fixture: Translation in translation_fixtures:
		TranslationServer.remove_translation(fixture)
	for failure: String in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _read_visit(_id: String) -> Dictionary:
	visits_read += 1
	return visits.duplicate(true)

func _search(query: String) -> void:
	await _scroll_to(panel.search)
	panel.search.text = query
	panel.search.grab_focus()
	panel.search.edit()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames(2)

func _physical(control: Control) -> Rect2:
	var canvas: Transform2D = control.get_global_transform_with_canvas()
	var factor: float = float(root.size.x) / root.get_visible_rect().size.x
	return Rect2(canvas.origin * factor, control.size * canvas.get_scale() * factor)

func _click(control: Control) -> void:
	await _scroll_to(control)
	var position: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		root.push_input(event, true)
	await _frames(3)

func _scroll_to(control: Control) -> void:
	var scroll: ScrollContainer = panel.find_child("GalaxyScroll", true, false)
	scroll.ensure_control_visible(control)
	await _frames(3)

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition and message not in failures: failures.append(message)

func _captures() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = size
		DisplayServer.window_set_size(size)
		panel.show_sector([0, 0, 0])
		await _frames(5)
		var scroll: ScrollContainer = panel.find_child("GalaxyScroll", true, false)
		scroll.scroll_vertical = 0
		await _frames(3)
		await RenderingServer.frame_post_draw
		var prefix: String = "user://galaxy-%dx%d" % [size.x, size.y]
		_expect(root.get_texture().get_image().save_png(prefix + "-navigation.png") == OK, "Navigation capture failed")
		await _scroll_to(panel.body_description)
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(prefix + "-body.png") == OK, "Body capture failed")
		if size.x == 1280:
			for index in range(panel.inspection_list.item_count):
				var body: Dictionary = panel._system.bodies[panel.inspection_list.get_item_metadata(index)]
				if body.kind == "star":
					panel.inspection_list.select(index)
					panel._inspect_body()
					await _frames(3)
					await RenderingServer.frame_post_draw
					_expect(root.get_texture().get_image().save_png(prefix + "-star.png") == OK, "Star capture failed")
					break

	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var captured: Dictionary = {"single": false, "moon": false, "gas_giant": false}
	for entry: Dictionary in catalog.sector_at([0, 0, 0]).systems:
		var system: Dictionary = catalog.system(entry.id)
		for body: Dictionary in P.ordered_bodies(system):
			var tag: String = "single" if system.star_count == 1 and body.kind == "star" else str(body.kind)
			if not captured.has(tag) or captured[tag]: continue
			await _search(body.id)
			await _scroll_to(panel.body_description)
			await RenderingServer.frame_post_draw
			_expect(root.get_texture().get_image().save_png("user://galaxy-1280x720-" + tag + ".png") == OK, "Body kind capture failed: " + tag)
			captured[tag] = true
	for tag: String in captured:
		_expect(captured[tag], "Capture fixture lacks " + tag)
	panel.show_sector([-1000000000, 1000000000, 1000000000])
	await _frames(4)
	var scroll: ScrollContainer = panel.find_child("GalaxyScroll", true, false)
	scroll.scroll_vertical = 0
	await _frames(3)
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("user://galaxy-1280x720-empty.png") == OK, "Large empty sector capture failed")

	root.size = Vector2i(800, 600)
	DisplayServer.window_set_size(root.size)
	root.get_node("DisplaySettings").ui_scale = 1.5
	panel._layout()
	panel.show_sector([0, 0, 0])
	await _frames(5)
	scroll.scroll_vertical = 0
	await _frames(3)
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("user://galaxy-800x600-scale150-navigation.png") == OK, "Scaled navigation capture failed")
	await _scroll_to(panel.body_description)
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("user://galaxy-800x600-scale150-body.png") == OK, "Scaled body capture failed")
	root.get_node("DisplaySettings").ui_scale = 1.0

	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	panel._layout()
	panel.show_sector([0, 0, 0])
	await _search("vx2/u1/g0")
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("user://galaxy-1280x720-invalid-id.png") == OK, "Address feedback capture failed")
