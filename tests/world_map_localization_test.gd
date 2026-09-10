extends "world_map_test.gd"
## Extends the real player/atlas/save/restart route, with in-place language checks.
const Presentation = preload("res://ui/world_map/atlas_presentation.gd")
var localization_checks: int = 0

func _expect(condition: bool, message: String) -> void:
	localization_checks += 1
	super._expect(condition, message)

func _layouts() -> void:
	var locale: Node = root.get_node("LocaleManager")
	var tracker: Node = map.tracker
	# A rejected record produces a stable presentation code and is never repaired
	# by display logic. Restoring a supported record clears the old error.
	var record: Dictionary = state.get_current_body_record().exploration_atlas
	record.schema = 99
	tracker.invalidate()
	tracker.update_exploration(true)
	_expect(tracker.problem_code == "atlas.invalid_record" and tracker.snapshot.is_empty() and record.schema == 99, "Unsupported map was rewritten or lacks a stable result")
	record.schema = 1
	tracker.update_exploration(true)
	_expect(tracker.problem_code.is_empty() and tracker.problem.is_empty() and not tracker.snapshot.is_empty(), "Recovered atlas retained an old error")
	var original_places: Dictionary = tracker.atlas.data.places.duplicate(true)
	var body: Dictionary = state.get_current_body_record()
	var selected_id := "atlas-locale-custom-12"
	for i in range(32):
		var title := "Weltkarte {name}" if i == 12 else "Eigenes Tal mit einem langen Ortsnamen %02d" % i
		var place: Dictionary = Source._place("atlas-locale-custom-" + str(i), title, "nest", state.campaign.data.player_species_id, "", true, Surface.plane_address(body.id, Vector3(i * 2, 100, 0)))
		_expect(tracker.atlas.remember(place), "Could not register a valid named place")
	map._refresh_places()
	map.select_place(selected_id)
	map.range_m = 635.0
	map._request()
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	map._layout()
	await _frames(5)
	var friends: Button = map._panel.find_child("AtlasFriendFilter", true, false)
	friends.button_pressed = false
	await _frames(3)
	# Stop unrelated queued raster work while checking that translation does not
	# schedule another terrain request or rebuild the list's actual Controls.
	map.set_process(false)
	var pending: bool = map._request_pending
	var samples: int = map.terrain.samples_total
	map._scroll.scroll_vertical = 210
	await _frames(3)
	var focus: Control = map._list.get_child(10)
	focus.grab_focus()
	await _frames(3)
	var scroll_before: int = map._scroll.scroll_vertical
	var center: Vector2 = map.projection.center
	var place_buttons: Array = map._list.get_children()
	var chart: RefCounted = map.projection
	var raster: RefCounted = map.terrain
	_expect(saves.save_now(), "Could not save the real map before language changes")
	var saved_bytes := FileAccess.get_file_as_string(saves.save_path)
	var state_before: Dictionary = state.campaign.export_state()
	var progress_before: Dictionary = root.get_node("ProgressionService").export_state()
	for language: String in ["en", "de", "en", "de"]:
		_expect(locale.save_preference(language) == OK, "Could not apply language preference")
		await _frames(6)
		_expect(map.is_open and paused and map._owns_pause, "Language change released the open map's pause")
		_expect(map._selected == selected_id and map.range_m == 635.0 and map.projection.center == center, "Language change reset selection, zoom or center")
		_expect(not map._show_friends and not friends.button_pressed and map._show_own, "Language change reset place filters")
		_expect(focus.has_focus() and map._scroll.scroll_vertical == scroll_before, "Language change lost list focus/scroll")
		_expect(map._list.get_children() == place_buttons and is_same(chart, map.projection) and is_same(raster, map.terrain), "Language change rebuilt Controls or the map")
		_expect(map.terrain.samples_total == samples and map._request_pending == pending, "Language change scheduled terrain sampling")
		_expect(state.campaign.export_state() == state_before and root.get_node("ProgressionService").export_state() == progress_before, "Language change changed exploration or awarded progress")
		_expect(FileAccess.get_file_as_string(saves.save_path) == saved_bytes, "Language change rewrote the campaign file")
		_expect("Weltkarte {name}" in map._detail.text, "Name matching a translation key was translated or interpolated")
		_expect(("1.3 km" if language == "en" else "1,3 km") in map._scale_label.text, "Map distance uses the wrong decimal separator")
		_expect(("Your species" if language == "en" else "Eigene Spezies") in map._detail.text, "Selected place detail did not refresh")
		_test_place_names(language)
		tracker.atlas.full = true
		map._refresh_description()
		_expect(("collection is full" if language == "en" else "Kartensammlung ist voll") in map._detail.text, "Full-map message is not translated")
		tracker.atlas.full = false
		map._refresh_description()
		for code: String in Presentation.PROBLEM_KEYS:
			_expect(not Presentation.problem_text(code).begins_with("ATLAS_"), "Untranslated map failure code")
	# No language action is allowed to reveal a hidden friend's habitat.
	_expect(map._places.all(func(p: Dictionary) -> bool: return p.id != _friend("500:500").object_id + ":habitat"), "Language change exposed an unknown habitat")
	map.set_process(true)
	# Restore the authoritative fixture data before the inherited save/restart
	# and friendship tests continue; screenshots exercise the same real map.
	tracker.atlas.data.places = original_places
	map._show_friends = true
	friends.set_pressed_no_signal(true)
	map._selected = ""
	map._refresh_places()
	map.focus_player()
	map.range_m = 64.0
	map._request()
	for i in range(240):
		await process_frame
		if map.terrain.completed and not map._request_pending: break
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		for scale: float in [1.0, 1.5]:
			for language: String in ["de", "en"]:
				locale._apply(language)
				root.size = size
				root.get_node("DisplaySettings").ui_scale = scale
				map._show_list = false
				map._layout()
				await _frames(8)
				map._layout()
				await _frames(3)
				_expect(Rect2(Vector2.ZERO, Vector2(size)).encloses(_physical(map._panel)), "Translated atlas escaped screen: " + str(size) + "/" + str(scale) + "/" + language)
				_expect(_physical(map._canvas).size.y >= 150 and _physical(map._canvas).size.x >= 180, "Translated map became unreadable")
				for id: String in ["CloseWorldMap", "AtlasZoomIn", "AtlasZoomOut", "AtlasPlayer", "AtlasExplored"]:
					var control: Control = map._panel.find_child(id, true, false)
					_expect(_physical(map._panel).encloses(_physical(control)), "Translated map action escaped panel: " + id)
				await _capture("atlas-%s-%dx%d-%d" % [language, size.x, size.y, roundi(scale * 100)])
				if size == Vector2i(800, 600) and scale == 1.5:
					map._show_list = true
					map._layout()
					await _frames(5)
					_expect(map._sidebar.visible and not map._canvas.visible, "Small atlas lost place-list switch")
					for button: Control in map._list.get_children():
						map._scroll.ensure_control_visible(button)
						await _frames(3)
						_expect(_physical(map._scroll).grow(1).encloses(_physical(button)), "Known-place action cannot be reached: %s button=%s scroll=%s" % [language, _physical(button), _physical(map._scroll)])
					await _capture("atlas-%s-800x600-150-places" % language)
					map._show_own = false
					map._show_friends = false
					map._refresh_places()
					map._layout()
					await _frames(4)
					await _capture("atlas-%s-800x600-150-empty" % language)
					map._show_own = true
					map._show_friends = true
					map._refresh_places()
	locale._apply("de")
	map._show_list = false
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.size = Vector2i(1280, 720)
	map._layout()
	await _frames(3)
	print("ATLAS_LOCALIZATION_CHECKS: ", localization_checks)

