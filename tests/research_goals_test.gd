extends SceneTree

const Research = preload("res://core/discovery/research_goals.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const SAVE_A := "user://research_campaign_a.json"
const SAVE_B := "user://research_campaign_b.json"

var failures: Array[String] = []
var progression: Node
var saves: Node
var journal: CanvasLayer
var fixture: Node3D
var wished_part: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE_A
	progression = root.get_node("ProgressionService")
	if "--research-child" in OS.get_cmdline_user_args():
		_check(saves.load_now(SAVE_A), "Fresh process loads the whole research campaign")
		var settings: Dictionary = progression.get_research_settings()
		_check(settings["wished_parts"].size() == 1 and settings["pinned"].begins_with("part:"), "Fresh process restores wishlist and pin")
		_check(progression.get_pinned_research().get("complete", false), "Fresh process derives the achieved part goal from actual unlocks")
		_check(_goal("species.three")["complete"] and _goal("role.swimmer")["complete"], "Fresh process retains discovery goal progress")
		_finish()
		return
	await _frames()
	root.get_node("GameState").start_world_with_seed(15838)
	progression.reset_for_new_game()
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	fixture = Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	fixture.add_child(player)
	await _frames()
	journal = player.get_node("ProgressionHUD").get("_discovery_journal")
	await _test_goal_pin_and_discoveries()
	await _test_wishlist_and_failed_save()
	await _test_campaign_switch_and_legacy()
	_test_validation_and_future_save()
	_test_fresh_process()
	if journal.is_open:
		journal.close_journal()
	await _frames()
	fixture.queue_free()
	current_scene = null
	await _frames()
	_finish()


func _test_goal_pin_and_discoveries() -> void:
	_check(not journal._pinned_button.visible, "New campaigns have no inherited pinned goal")
	_check(_goal("species.three")["current"] == 0, "New campaign starts at zero real discoveries")
	var original: Dictionary = _without_research()
	journal.open_journal()
	await _frames()
	await _tab(4)
	await _select_key("species.three")
	await _click(journal._pin)
	_check(progression.get_research_settings()["pinned"] == "species.three", "Real pin button selects the research goal")
	_check(journal._action_message.text == "Auswahl gespeichert.", "Pin confirms the successful save")
	var data: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE_A))
	_check(data["progression"]["research"]["pinned"] == "species.three", "Pin success is present in the campaign file")
	_check(_without_research() == original, "Selecting a goal grants no points, discoveries or parts")
	await _click(journal._close)
	_discover(101, "grazer")
	_discover(102, "predator")
	await _frames()
	_check(journal._pinned_button.text.contains("2 / 3 Arten"), "HUD tracks two distinct discoveries without opening the book")
	var points: int = progression.discovery_points
	_discover(101, "grazer")
	_check(_goal("species.three")["current"] == 2 and progression.discovery_points == points, "Repeated observation changes neither progress nor rewards")
	await _capture("pinned")
	await _click(journal._pinned_button)
	_check(journal.is_open and journal._tabs.current_tab == 4 and journal._selected_key == "species.three", "Clicking HUD opens the exact pinned goal")
	_check(journal._goal_progress.value == 2, "Goal detail displays actual progress")
	await _capture("goals")
	await _click(journal._close)
	_discover(103, "swimmer")
	_check(_goal("role.swimmer")["current"] == 1 and _goal("species.three")["complete"], "Real swimmer discovery completes the water and species goals")
	_check(progression.discovery_points == points + 3, "Completing two goals gives only the normal discovery reward")
	_check(journal._pinned_button.text.contains("Ziel erreicht"), "Completion remains visible until the player chooses another goal")
	for cell in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]:
		progression.register_region_discovery(cell, 15838)
	progression.register_region_discovery(Vector2i(1, 2), 15838)
	_check(_goal("regions.three")["current"] == 3, "Only distinct visited regions advance the region goal")
	# Import/reset uses the same derived progress; there is no second completion ledger.
	var loaded: Dictionary = progression.export_state()
	loaded["discovered_species"]["other_world:101"] = {"name": "Other world", "role": "grazer", "world_seed": 98765}
	_check(Research.rows(loaded)[4]["current"] == 4, "Different saved worlds retain distinct species entries")


