extends "world_map_test.gd"
## Real map, native input, filtered archived pages, save/restart and small UI.
const Query = preload("res://ui/world_map/atlas_place_query.gd")
const Presentation = preload("res://ui/world_map/atlas_presentation.gd")
var checks: int = 0

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)

func _test_model() -> void:
	super._test_model()
	var atlas := Atlas.new()
	atlas.bind(Atlas.create("search-sphere", Cube.MODE, 6371000))
	for i in range(1025):
		atlas.remember(Source._place("place-%d" % i, "Polar needle" if i == 1024 else "Landscape %d" % i, "nest", "species", "", true, Cube.address("search-sphere", i % 6, 0.1, 0.2)))
	var before: String = JSON.stringify(atlas.data)
	var query := Query.new()
	query.begin(atlas, " NEEDLE ", true, true, 0, func(_p: Dictionary) -> bool: return true, Presentation.place_name)
	_drain(query)
	_expect(query.results.size() == 1 and query.results[0].id == "place-1024", "Search did not cross all archived sphere pages")
	_expect(query.scanned == 1025 and not query.has_next, "Search did not finish the entire register")
	_expect(JSON.stringify(atlas.data) == before and atlas.places.store.cache.size() <= 96 and atlas.places.store.pages.size() <= 128, "Search changed saved data or grew caches")
	query.begin(atlas, "Landscape", true, true, 0, func(_p: Dictionary) -> bool: return true, Presentation.place_name)
	query.step()
	query.cancel()
	query.step()
	_expect(not query.active and query.results.is_empty(), "Cancelled search retained pending work")
	query.begin(atlas, "", true, true, 0, func(_p: Dictionary) -> bool: return true, Presentation.place_name)
	atlas.bind(Atlas.create("other-body", Cube.MODE, 6371000))
	query.step()
	_expect(query.invalidated and query.results.is_empty(), "Body rebind published stale search results")
	# A newer archived payload must fail the query, never become 'no matches'.
	var bad := Atlas.new()
	bad.bind(JSON.parse_string(before))
	var writer := preload("res://core/persistence/region_store.gd").new()
	writer.put("o:0", {"schema": 1, "body_id": "search-sphere", "id": "place-0"})
	writer.put("p:place-0", {"schema": 99})
	var corrupt: Dictionary = bad.data.duplicate(true)
	corrupt.place_storage = writer.checkpoint()
	bad.bind(corrupt)
	query.begin(bad, "", true, true, 0, func(_p: Dictionary) -> bool: return true, Presentation.place_name)
	_drain(query)
	_expect(query.failed and query.results.is_empty() and not bad.last_error.is_empty(), "Unreadable archive masqueraded as empty search")

func _drain(query: RefCounted) -> void:
	for tick in range(10000):
		if not query.active: break
		var before: int = query.scanned
		query.step()
		_expect(query.scanned - before <= Query.RECORDS_PER_STEP and query.results.size() <= Query.PAGE_SIZE, "Query exceeded per-step work or result-page budget")
	_expect(not query.active, "Query did not terminate")

