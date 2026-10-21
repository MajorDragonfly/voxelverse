extends RefCounted
## Runs after the existing campaign test has REALLY tamed its D1 individual.
## The original follow/home/copy/cold-process/death route remains in that test.
const Navigation = preload("res://core/map/navigation_state.gd")
const Owned = preload("res://ui/minimap/owned_animal_markers.gd")
const View = preload("res://ui/world_map/navigation_presentation.gd")
const Text = preload("res://core/localization/ui_text.gd")

static func run(test: SceneTree) -> void:
	var hud: CanvasLayer = test.get_first_node_in_group(&"minimap_hud")
	test._expect(hud != null, "Tamed campaign has no shared minimap")
	if hud == null: return
	var map: CanvasLayer = hud.atlas_window
	var body: Dictionary = test.tribe.body()
	map.tracker.update_exploration()
	test._key(KEY_M)
	await test._frames(4)
	test._expect(map.is_open and test.paused, "Real map input did not pause the owned-animal campaign")
	if not map.is_open: return
	test._expect(test.tribe.has_loaded_village() and not test.tribe.is_active(), "Paused map enabled simulation or lost the loaded village")
	var fog: Dictionary = map.tracker.atlas.data.duplicate(true)
	# Rollback must restore even a v1 record that a successful edit would upgrade.
	map.add_waypoint(View.origin(map.tracker.snapshot))
	body.map_navigation.schema = 1
	test._expect(test.saves.save_now(), "Cannot save supported v1 navigation fixture")
	await test._click(map._animal_toggle)
	test._expect(map._animal_scroll.is_visible_in_tree() and not map._navigation_scroll.is_visible_in_tree(), "Animal drawer did not replace waypoint management")
	test._expect(map._animals._list.get_child_count() == 1, "Actual tamed individual is missing from map list")
	if map._animals._list.get_child_count() != 1: map.close_map(); return
	var row: Button = map._animals._list.get_child(0)
	await test._show_in_scroll(map._animal_scroll, row)
	await test._click(row)
	test._expect(map._animals.selected_id == test.animal_id and map._selected == test.animal_id, "Real animal row did not select the D2 ID")
	test._expect(map._canvas.places.any(func(point: Dictionary) -> bool: return point.id == test.animal_id and point.kind == "owned_animal"), "Owned individual is absent from world-map markers")
	var before: Dictionary = Navigation.view(body).duplicate(true)
	var path: String = test.saves.save_path
	var blocker := FileAccess.open("user://nav-animal-blocker", FileAccess.WRITE)
	blocker.store_string("sentinel")
	blocker.close()
	test.saves.save_path = "user://nav-animal-blocker/save.json"
	await test._show_in_scroll(map._animal_scroll, map._animals._track)
	await test._click(map._animals._track)
	test._expect(Navigation.view(body) == before and body.map_navigation.schema == 1, "Rejected animal selection changed the target or upgraded v1")
	test._expect(map._animals._message.text == Text.text("NAV_SAVE_FAILED") and not map._animals._track.disabled, "Animal save failure cannot be understood or retried")
	test.saves.save_path = path
	await test._click(map._animals._track)
	test._expect(body.map_navigation.schema == Navigation.SCHEMA and body.map_navigation.waypoints == before.waypoints and body.map_navigation.target == {"kind": "owned_animal", "id": test.animal_id}, "Animal tracking lost v1 pins or failed to store only the stable ID")
	var expected: Dictionary = Navigation.view(body).duplicate(true)
	var settings: Node = test.root.get_node("DisplaySettings")
	var locale: Node = test.root.get_node("LocaleManager")
	var original_size: Vector2i = test.root.size
	var original_scale: float = settings.ui_scale
	var original_locale: String = locale.locale
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.25, 1.5]:
			for language: String in ["de", "en"]:
				test.root.size = dimensions
				settings.ui_scale = scale
				locale._apply(language)
				map._layout()
				map._refresh_description()
				await test._frames(5)
				var context: String = "%s/%s/%s" % [dimensions, scale, language]
				test._expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(test._physical_rect(map._panel)), "Animal navigation escaped screen: " + context)
				test._expect(not map._animals._title.text.begins_with("NAV_") and map._animals._detail.text.contains(Text.text("NAV_ANIMAL_LIVE")), "Animal status retained keys or stale language: " + context)
				await test._show_in_scroll(map._animal_scroll, row)
				await test._click(row)
				test._expect(map._animals._list.get_child(0) == row and Navigation.view(body) == expected, "Read-only refresh rebuilt focused animal row or changed navigation")
				await test._show_in_scroll(map._animal_scroll, map._animals._stop)
				test._expect(test._physical_rect(map._animal_scroll).grow(1).encloses(test._physical_rect(map._animals._stop)), "Animal stop action is clipped: " + context)
				if not test.capture_dir.is_empty(): await test._capture("animal-navigation-%s-%dx%d-%d" % [language, dimensions.x, dimensions.y, roundi(scale * 100)])
	test.root.size = original_size
	settings.ui_scale = original_scale
	locale._apply(original_locale)
	map._layout()
	await test._frames(5)
	await test._show_in_scroll(map._animal_scroll, map._animals._stop)
	await test._click(map._animals._stop)
	test._expect(Navigation.view(body).target.is_empty() and not map._animals._track.disabled, "Real animal stop action did not clear tracking")
	await test._click(map._animals._track)
	test._expect(map.tracker.atlas.data == fog, "Animal selection or map panning revealed unexplored terrain")
	test._key(KEY_ESCAPE)
	await test._frames(3)
	test._expect(map.is_open and not map._show_animals and test.paused, "First Escape did not return from animals to map")
	test._key(KEY_ESCAPE)
	await test._frames(3)
	test._expect(not map.is_open and not test.paused, "Second Escape did not resume the owned-animal campaign")
	hud._update_snapshot()
	test._expect(hud._navigation_label.visible and not hud._map.navigation.is_empty(), "Tracked animal has no minimap guidance")
	var speed: float = test.state.campaign.data.time_scale
	test.state.set_simulation_speed(0)
	hud._update_snapshot()
	test._expect(Navigation.target(body, map.tracker.atlas, Owned.collect(body, test.state.campaign.data.player_faction_id, test)).get("live", false), "0x simulation replaced loaded guidance with a saved position")
	test.state.set_simulation_speed(speed)
	var record: Dictionary = test.d2.controller.registry.animals[test.animal_id]
	var faction: String = record.owner_faction_id
	record.owner_faction_id = "foreign-owner"
	hud._update_snapshot()
	test._expect(hud._map.navigation.is_empty() and hud._navigation_label.text == Text.text("NAV_ANIMAL_UNAVAILABLE"), "Ownership loss retained a stale direction or hid the problem")
	record.owner_faction_id = faction
	test.d2._ready_runtime = false
	hud._update_snapshot()
	test._expect(not hud._map.navigation.is_empty() and not hud._map.navigation.arrived and hud._navigation_label.text.begins_with(Text.text("NAV_ANIMAL_LAST_GUIDANCE").get_slice("{name}", 0)), "Unloaded animal was claimed as live or arrived")
	test.d2._ready_runtime = true
	hud._update_snapshot()
	test._expect(Navigation.view(body) == expected and not Owned.collect(body, faction, test).is_empty(), "Visibility changes mutated navigation or animal ownership")
	if test.failures.is_empty(): print("ANIMAL_NAVIGATION_UI_PASSED")