func _test_wishlist_and_failed_save() -> void:
	journal.open_journal()
	await _frames()
	await _tab(1)
	journal._status.select(2)
	journal._status.item_selected.emit(2)
	wished_part = str(journal._rows[0]["id"])
	var original: Dictionary = _without_research()
	await _click(journal._wish)
	_check(progression.get_research_settings()["wished_parts"] == [wished_part], "Real wish button adds the selected locked part")
	await _click(journal._pin)
	_check(progression.get_research_settings()["pinned"] == "part:" + wished_part, "A wished part replaces the single pinned goal")
	_check(_without_research() == original, "Wishlist and part pin cannot buy or unlock anything")
	journal._status.select(3)
	journal._status.item_selected.emit(3)
	_check(journal._list.item_count == 1 and journal._rows[0]["wished"], "Wishlist filter contains only the chosen part")
	await _capture("wishlist")
	var before: Dictionary = progression.export_state()
	saves.save_path = "user://research_missing_directory/save.json"
	await _click(journal._wish)
	_check(progression.export_state() == before, "Failed wishlist removal restores both the wish and its pin")
	_check(journal._action_message.text.contains("Speichern fehlgeschlagen") and journal._rows[0]["wished"], "Save error is visible and the existing selection remains usable")
	var failed: Dictionary = progression.set_research_pin("species.first")
	_check(not failed["ok"] and progression.export_state() == before, "Failed goal replacement also rolls back")
	saves.save_path = SAVE_A
	await _click(journal._wish)
	_check(progression.get_research_settings()["pinned"].is_empty() and journal._list.item_count == 0, "Successful removal also clears the tracked part")
	_check(journal._title.text == "Deine Teile-Merkliste", "Empty wishlist explains how to add a part")
	_check(progression.set_part_wished(wished_part, true)["ok"], "Player can restore a removed wish")
	_check(progression.set_research_pin("part:" + wished_part)["ok"], "Restored wish can be pinned")
	var settings: Dictionary = progression.get_research_settings()
	settings["wished_parts"].clear()
	_check(progression.get_research_settings()["wished_parts"].size() == 1, "Returned settings cannot mutate the service")
	await _click(journal._close)
	await _frames()
	await _click(journal._pinned_button)
	_check(journal._selected_key == wished_part and journal._tabs.current_tab == 1, "Tracked part opens its exact wishlist entry")
	var points: int = progression.discovery_points
	_check(progression.unlock_part(wished_part, "Research test external unlock"), "Existing unlock service grants the fixture part")
	await _frames()
	_check(progression.get_pinned_research()["complete"] and journal._description.text.contains("Sammelziel erreicht"), "An actual unlock updates the wish without removing it")
	_check(progression.discovery_points == points, "Research completion introduces no extra reward")
	_check(saves.save_now(), "Achieved wish saves with the whole campaign")
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	await _frames()
	journal._detail_scroll.ensure_control_visible(journal._wish)
	await _frames()
	_check(root.get_visible_rect().encloses(journal._close.get_global_rect()), "Close button fits compact research layout")
	_check(root.get_visible_rect().encloses(journal._wish.get_global_rect()), "Wishlist action remains reachable at compact resolution")
	await _capture("compact")


func _test_campaign_switch_and_legacy() -> void:
	var saved: Dictionary = progression.export_state()
	saves.save_path = SAVE_B
	root.get_node("GameState").start_world_with_seed(98765)
	_check(progression.get_research_settings() == Research.defaults(), "New campaign clears the old wishlist and pin")
	_check(not journal._pinned_button.visible, "Switching campaign removes the old HUD target")
	_check(saves.save_now(), "Second campaign saves independently")
	_check(saves.load_now(SAVE_A), "First campaign reloads")
	_check(Atomic.parse_dictionary(Atomic.stringify(progression.export_state())) == Atomic.parse_dictionary(Atomic.stringify(saved)), "First campaign restores all discoveries, wishes and pin exactly")
	_check(journal._pinned_button.text.contains("Ziel erreicht"), "Reload restores the completed HUD target without another event")
	_check(saves.load_now(SAVE_B), "Second campaign reloads")
	_check(progression.get_research_settings() == Research.defaults(), "Wishes do not leak between campaign files")
	saves.save_path = SAVE_A
	_check(saves.load_now(), "Return to first campaign")
	var legacy: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE_A))
	legacy["progression"].erase("research")
	_check(Atomic.write("user://research_legacy.json", legacy, false) == OK, "Write a pre-research save fixture")
	_check(saves.load_now("user://research_legacy.json"), "Existing campaign without research metadata remains loadable")
	_check(progression.get_research_settings() == Research.defaults() and _goal("species.three")["complete"], "Legacy discoveries count immediately without inventing player choices")
	_check(saves.load_now(SAVE_A), "Restore canonical save after legacy check")
	var unknown: Dictionary = progression.export_state()
	unknown["research"] = {"version": 1, "pinned": "part:removed_part", "wished_parts": ["removed_part"]}
	_check(progression.import_state(unknown), "Missing historical part remains a valid saved wish")
	_check(Records.part_rows(unknown, "", "", 3)[0]["category"] == "missing", "Removed part is still visible and removable in wishlist")
	_check(not progression.get_pinned_research()["available"], "Removed target is labelled unavailable, not completed")
	unknown["research"] = {"version": 1, "pinned": "goal.retired", "wished_parts": []}
	_check(progression.import_state(unknown), "Retired saved goal remains readable")
	var before: Dictionary = progression.export_state()
	if journal.is_open:
		journal.close_journal()
	await _frames()
	await _click(journal._pinned_button)
	_check(journal._selected_key == "goal.retired" and progression.export_state() == before, "Opening unavailable saved target does not silently delete it")
	_check(saves.load_now(SAVE_A), "Restore canonical save after unavailable targets")