func _layouts() -> void:
	var body: Dictionary = state.get_current_body_record()
	var original: Dictionary = body.exploration_atlas.duplicate(true)
	# First four raw pages do not match; 65 matches must span two full filtered
	# pages, independent of both disk index pages and ownership filtering.
	for i in range(386):
		var name: String = "Waldrand %03d" % i if i < 256 else ("Nadelöhr {name} %03d" % i if i % 2 == 0 else "Feld %03d" % i)
		map.tracker.atlas.remember(Source._place("search-place-%d" % i, name, "nest", state.campaign.data.player_species_id, "", true, Surface.plane_address(body.id, Vector3(i, 100, i))))
	_expect(saves.save_now(), "Cannot save search fixture through SaveGameService")
	var before: String = JSON.stringify(map.tracker.atlas.data)
	var file_before := FileAccess.get_file_as_string(saves.save_path)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/support/atlas_search_restart.gd"], output, true)
	_expect(code == 0 and str(output).contains("ATLAS_SEARCH_RESTART_OK") and not str(output).contains("ERROR:"), "Fresh search process failed: " + str(output).right(1000))
	await _search("  NADELÖHR ")
	_expect(map._places.size() == 64 and not map._place_next.disabled and map._place_previous.disabled, "Filtered first page did not find archived matches")
	_expect(map._list.get_child_count() == 64 and map._canvas.places.size() == 64, "Search created an unbounded list or marker set")
	map._place_next.pressed.emit()
	await _wait_search()
	_expect(map._place_offset == 64 and map._places.size() == 1 and map._places[0].id == "search-place-384" and map._place_next.disabled, "Filtered second page duplicated/skipped a match")
	map._list.get_child(0).pressed.emit()
	_expect(map._selected == "search-place-384" and "{name}" in map._detail.text, "Result action failed or interpolated a literal user name")
	_expect(map.projection.center.distance_to(map.projection.project(map._places[0].address)) < 0.001, "Result did not center the correct address")
	map._place_previous.pressed.emit()
	await _wait_search()
	_expect(map._places.size() == 64 and map._places[0].id == "search-place-256", "Previous results page changed ordering")
	await _search("no-such-place")
	_expect(map._places.is_empty() and not map._search_status.text.begins_with("ATLAS_") and not map._place_pager.visible, "Empty search left stale results or controls")
	# A fast replacement must not publish the first request's late results.
	_set_search("Waldrand")
	map._search_delay = 0
	await process_frame
	_set_search("Nadelöhr")
	await _wait_search()
	_expect(map._places.size() == 64 and map._places.all(func(p: Dictionary) -> bool: return p.name.begins_with("Nadelöhr")), "Cancelled request published stale matches")
	await _search("")
	var own: Button = map._panel.find_child("AtlasOwnFilter", true, false)
	var friends: Button = map._panel.find_child("AtlasFriendFilter", true, false)
	own.button_pressed = false
	await _wait_search()
	_expect(map._places.size() == 1 and not map._places[0].own and not map._place_pager.visible, "Global ownership filter retained empty raw pages")
	var progression := root.get_node("ProgressionService")
	var ally: Dictionary = _friend("1:0")
	var dead: Dictionary = ally.duplicate(true)
	dead.dead = true
	dead.health_ratio = 0.0
	progression._encounters.put(dead)
	map._refresh_places()
	await _wait_search()
	_expect(map._places.is_empty(), "Search exposed a dead ally's habitat")
	progression._encounters.put(ally)
	friends.button_pressed = false
	_expect(not map._place_query.active and map._places.is_empty(), "Disabled filters scanned the archive")
	own.button_pressed = true
	friends.button_pressed = true
	await _search("Own nest")
	var locale: Node = root.get_node("LocaleManager")
	locale._apply("en")
	await _frames(3)
	await _wait_search()
	_expect(map._places.size() == 1 and Presentation.place_name(map._places[0]) == "Own nest", "Translated built-in name was not searchable")
	locale._apply("de")
	await _frames(3)
	await _wait_search()
	_expect(map._places.is_empty() and map._place_search.text == "Own nest", "Language change did not refresh search membership/preserve the term")
	await _search("Nadelöhr")
	await _search_layouts()
	# Text editing must not trigger map shortcuts or consume arrow/copy keys.
	map._places_toggle.grab_focus()
	var find_key := InputEventKey.new()
	find_key.keycode = KEY_F
	find_key.ctrl_pressed = true
	find_key.pressed = true
	root.push_input(find_key, true)
	await process_frame
	_expect(map._show_list and map._place_search.has_focus(), "Ctrl+F did not reveal and focus the search field")
	map._place_search.select_all()
	var typed := InputEventKey.new()
	typed.keycode = KEY_M
	typed.physical_keycode = KEY_M
	typed.unicode = 109
	typed.pressed = true
	root.push_input(typed, true)
	await process_frame
	_expect(map.is_open and map._place_search.text == "m", "Typing M closed the atlas or lost text input")
	var center: Vector2 = map.projection.center
	await _key(KEY_LEFT)
	_expect(map.projection.center == center and map._place_search.caret_column == 0, "Text cursor key panned the map")
	await _key(KEY_ESCAPE)
	_expect(map.is_open and not map._place_search.has_focus(), "First Escape did not leave search focus")
	await _key(KEY_ESCAPE)
	await _frames(2)
	_expect(not map.is_open and not paused and not map._place_query.active and not map._search_pending, "Closing search leaked work or pause")
	_expect(JSON.stringify(map.tracker.atlas.data) == before and FileAccess.get_file_as_string(saves.save_path) == file_before, "Searching rewrote exploration or the campaign file")
	_expect(map.open_map(), "Map did not reopen after cancelled search")
	_set_search("pending-on-load")
	_expect(saves.load_now(), "Cannot load campaign with pending search")
	await _frames(3)
	_expect(not map.is_open and not map._place_query.active and not map._search_pending and not paused, "Loading retained stale map search")
	# Restore the inherited fixture for its independent save/restart/death route.
	state.get_current_body_record().exploration_atlas = original
	map.tracker.invalidate()
	map.tracker.update_exploration(true)
	_expect(map.open_map(), "Restored map fixture cannot open")
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.size = Vector2i(1280, 720)
	map._layout()
	print("ATLAS_SEARCH_CHECKS: ", checks)

func _set_search(term: String) -> void:
	map._place_search.text = term
	map._place_search.text_changed.emit(term)

func _search(term: String) -> void:
	_set_search(term)
	await _wait_search()

func _wait_search() -> void:
	for frame in range(2000):
		if not map._search_pending and not map._place_query.active: break
		await process_frame
	_expect(not map._search_pending and not map._place_query.active, "Map search timed out")
	await _frames(3)

func _search_layouts() -> void:
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.5]:
			for language: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(language)
				await _frames(2)
				await _wait_search()
				root.size = size
				root.get_node("DisplaySettings").ui_scale = scale
				map._show_list = true
				map._layout()
				await _frames(5)
				var screen := Rect2(Vector2.ZERO, Vector2(size))
				if not screen.encloses(_physical(map._panel)):
					for node: Control in [map._column, map._body, map._sidebar, map._search_status, map._scroll, map._list, map._legend]:
						print("SEARCH_LAYOUT_DIAG ", node.get_class(), " ", node.name, " size=", node.size, " min=", node.get_combined_minimum_size(), " visible=", node.visible)
				_expect(screen.encloses(_physical(map._panel)), "Search panel escaped screen: %s/%s/%s rect=%s logical=%s transform=%s" % [size, scale, language, _physical(map._panel), root.get_visible_rect(), map.transform])
				for control: Control in [map._place_search, map._search_status, map._place_previous, map._place_next]:
					_expect(screen.encloses(_physical(control)), "Search control escaped screen: " + control.name)
				_expect(map._scroll.size.y >= 44 * scale, "Search left no complete result row")
				if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("user://search-%s-%dx%d-%d.png" % [language, size.x, size.y, roundi(scale * 100)])
	root.get_node("LocaleManager")._apply("de")
	await _frames(3)
	await _wait_search()