func _test_place_names(language: String) -> void:
	var body: String = state.get_current_body_record().id
	var species: String = state.campaign.data.player_species_id
	var radial: Dictionary = Cube.address(body, 0, 0, 0)
	var own: Dictionary = Source._place(body + ":nest", "Eigenes Nest", "nest", species, "", true, radial)
	_expect(Presentation.place_name(own) == ("Own nest" if language == "en" else "Eigenes Nest"), "Built-in radial nest is untranslated")
	own.id = "external-provider"
	_expect(Presentation.place_name(own) == "Eigenes Nest", "Provider name was mistaken for a built-in label")
	var home: Dictionary = Source._place(Presentation.Ids.scoped("group", body, species + ":home"), "Heimat deiner Spezies", "home", species, "", true, radial)
	_expect(Presentation.place_name(home) == ("Home of your species" if language == "en" else "Heimat deiner Spezies"), "Built-in home is untranslated")
	var friend: Dictionary = Source._place("friend:habitat", "Weltkarte {name} · Lebensraum", "friend_habitat", "friend-species", "friend", false, radial)
	_expect(Presentation.place_name(friend) == ("Weltkarte {name} · Habitat" if language == "en" else "Weltkarte {name} · Lebensraum"), "Named habitat changed its creature name")
	var before: Dictionary = friend.duplicate(true)
	Presentation.detail_text(friend)
	_expect(friend == before, "Map presentation mutated a saved place")
	_expect(Presentation.scale_text(1250, true).begins_with("Equatorial width" if language == "en" else "Breite am Äquator"), "Spherical map lost its equatorial scale label")

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://" + name + ".png")
