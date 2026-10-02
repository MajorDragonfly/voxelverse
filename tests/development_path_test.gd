extends SceneTree

const PathModel = preload("res://core/progression/development_path.gd")
const Event = preload("res://core/campaign/game_event.gd")
const FIXTURE_PATH := "res://tests/fixtures/home_group_pr20.json"
const SAVE_PATH := "user://development_path_test.json"

var failures: Array[String] = []
var state: Node
var progression: Node
var saves: Node
var scene: Node3D
var ui: CanvasLayer
var fixture: Dictionary


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# This historical GUI fixture asserts German wording. The separate
	# localization suites exercise DE/EN; never depend on the runner OS locale.
	_expect(root.get_node("LocaleManager").save_preference("de") == OK, "Cannot select the German GUI fixture locale.")
	state = root.get_node("GameState")
	progression = root.get_node("ProgressionService")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE_PATH
	state.start_world_with_seed(15838)
	var fixture_path: String = FIXTURE_PATH if FileAccess.file_exists(FIXTURE_PATH) else get_script().resource_path.get_base_dir().path_join("home_group_pr20.json")
	fixture = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	_model_checks()
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	scene.add_child(player)
	await _frames()
	ui = scene.find_child("PlayerProgression", true, false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _key(KEY_K)
	_expect(ui.visible and paused, "K did not open the actual progression panel.")
	var before: Dictionary = _snapshot()
	await _click(ui._development_tab)
	_expect(ui._development.visible and not ui._body.visible and not ui.journal.is_open, "Development tab does not own its page.")
	_expect(ui._development._home.text.contains("noch keine") and ui._development._home.text.contains("noch nicht verfügbar"), "Absent home runtime is presented as an existing group.")
	_expect(_snapshot() == before and not FileAccess.file_exists(SAVE_PATH), "Viewing development wrote or changed campaign data.")
	await _compact_checks()
	await _capture("development_empty.png", Vector2i(1600, 900))
	# Use the exact schema-1 snapshot produced by the published PR #20 source.
	state.campaign.import_state(fixture["campaign"])
	state.activate_body(fixture["campaign"]["bodies"]["15838"]["id"], 15838, 0, false)
	ui._show_development()
	var home: Dictionary = progression.get_development_path()["home"]
	_expect(home["status"] == "saved" and home["member_count"] == 2 and not home["runtime_available"], "Published group snapshot not recognized without importing its runtime.")
	_expect(ui._development._home.text.contains("2 eigene Gefährten"), "Actual saved member count not shown.")
	await _capture("development_saved.png", Vector2i(1600, 900))
	# Earn a real backend wallet and purchase its three social nodes via GUI.
	for index in range(3):
		var event = state.campaign.next_event(Event.Kind.INTERACTION, "development_friend_%d" % index, 0, "befriended")
		event.encounter_id = "development_encounter_%d" % index
		event.behavior_context = {"target_relation": "wild"}
		_expect(state.record_campaign_event(event), "Reward fixture was rejected.")
	await _click(ui._tree_tab)
	for id in ["creature.social.approach", "creature.social.support", "creature.social.legacy"]:
		await _click(ui._cards[id]["button"])
		await _click(ui._purchase)
	_expect(progression.get_behavior_wallet(0)["spent"]["social"] == 9, "Legacy was not purchased using the existing wallet.")
	var saved_bytes: String = FileAccess.get_file_as_string(SAVE_PATH)
	before = _snapshot()
	await _choose_phase(1)
	_expect(ui._view_phase == 1 and ui._wallet_labels["social"].text.begins_with("0 Punkte"), "Tribe view shows the creature wallet.")
	_expect(not ui._cards["creature.social.approach"]["button"].is_visible_in_tree() and ui._purchase.disabled, "Tribe preview exposes creature purchase controls.")
	_expect(ui._phase_preview.text.contains("Werkzeuge herstellen") and ui._phase_preview.text.contains("eigentliche Stammesphase"), "Tribe loop is confused with the nest-group precursor.")
	_expect(ui._phase_preview.text.contains("Koordination +10 %") and ui._phase_preview.text.contains("Verteidigung folgt mit Stammeskämpfen"), "Real bought legacy or remaining combat scope is misrepresented.")
	ui._buy_selected()
	await _capture("tribe_wallet.png", Vector2i(1600, 900))
	for phase in range(2, 6):
		await _choose_phase(phase)
		_expect(ui._wallet_labels["social"].text.begins_with("0 Punkte") and ui._purchase.disabled, "Future view allows a purchase or leaks another phase's points.")
	_expect(_snapshot() == before and FileAccess.get_file_as_string(SAVE_PATH) == saved_bytes, "Browsing phases changed phase, points, members or save bytes.")
	_expect(not state.get_phase_transition_blockers(1).is_empty() and not saves.request_phase_transition(1), "Development view unlocked an unimplemented phase.")
	await _click(ui._development_tab)
	_expect(ui._development._legacy.text.contains("Koordination +10 %") and ui._development._legacy.text.contains("Nestgruppe noch nicht aktiv"), "Development path applies tribal legacy to nest companions.")
	await _capture("development_legacy.png", Vector2i(1600, 900))
	await _capture("development_800x900.png", Vector2i(800, 900))
	await _click(ui._tree_tab)
	await _choose_phase(1)
	await _capture("tribe_800x900.png", Vector2i(800, 900))
	await _choose_phase(0)
	_expect(ui._cards["creature.social.legacy"]["button"].is_visible_in_tree() and ui._purchase.text == "Freigeschaltet", "Returning to creature phase lost purchased state.")
	# The shared save preserves the extension; the adapter does not own its data.
	state.get_current_body_record().erase("home_group")
	_expect(saves.load_now(), "Shared save containing home-group extension failed to load.")
	_expect(progression.get_development_path()["home"]["member_count"] == 2, "Loading did not restore actual saved home members.")
	var group: Dictionary = state.get_current_body_record()["home_group"]
	group["schema"] = 2
	group["future_field"] = {"keep": [1, 2, 3]}
	before = _snapshot()
	ui._show_development()
	_expect(progression.get_development_path()["home"]["status"] == "unsupported", "Future group schema was coerced into the old preview.")
	_expect(_snapshot() == before, "Unknown group payload was rewritten by the view.")
	state.start_world_with_seed(63352)
	ui._show_development()
	_expect(ui._development._home.text.contains("noch keine") and ui._development._legacy.text.contains("Koordination +0 %"), "New campaign retained another campaign's group or legacy.")
	await _key(KEY_ESCAPE)
	_expect(not paused and not ui.visible, "Closing development did not release pause.")
	scene.queue_free()
	await _frames()
	if failures.is_empty():
		print("DEVELOPMENT_PATH_OK: published home contract, real GUI phase wallets, earned legacy, read-only navigation, load and new campaign")
	else:
		for failure in failures:
			push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _model_checks() -> void:
	var campaign: Dictionary = fixture["campaign"]
	var before: Dictionary = campaign.duplicate(true)
	var result: Dictionary = PathModel.describe(campaign, "15838", 0, true)
	_expect(result["current_stage"] == "nest_group" and not result["transition"]["available"], "Saved group was treated as an automatic tribe unlock.")
	result["home"]["member_count"] = 99
	_expect(campaign == before, "Summary exposed mutable live campaign records.")
	_expect(PathModel.read_home(campaign, "63352")["status"] == "missing", "A different planet inherited the current home group.")
	for damage in ["species", "body", "duplicate", "position", "surface", "schema"]:
		var candidate: Dictionary = campaign.duplicate(true)
		var home: Dictionary = candidate["bodies"]["15838"]["home_group"]
		match damage:
			"species": home["species_id"] = "another_species"
			"body": home["body_id"] = "another_body"
			"duplicate": home["members"][1]["id"] = home["members"][0]["id"]
			"position": home["members"][0]["position"][0] = INF
			"surface": home["surface_mode"] = "future_sphere"
			"schema": home["schema"] = 1.5
		var snapshot: Dictionary = candidate.duplicate(true)
		_expect(PathModel.read_home(candidate, "15838")["status"] != "saved", "Invalid home accepted: " + damage)
		_expect(candidate == snapshot, "Invalid home was modified: " + damage)


func _compact_checks() -> void:
	var starting: Dictionary = _snapshot()
	for size_value: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		for scale_value: float in [1.0, 1.25, 1.5]:
			root.content_scale_size = Vector2i.ZERO
			root.content_scale_factor = 1.0
			root.size = size_value
			root.get_node("DisplaySettings").ui_scale = scale_value
			for language: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(language)
				ui._layout()
				await _frames()
				await _frames()
				_expect(ui._panel.size.x <= 1059 and ui._panel.size.y <= 650, "Development view lost its compact size.")
				_expect(root.get_visible_rect().encloses(ui._panel.get_global_rect()), "Development view leaves the viewport.")
				_expect(ui._close.get_global_rect().end.x <= size_value.x, "Close control is clipped at %s / panel %s / viewport %s." % [ui._close.get_global_rect(), ui._panel.get_global_rect(), size_value])
				_expect(ui._scroll.size.y >= 80, "Development view has no usable detail viewport.")
				for chapter: String in ui._development.CHAPTERS:
					var button: Button = ui._development._chapter_buttons[chapter]
					_expect(not button.text.contains("PATH_"), "Untranslated chapter: " + chapter)
				ui._development.select_chapter("creature")
				ui._development._chapter_buttons["creature"].grab_focus()
				await _frames()
				_expect(ui._development._stage_labels["creature"]["title"].size.x >= 120 * scale_value, "Selected chapter title is squeezed into a vertical column.")
				await _capture_matrix(size_value, scale_value, language)
				ui._development._chapter_buttons["tribe"].grab_focus()
				await _key(KEY_ENTER)
				_expect(ui._development._chapter_details["tribe"].visible and not ui._development._chapter_details["creature"].visible, "Chapter selection displays more than one detail.")
				_expect(("Tribal progress" if language == "en" else "Stammesfortschritt") in ui._development._community.text, "Tribe milestone summary is not translated.")
				ui._development._chapter_buttons["medieval"].grab_focus()
				await _key(KEY_ENTER)
				_expect(ui._development._epochs[2]["action"].disabled and ("Playable medieval" if language == "en" else "Spielbares Mittelalter") in ui._development._epochs[2]["goals"].text, "Future transition is exposed or untranslated.")
				_expect(_snapshot() == starting, "Browsing translated chapters changed saved progress.")
	root.get_node("LocaleManager")._apply("de")
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.size = Vector2i(1600, 900)
	ui._layout()
	ui._development.select_chapter("nest_group")
	await _frames()


func _capture_matrix(size_value: Vector2i, scale_value: float, language: String) -> void:
	var args := OS.get_cmdline_user_args()
	if not "--capture" in args:
		return
	var directory: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	var filename := "development-%s-%dx%d-%d.png" % [language, size_value.x, size_value.y, roundi(scale_value * 100)]
	_expect(root.get_texture().get_image().save_png(directory.path_join(filename)) == OK, "Development matrix capture failed.")


func _snapshot() -> Dictionary:
	return {"state": state.export_state(), "progression": progression.export_state()}


func _choose_phase(index: int) -> void:
	if ui._phase_strip.visible:
		ui._phase_buttons[index].grab_focus()
		await _key(KEY_ENTER)
		_expect(ui._phase_choice.selected == index, "Chapter keyboard activation did not select phase %d." % index)
		return
	await _frames()
	ui._phase_choice.grab_focus()
	var distance: int = index - ui._phase_choice.selected
	await _key(KEY_SPACE)
	for step in range(absi(distance)):
		await _key(KEY_DOWN if distance > 0 else KEY_UP)
	await _key(KEY_ENTER)
	_expect(ui._phase_choice.selected == index, "Keyboard did not select phase %d." % index)


func _click(control: Control) -> void:
	_expect(control.is_visible_in_tree(), "Attempted to click a hidden control.")
	if ui._scroll.is_ancestor_of(control):
		ui._scroll.ensure_control_visible(control)
	await _frames()
	# Move the real pointer and settle hover geometry before button input,
	# as the public pause-menu probe does. Larger fonts can reflow the tabs.
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
	root.push_input(motion, true)
	await _frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
		event.global_position = event.position
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()


func _key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _frames()


func _capture(filename: String, dimensions: Vector2i) -> void:
	var args := OS.get_cmdline_user_args()
	if not "--capture" in args:
		return
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = dimensions
	ui._scroll.scroll_vertical = 0
	await _frames()
	ui._layout()
	await RenderingServer.frame_post_draw
	var directory: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(filename))


func _frames() -> void:
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
