extends SceneTree

const Records = preload("res://core/discovery/discovery_records.gd")
const Journal = preload("res://ui/discovery/discovery_journal.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const SAVE := "user://journal_acceptance.json"

var _failures: Array[String] = []
var _progression: Node
var _journal: CanvasLayer
var _fixture: Node3D
var _species_key: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var saves := root.get_node("SaveGameService")
	saves.set("autosave_enabled", false)
	_progression = root.get_node("ProgressionService")
	if "--journal-child" in OS.get_cmdline_user_args():
		_check(bool(saves.call("load_now", SAVE)), "Fresh process restores the campaign save")
		var entries: Dictionary = _progression.get("discovered_species")
		_check(entries.size() == 2, "Fresh process restores both worlds' species")
		for entry in entries.values():
			var visual: Dictionary = Records.visual_for(entry)
			_check(not visual.is_empty() and visual["body"]["shape"] is Vector3, "Saved preview retains typed anatomy")
		_finish()
		return
	await process_frame
	await process_frame
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_progression.call("reset_for_new_game")
	await _test_empty_and_input()
	_test_records()
	_test_save(saves)
	await _test_collection()
	await _test_skilltree_connection()
	await _test_pause_cleanup()
	_fixture.queue_free()
	current_scene = null
	await process_frame
	_finish()


func _test_empty_and_input() -> void:
	_fixture = Node3D.new()
	root.add_child(_fixture)
	current_scene = _fixture
	_journal = Journal.new()
	_fixture.add_child(_journal)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var original_mouse_mode: int = Input.mouse_mode
	_key(KEY_J)
	await process_frame
	_check(_journal.is_open and paused, "Physical J opens and pauses")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Journal releases cursor")
	_check(_journal._title.text == "Noch keine Arten entdeckt", "Empty collection guides first observation")
	_check(_journal._list.item_count == 0, "Undiscovered wildlife is never revealed")
	_key(KEY_F8)
	_check(root.get_node("DisplaySettings").get("_menu_layer").visible == false, "Settings shortcut cannot stack a modal")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not _journal.is_open and not paused, "Escape restores gameplay")
	_check(Input.mouse_mode == original_mouse_mode, "Original cursor mode restored")
	paused = true
	_key(KEY_J)
	_check(not _journal.is_open and paused, "Journal respects another pause owner")
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	await process_frame
	var button: Button = _journal._hud.find_child("OpenJournal", true, false)
	await _click(button)
	_check(_journal.is_open, "Visible HUD button opens journal with a real click")
	await _click(_journal._close)
	_check(not _journal.is_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Close button retains visible cursor")


func _test_records() -> void:
	var game: Node = root.get_node("GameState")
	game.set_world_seed(123456, false)
	game.campaign.ensure_body(654321, game.system_seed, game.active_system_id)
	var blueprint: Dictionary = Species.create_species(771337, Vector2i(1, -2), "predator")
	var original: String = JSON.stringify(Records.encode(blueprint))
	var receipt: Dictionary = _progression.call("register_species_discovery", 771337, blueprint, 123456)
	_species_key = receipt["species_key"]
	_check(receipt["is_new"], "Real service discovery succeeds")
	var entries: Dictionary = _progression.get("discovered_species")
	var snapshot: Dictionary = Records.visual_for(entries[_species_key])
	_check(snapshot["body"]["shape"] == blueprint["body"]["shape"], "Exact observed anatomy retained")
	_check(snapshot["parts"] == blueprint["parts"], "Attachments, transforms and colors retained")
	_check(JSON.stringify(Records.encode(blueprint)) == original, "Observation does not mutate live creature")
	var points: int = _progression.get("discovery_points")
	var part: String = receipt["unlocked_part"]
	_check(not part.is_empty(), "Fixture discovery actually unlocks a non-starter part")
	_check(Records.source_for(part, _progression.call("export_state")).contains(str(blueprint["name"])), "Unlock links to the exact discovery")
	var again: Dictionary = _progression.call("register_species_discovery", 771337, blueprint, 123456)
	_check(not again["is_new"] and _progression.get("discovery_points") == points, "Re-observation gives no second reward")
	blueprint["body"]["shape"] = Vector3(9, 9, 9)
	_check(Records.visual_for(entries[_species_key])["body"]["shape"] == snapshot["body"]["shape"], "Later body edits cannot change observation")
	blueprint["body"]["shape"] = snapshot["body"]["shape"]
	_progression.call("register_species_discovery", 771337, blueprint, 654321)
	_check(_progression.call("get_discovered_species_count") == 2, "Same species seed on two worlds remains distinct")
	var state: Dictionary = _progression.call("export_state")
	_check(Records.species_rows(state, "654321").size() == 1, "Search respects source world")
	_check(Records.species_rows(state, "", "grazer").is_empty(), "Role filter excludes other roles")
	_check(Records.species_rows(state, "", "predator").size() == 2, "Role filter keeps observed predators")
	_check(Records.next_step({}, 1, 0.1, 1).begins_with("Wasser suchen"), "Guidance prioritizes thirst")
	_check(Records.next_step({}, 1, 1, 0.1).begins_with("Nahrung suchen"), "Guidance prioritizes hunger")
	_check(Records.next_step({}, 0, 0.1, 0.1).begins_with("Zurück zum Nest"), "Death takes priority over survival hints")
	_progression.call("register_region_discovery", Vector2i(-2, 7), 123456)
	_progression.call("register_region_discovery", Vector2i(-2, 7), 654321)
	var regions: Array[Dictionary] = Records.region_rows(_progression.call("export_state"), "654321")
	_check(regions.size() == 1 and regions[0]["name"] == "Region -2 / 7", "Regions preserve exact coordinates and distinct source worlds")
	# Additive migration keeps old records and only backfills an actual re-observation.
	entries[_species_key].erase("journal")
	_check(Records.visual_for(entries[_species_key]).is_empty(), "Legacy records do not invent a preview")
	points = _progression.get("discovery_points")
	_progression.call("register_species_discovery", 771337, blueprint, 123456)
	_check(not Records.visual_for(entries[_species_key]).is_empty(), "Re-observation fills a legacy preview")
	_check(_progression.get("discovery_points") == points, "Legacy backfill never rewards again")
	var legacy: Dictionary = state.duplicate(true)
	legacy["unlocked_parts"][part].erase("species_key")
	_check(Records.source_for(part, legacy).contains("nicht vermerkt"), "Unknown old unlock source stays unknown")
	legacy["unlocked_parts"]["removed_part"] = {"reason": "Starter part"}
	_check(Records.part_rows(legacy, "removed_part").size() == 1, "Unavailable saved part remains visible")
	_check(Records.decode({"_journal_type": "v3", "v": ["bad", 0, 0]}) == null, "Malformed typed metadata rejected")


func _test_save(saves: Node) -> void:
	_check(bool(saves.call("save_now", SAVE)), "Whole campaign saves with observation metadata")
	var points: int = _progression.get("discovery_points")
	_progression.call("reset_for_new_game")
	_check(bool(saves.call("load_now", SAVE)), "Whole campaign reloads")
	_check(_progression.get("discovery_points") == points, "Reload retains points without rewards")
	var output: Array = []
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/discovery_journal_test.gd", "--", "--journal-child"])
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_check(exit_code == 0 and not str(output).contains("SCRIPT ERROR"), "Independent process reads saved observations: %s" % str(output))


func _test_collection() -> void:
	var before: String = JSON.stringify(_progression.call("export_state"))
	_journal.open_journal()
	await process_frame
	_check(_journal._list.item_count == 2, "Journal shows both saved entries")
	_check(_journal._preview.visible and is_instance_valid(_journal._preview.get("_model")), "Selected saved species builds a real preview")
	await _capture("species")
	var preview: Control = _journal._preview
	var angle_before: float = preview.get("_angle")
	var motion := InputEventMouseMotion.new()
	motion.position = preview.get_global_rect().get_center()
	motion.global_position = motion.position
	motion.relative = Vector2(40, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	_check(not is_equal_approx(float(preview.get("_angle")), angle_before), "Dragging the real preview rotates its camera")
	var wheel := InputEventMouseButton.new()
	wheel.position = preview.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	await process_frame
	_check(float(preview.get("_zoom")) < 1.0, "Preview mouse wheel changes zoom")
	_journal._search.text = "no matching creature"
	_journal._search.text_changed.emit(_journal._search.text)
	_check(_journal._list.item_count == 0, "Search updates the actual list")
	_journal._search.grab_focus()
	_key(KEY_J)
	_check(_journal.is_open, "Typing J in search does not close the book")
	# Click the actual tab rectangle, not a direct tab callback.
	await _click_at(_journal._tabs.global_position + _journal._tabs.get_tab_rect(1).get_center())
	_check(_journal._tabs.current_tab == 1, "Mouse selects body-part tab while paused")
	_check(_journal._list.item_count > 0, "Body-part catalog is populated")
	_journal._status.select(2)
	_journal._status.item_selected.emit(2)
	for row in _journal._rows:
		_check(not row["unlocked"], "Locked-only filter contains no unlocked parts")
	await _capture("parts")
	await _click_at(_journal._tabs.global_position + _journal._tabs.get_tab_rect(2).get_center())
	_check(_journal._rows.size() == 2 and not _journal._preview.visible, "Regions view retains saved worlds without a creature preview")
	_check(_journal._title.text == "Region -2 / 7" and _journal._description.text.contains("Welt 123456\n"), "Reloaded coordinates and world IDs keep integer formatting")
	await _capture("regions")
	await _click_at(_journal._tabs.global_position + _journal._tabs.get_tab_rect(3).get_center())
	_check(_journal._guide.visible and _journal._guide.text.contains("Linksklick"), "Guide uses real observation control")
	await _capture("guide")
	_check(JSON.stringify(_progression.call("export_state")) == before, "Browsing, preview and filters never mutate progression")
	await _click(_journal._close)
	_check(not paused, "GUI returns to gameplay")
	# Verify text remains within the viewport at the smallest supported display + high UI scale.
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	_journal.open_journal()
	await process_frame
	await process_frame
	_check(root.get_visible_rect().encloses(_journal._close.get_global_rect()), "Close control visible at compact resolution")
	await _capture("compact")
	_journal.close_journal()
	await process_frame


func _test_pause_cleanup() -> void:
	_journal.open_journal()
	_check(paused, "Cleanup fixture owns pause")
	_journal.queue_free()
	await process_frame
	_check(not paused, "Removing journal while open releases only its own pause")
	# Production scene integration is explicit and checked without loading terrain.
	var scene: PackedScene = load("res://main/main.tscn")
	var main: Node = scene.instantiate()
	_check(main.get_node_or_null("DiscoveryJournal") == null and main.get_node_or_null("Player/ProgressionHUD") != null, "Main delegates journal installation to player HUD without a duplicate root book")
	main.free()


func _test_skilltree_connection() -> void:
	# Use the production player installer, including its actual K and J input handlers.
	_journal.queue_free()
	await process_frame
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	_fixture.add_child(player)
	await process_frame
	await process_frame
	var hud := player.get_node("ProgressionHUD")
	_journal = hud.get("_discovery_journal")
	var skilltree: CanvasLayer = hud.get("_skill_tree")
	_check(get_nodes_in_group(&"discovery_journal").size() == 1 and skilltree.journal == _journal, "Production player installs one shared book")
	var before: Dictionary = _progression.call("export_state")
	player.set_physics_process(false)
	_key(KEY_J)
	_check(not _journal.is_open and not paused, "Journal cannot interrupt player loading or a boot menu")
	player.set_physics_process(true)
	_key(KEY_K)
	await process_frame
	_check(skilltree.visible and paused, "K opens the production skilltree")
	await _click(skilltree._journal_tab)
	await process_frame
	_check(_journal.is_open and not skilltree.visible and paused, "Skilltree entry transfers to the shared book with one pause owner")
	_key(KEY_F8)
	_check(not root.get_node("DisplaySettings").get("_menu_layer").visible, "Settings cannot interrupt journal")
	await _click(_journal._close)
	await process_frame
	_check(not paused and not skilltree.visible, "Closing integrated book returns to game")
	_key(KEY_J)
	await process_frame
	_check(_journal.is_open and get_nodes_in_group(&"discovery_journal")[0] == _journal, "J opens exactly the same installed instance")
	_check(_progression.call("export_state") == before, "Both menu entrances leave points, discoveries and unlocks unchanged")
	await _click(_journal._close)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)


func _click(button: Control) -> void:
	await process_frame
	await process_frame
	await _click_at(button.get_global_rect().get_center())


func _click_at(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _capture(label: String) -> void:
	if not "--journal-capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	if label == "species":
		print("JOURNAL_PREVIEW ", JSON.stringify({"bounds": str(_journal._preview.get("_bounds")),
			"size": str(_journal._preview.size), "viewport": str(_journal._preview.get("viewport").size),
			"camera": str(_journal._preview.get("_camera").position)}))
	var directory := "res://art/review/discovery_journal"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Capture " + label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("DISCOVERY_JOURNAL_TEST ", JSON.stringify({"passed": _failures.is_empty(), "failures": _failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if _failures.is_empty() else 1)
