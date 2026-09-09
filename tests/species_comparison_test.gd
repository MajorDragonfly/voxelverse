extends SceneTree

const Data = preload("res://core/discovery/species_comparison.gd")
const Symbols = preload("res://ui/discovery/stat_symbols.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")

var failures: Array[String] = []
var journal: CanvasLayer
var progression: Node
var saves: Node
var fixture: Node3D
var species_key: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://species_comparison_acceptance.json"
	progression = root.get_node("ProgressionService")
	await _frames()
	root.get_node("GameState").start_world_with_seed(15838)
	progression.reset_for_new_game()
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_test_projection()
	fixture = Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	fixture.add_child(player)
	await _frames()
	journal = player.get_node("ProgressionHUD").get("_discovery_journal")
	var anatomy: Dictionary = Species.create_species(771337, Vector2i(1, -2), "predator")
	var receipt: Dictionary = progression.register_species_discovery(771337, anatomy, 15838)
	species_key = receipt["species_key"]
	await _frames()
	_check(saves.save_now(), "Fixture is saved before read-only comparison")
	var saved_before: String = FileAccess.get_file_as_string(saves.save_path)
	var state_before: Dictionary = progression.export_state()
	var player_before: Dictionary = journal._player_blueprint()
	journal.open_journal()
	await _frames()
	await _click(journal._compare_button)
	var panel: VBoxContainer = journal._comparison
	_check(panel.is_visible_in_tree() and not journal._preview.visible, "Compare button opens exactly two dedicated previews")
	_check(paused and journal._owns_pause, "Comparison keeps the existing book pause")
	_check(panel.own_preview._model != null and panel.species_preview._model != null, "Both real creature models are built")
	_check(panel.stats_grid.get_child_count() == 28, "Six labelled comparison rows have own value, species value and difference")
	_check(_icon_count(panel.stats_grid) == 6, "Every compared value has its pictogram")
	_check(panel.own_preview._model.blueprint["body"] == player_before["body"], "Own preview uses the current player's anatomy")
	_check(panel.species_preview._model.blueprint["body"] == anatomy["body"], "Observed preview uses the discovery snapshot")
	_check(Data.formatted(Data.stats_for(player_before)["attack"]) == panel.stats_grid.get_child(5).text, "Displayed own attack matches the actual anatomy")
	await _capture("comparison")
	var angle: float = panel.own_preview._angle
	var other_angle: float = panel.species_preview._angle
	var hold := InputEventMouseButton.new()
	hold.position = panel.own_preview.get_global_rect().get_center()
	hold.global_position = hold.position
	hold.button_index = MOUSE_BUTTON_LEFT
	hold.pressed = true
	root.push_input(hold, true)
	await process_frame
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(28, 0)
	drag.position = panel.own_preview.get_global_rect().get_center()
	drag.global_position = drag.position
	root.push_input(drag, true)
	hold.pressed = false
	root.push_input(hold, true)
	await _frames()
	_check(panel.own_preview._angle != angle and panel.species_preview._angle == other_angle, "Dragging rotates only the chosen preview")
	var zoom: float = panel.species_preview._zoom
	var wheel := InputEventMouseButton.new()
	wheel.position = panel.species_preview.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	wheel.pressed = false
	root.push_input(wheel, true)
	await _frames()
	_check(panel.species_preview._zoom < zoom, "Wheel zoom reaches the selected model")
	_check(progression.export_state() == state_before and journal._player_blueprint() == player_before, "Browsing and rotating do not mutate discoveries or the live creature")
	_check(FileAccess.get_file_as_string(saves.save_path) == saved_before, "Browsing never writes the campaign")
	await _test_wish(panel)
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	await _frames()
	journal._detail_scroll.ensure_control_visible(panel.wish_button)
	await _frames()
	_check(root.get_visible_rect().encloses(journal._close.get_global_rect()), "Compact layout retains a reachable close button")
	_check(root.get_visible_rect().encloses(panel.wish_button.get_global_rect()), "Compact layout retains a reachable wishlist button")
	_check(panel.size.x <= journal._detail_scroll.size.x, "Comparison stays within the compact horizontal viewport")
	await _capture("compact")
	await _click(journal._compare_button)
	_check(journal._list.is_visible_in_tree() and journal._preview.visible, "Return restores the selected species browser")
	_check(panel.own_preview._model == null and panel.species_preview._model == null, "Leaving comparison releases both models")
	await _click(journal._compare_button)
	await _click(journal._close)
	_check(not paused and panel.own_preview._model == null and panel.species_preview._model == null, "Closing the book frees models and returns to gameplay")
	await _test_old_records()
	fixture.queue_free()
	current_scene = null
	await _frames()
	for failure in failures:
		push_error(failure)
	print("SPECIES_COMPARISON_TEST ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _test_projection() -> void:
	var body: Dictionary = Blueprint.create_default()
	Blueprint.clear_parts(body)
	Blueprint.add_part(body, "mouth_predator_jaws")
	Blueprint.add_part(body, "mouth_predator_jaws")
	var original: Dictionary = body.duplicate(true)
	_check(is_equal_approx(Data.stats_for(body)["attack"], 6.4), "Two jaws plus balanced core produce 6.4 attack")
	_check(is_equal_approx(Data.contribution(body, "mouth_predator_jaws")["attack"], 5.4), "Repeated parts contribute exactly 5.4 attack")
	_check(is_equal_approx(Data.contribution(body, "mouth_predator_jaws")["hunger_drain"], 0.1), "Part inspection includes the additional food cost")
	_check(Data.contribution(body, Blueprint.get_paint_part_id(body)).is_empty(), "Cosmetic paint invents no stat bonuses")
	_check(body == original, "Comparison projections never normalize or edit source anatomy")
	for metric in Data.METRICS:
		var texture: Texture2D = Symbols.ICONS.get(metric["id"])
		_check(texture != null and texture.get_size() == Vector2(32, 32), "Imported icon is available for " + str(metric["id"]))
	_check(Data.formatted(-0.000001, true) == "0" and Data.formatted(2.7, true) == "+2,7", "Display uses German decimals and suppresses negative zero")
	body["parts"][0]["part_id"] = "retired_test_part"
	_check(Data.stats_for(body).is_empty(), "Retired anatomy cannot masquerade as a weaker fully known species")
	_check(Data.stats_for({}).is_empty(), "Missing historical snapshots have no invented values")
	_check(Data.stats_for({"body": {}, "parts": []}).is_empty(), "Incomplete body records do not inherit a default creature's values")


func _test_wish(panel: VBoxContainer) -> void:
	var chosen: int = -1
	for i in range(panel._parts.size()):
		if not panel._parts[i]["unlocked"] and panel._parts[i]["available"]:
			chosen = i
			break
	_check(chosen >= 0, "Fixture includes a locked observed part")
	if chosen < 0:
		return
	panel.part_choice.select(chosen)
	panel.part_choice.item_selected.emit(chosen)
	await _frames()
	var part_id: String = panel._parts[chosen]["id"]
	var before: Dictionary = progression.export_state()
	saves.save_path = "user://comparison_missing_directory/save.json"
	await _click(panel.wish_button)
	_check(progression.export_state() == before and journal._action_message.text.contains("Speichern fehlgeschlagen"), "Failed wish through comparison rolls back with visible error")
	saves.save_path = "user://species_comparison_acceptance.json"
	await _click(panel.wish_button)
	_check(progression.get_research_settings()["wished_parts"].has(part_id), "Comparison wishlist button uses the shared persisted wishlist")
	_check(journal._comparison_mode and panel._selected_part == part_id, "Successful save retains comparison and selected part")
	var after: Dictionary = progression.export_state()
	before.erase("research")
	after.erase("research")
	_check(before == after, "Wishing an observed part grants no points, parts or species")
	_check(saves.load_now(), "Saved wish reloads through the real campaign service")
	_check(progression.get_research_settings()["wished_parts"].has(part_id), "Reload restores comparison wish")
	await _frames()
	journal._detail_scroll.ensure_control_visible(panel.wish_button)
	await _frames()
	await _capture("part")


func _test_old_records() -> void:
	var state: Dictionary = progression.export_state()
	state["discovered_species"][species_key].erase("journal")
	progression.import_state(state)
	journal.open_journal()
	await _frames()
	_check(not journal._compare_button.visible and journal._description.text.contains("fehlt eine gespeicherte Ansicht"), "Legacy species explains the missing snapshot and offers no invented comparison")
	await _click(journal._close)
	progression.reset_for_new_game()
	journal.open_journal()
	await _frames()
	_check(not journal._comparison.visible and not journal._compare_button.visible, "New campaign cannot retain a previous species comparison")
	await _click(journal._close)


func _icon_count(node: Node) -> int:
	var count: int = 1 if node is TextureRect and node.texture != null else 0
	for child in node.get_children():
		count += _icon_count(child)
	return count


func _click(control: Control) -> void:
	if journal._detail_scroll.is_ancestor_of(control):
		journal._detail_scroll.ensure_control_visible(control)
	await _frames()
	_check(control.is_visible_in_tree(), "Click target is visible: " + control.name)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()


func _frames() -> void:
	await process_frame
	await process_frame


func _capture(label: String) -> void:
	if not "--comparison-capture" in OS.get_cmdline_user_args():
		return
	await _frames()
	await RenderingServer.frame_post_draw
	var directory := "res://art/review/species_comparison"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Capture " + label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