func _test_validation_and_future_save() -> void:
	var before: Dictionary = progression.export_state()
	for value in [[], {"version": 1, "pinned": 3, "wished_parts": []}, {"version": 1, "pinned": "", "wished_parts": ["a", "a"]}, {"version": 1, "pinned": "part:a", "wished_parts": []}]:
		var invalid: Dictionary = before.duplicate(true)
		invalid["research"] = value
		_check(not progression.import_state(invalid) and progression.export_state() == before, "Malformed research state is rejected atomically")
	var too_many: Dictionary = Research.defaults()
	for index in range(Research.MAX_WISHES + 1):
		too_many["wished_parts"].append("part_%d" % index)
	_check(not Research.validate(too_many).is_empty(), "Oversized wishlist is rejected")
	_check(not progression.set_research_pin("invented_goal")["ok"], "Unknown new goal cannot be pinned")
	_check(not progression.set_part_wished("invented_part", true)["ok"], "Unknown new part cannot be wished")
	var future: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE_A))
	future["progression"]["research"]["version"] = 2
	_check(Atomic.write("user://research_future.json", future, false) == OK, "Write future research fixture")
	_check(Atomic.write("user://research_future.json.bak", Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE_A)), false) == OK, "Write a tempting older backup")
	_check(not saves.load_now("user://research_future.json"), "Future research contract is not silently downgraded to a backup")
	_check(progression.export_state() == before and not saves.save_now(), "Future save blocks overwrite and retains live campaign")
	_check(saves.load_now(SAVE_A), "Loading a compatible save clears the write block")


func _test_fresh_process() -> void:
	var arguments := PackedStringArray(["--headless"])
	var current_args: PackedStringArray = OS.get_cmdline_user_args()
	var pack_index: int = current_args.find("--research-pack")
	if pack_index >= 0:
		arguments.append_array(["--main-pack", current_args[pack_index + 1]])
	else:
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--script", get_script().resource_path, "--", "--research-child"])
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_check(code == 0 and not str(output).contains("SCRIPT ERROR"), "Independent process reload: %s" % str(output))


func _discover(seed_value: int, role: String) -> void:
	progression.register_species_discovery(seed_value, Species.create_species(seed_value, Vector2i.ZERO, role), 15838)


func _goal(id: String) -> Dictionary:
	for row in Research.rows(progression.export_state()):
		if row["id"] == id:
			return row
	return {}


func _without_research() -> Dictionary:
	var result: Dictionary = progression.export_state()
	result.erase("research")
	return result


func _tab(index: int) -> void:
	await _click_at(journal._tabs.get_global_transform_with_canvas() * journal._tabs.get_tab_rect(index).get_center())


func _select_key(key: String) -> void:
	for index in range(journal._rows.size()):
		if journal._rows[index].get("key", journal._rows[index].get("id", "")) == key:
			journal._list.select(index)
			journal._list.item_selected.emit(index)
			await _frames()
			return
	_check(false, "Requested row missing: " + key)


func _click(control: Control) -> void:
	# Preview/filter changes settle the detail height before scrolling to its action.
	await _frames()
	_check(control.is_visible_in_tree(), "Interaction target must be visible")
	if journal._detail_scroll.is_ancestor_of(control):
		journal._detail_scroll.ensure_control_visible(control)
	await _frames()
	await _click_at(control.get_global_transform_with_canvas() * (control.size * 0.5))


func _click_at(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()


func _frames() -> void:
	await process_frame
	await process_frame


func _capture(label: String) -> void:
	if not "--research-capture" in OS.get_cmdline_user_args():
		return
	await _frames()
	await RenderingServer.frame_post_draw
	var directory := "res://art/review/research_goals"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Capture " + label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("RESEARCH_GOALS_TEST ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