static func check_motion(test: SceneTree) -> void:
	var hud: CanvasLayer = test.get_first_node_in_group(&"minimap_hud")
	hud._update_snapshot()
	var body: Dictionary = test.tribe.body()
	var targets: Array[Dictionary] = Owned.collect(body, test.state.campaign.data.player_faction_id, test)
	var target: Dictionary = Navigation.target(body, hud.atlas_window.tracker.atlas, targets)
	test._expect(not target.is_empty() and target.id == test.animal_id and target.live, "Following animal disappeared from active guidance")
	if target.is_empty(): return
	var point: Vector3 = preload("res://world/domestication/animal_state.gd").vector(target.address.position)
	test._expect(point.distance_to(test.d2.animals[test.animal_id].global_position) < 0.001, "Guidance lagged behind actual physical following")
	test._expect(not hud._map.navigation.is_empty() and hud._map.navigation.position.is_equal_approx(hud.projection.project(target.address)), "Minimap direction did not move with the actual animal")

static func check_restart(test: SceneTree) -> void:
	var body: Dictionary = test.tribe.body()
	test._expect(Navigation.view(body).get("target", {}) == {"kind": "owned_animal", "id": test.animal_id}, "Fresh process lost the moving target identity")
	check_motion(test)

static func check_death(test: SceneTree) -> void:
	var hud: CanvasLayer = test.get_first_node_in_group(&"minimap_hud")
	hud._update_snapshot()
	test._expect(hud._map.navigation.is_empty() and hud._navigation_label.visible and hud._navigation_label.text == Text.text("NAV_ANIMAL_UNAVAILABLE"), "Persisted actual animal death kept a direction to stale coordinates")
