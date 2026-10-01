extends SceneTree
const Registry = preload("res://core/campaign/body_registry.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const GameplaySpace = preload("res://world/surface/gameplay_space.gd")
const SAVE: String = "user://tribal_age_test.json"
class ReadyWorld:
	extends Node
	var world_initialized: bool = true
var failures: Array[String] = []
var state: Node
var saves: Node
var scene: Node3D
var player: CharacterBody3D
var home: Node
var tribe: Node
var capture_dir: String = ""
var capture_on_demand: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# The action assertions below use German captions. Keep this fixture
	# deterministic on native Windows too; _check_minimap covers DE/EN layouts.
	root.get_node("LocaleManager")._apply("de")
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args: PackedStringArray = OS.get_cmdline_user_args()
	capture_on_demand = "--controls-only" in args and "--capture-on-demand" in args and "--capture" in args
	if capture_on_demand:
		# Keep input/layout and physics live; software diagnostics only need to
		# paint the comparable views, as in the existing tribal world probe.
		RenderingServer.render_loop_enabled = false
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	Engine.time_scale = 3.0
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	player.current_hunger = 61.0
	await _frames(25)
	_expect(not saves.request_phase_transition(1), "Empty nest unlocked tribal age.")
	_expect(home.establish_home()["ok"], "Could not establish precursor group.")
	await _frames(15)
	var original: Dictionary = home.group_state().duplicate(true)
	var progression: Dictionary = root.get_node("ProgressionService").export_state().duplicate(true)
	var old_bytes: String = FileAccess.get_file_as_string(SAVE)
	await _click(tribe.panel.entry)
	_expect(tribe.panel.confirmation_open and paused and not tribe.panel.confirm.disabled, "Transition dialog unavailable: " + tribe.panel._detail.text)
	await _capture("01_confirmation")
	await _click(tribe.panel.cancel)
	_expect(state.current_phase == 0 and not paused and FileAccess.get_file_as_string(SAVE) == old_bytes, "Cancel changed epoch or save: phase=%s paused=%s bytes_equal=%s dialog=%s" % [state.current_phase, paused, FileAccess.get_file_as_string(SAVE) == old_bytes, tribe.panel.confirmation_open])
	if "--entry-only" in args:
		tribe.panel.cancel_confirmation()
		await _cleanup()
		_finish()
		return
	_expect(not saves.request_phase_transition(1), "Unconfirmed API bypassed the dialog.")
	await _click(tribe.panel.entry)
	var token: String = tribe._token
	_expect(not saves.request_phase_transition(1, "stale-token"), "Stale confirmation accepted.")
	# A failed atomic save must not change phase, members, orders, points or camera.
	var file: FileAccess = FileAccess.open("user://blocked-parent", FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	saves.save_path = "user://blocked-parent/campaign.json"
	_expect(not saves.request_phase_transition(1, token), "Failed write reported successful transition.")
	_expect(state.current_phase == 0 and not state.get_current_body().has("tribe") and home.actors.size() == 2, "Failed write installed a half-tribe.")
	saves.save_path = SAVE
	tribe.panel.cancel_confirmation()
	await _frames(3)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active(), 600)
	_expect(state.current_phase == 1 and tribe.is_active(), "Confirmation did not activate the playable tribe: " + saves.last_error)
	if not tribe.is_active():
		await _cleanup()
		_finish()
		return
	if "--controls-only" in args:
		await _check_controls_matrix()
		await _cleanup()
		_finish()
		return
	_expect(absf(float(tribe.village()["members"][0]["hunger"]) - 61.0) < 0.5, "Transition did not preserve the original creature hunger ratio.")
	_expect(not player.is_physics_processing() and tribe.camera.current and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Control did not switch from creature to group overview.")
	_expect(tribe.panel._top_bar.visible and tribe.panel._stock_labels["wood"].is_visible_in_tree()
		and tribe.panel._hud.visible and tribe.panel._tabs.is_visible_in_tree(),
		"Tribal overview did not show resources above and actions below.")
	_expect(tribe.panel._top_bar.size.x < 0.7 * root.size.x and tribe.panel._top_bar.position.y + tribe.panel._top_bar.size.y < tribe.panel._hud.position.y,
		"Resource strip exceeded its top bar or overlapped the bottom actions: %s / %s" % [tribe.panel._top_bar.get_rect(), tribe.panel._hud.get_rect()])
	var initial_speed: float = Engine.time_scale
	tribe.panel._speed_selector.select(1)
	tribe.panel._speed_selector.item_selected.emit(1)
	_expect(is_equal_approx(Engine.time_scale, 2.0), "Village speed selection did not change the simulation rate.")
	await _click(tribe.panel._speed_pause)
	_expect(paused and tribe.panel._owns_pause and tribe.panel._speed_pause.text == "Weiter", "Pause button did not stop the village simulation.")
	await _frames(3)
	await _click(tribe.panel._speed_pause)
	_expect(not paused and not tribe.panel._owns_pause, "Resume button left the village paused.")
	tribe.panel._speed_selector.select(2)
	tribe.panel._speed_selector.item_selected.emit(2)
	_expect(is_equal_approx(Engine.time_scale, initial_speed), "Village speed did not restore the test's original rate.")
	if "--speed-only" in args:
		await _cleanup()
		_finish()
		return
	_expect(home.actors.is_empty() and tribe.actors.size() == 3 and tribe.actors[state.campaign.data["player_object_id"]] == player, "Original creature was replaced or residents duplicated.")
	for i in range(2):
		_expect(tribe.village()["members"][i + 1]["id"] == original["members"][i]["id"], "Original companion identity changed.")
	_expect(root.get_node("ProgressionService").export_state() == progression, "Transition changed purchased behavior, points or relationships.")
	_expect(not saves.request_phase_transition(1, token) and not saves.request_phase_transition(2), "Duplicate or later transition accepted.")
	_expect(Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty(), "Invalid fresh tribe.")
	# Group control keeps existing menus and phase-specific combat ownership.
	var original_health: float = player.current_health
	player.receive_damage(10000)
	_expect(player.current_health == original_health and not player.is_dead, "Creature combat attacked only the former player in civilian group mode.")
	var skills: Node = player.find_child("PlayerProgression", true, false)
	_expect(skills.open_panel(), "Tribal group control cannot open the existing development view.")
	_key(KEY_SPACE)
	_expect(paused and skills.visible, "Tribal pause key released another menu's pause.")
	skills.close_panel()
	await _frames(3)
	var journal: Node = skills.journal
	_expect(journal.visible and journal.open_journal(), "Shared journal disappeared after tribal transition.")
	_expect(journal.is_open and paused and journal._surface.visible, "Tribal journal failed to own its visible modal.")
	journal.close_journal()
	await _frames(3)
	_expect(not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Closing tribal journal restored creature mouse capture.")
	await _check_minimap()
	await _capture("02_group")
	# M6's expanded economy controls can cover the companions. Use its real
	# collapse button before clicking/dragging in the world, like the player.
	await _click(tribe.panel._collapse)
	await _frames(3)
	var identity: String = str(tribe.village()["members"][0]["id"])
	var screen_point: Vector2 = tribe.camera.unproject_position(player.global_position + Vector3.UP)
	await _world_click(screen_point, MOUSE_BUTTON_LEFT)
	# The detail refreshes every 0.2 simulation seconds while needs continue
	# ticking each physics frame. Allow one refresh interval of meter drift.
	_expect(tribe.selected.size() == 1 and tribe.selected[0] == identity, "World click did not select the original creature.")
	_expect(tribe.panel._resident_detail.visible and tribe.panel._resident_name.text == tribe.member_record(identity).name
		and absf(tribe.panel._resident_food.value - float(tribe.member_record(identity).hunger)) < 0.1
		and absf(tribe.panel._resident_water.value - float(tribe.member_record(identity).hydration)) < 0.1
		and preload("res://core/localization/ui_text.gd").text("TRIBE_RESIDENT_DETAIL_CLOTHING") in tribe.panel._resident_equipment.text,
		"World selection did not show the resident's real name, needs and honest equipment status: %s" % JSON.stringify({"selected": tribe.selected, "visible": tribe.panel._resident_detail.visible, "name": tribe.panel._resident_name.text, "food": tribe.panel._resident_food.value, "expected_food": tribe.member_record(identity).hunger, "water": tribe.panel._resident_water.value, "expected_water": tribe.member_record(identity).hydration, "equipment": tribe.panel._resident_equipment.text, "locale": TranslationServer.get_locale()}))
	var companion_id: String = str(tribe.village()["members"][1]["id"])
	await _world_click(tribe.camera.unproject_position(tribe.actors[companion_id].global_position + Vector3.UP), MOUSE_BUTTON_LEFT, true)
	_expect(tribe.selected.size() == 2, "Shift-click did not add the companion to the group.")
	_expect(not tribe.panel._resident_detail.visible, "Multi-selection retained the wrong individual detail.")
	var selection_rect := Rect2(screen_point, Vector2.ONE)
	for actor: Node3D in tribe.actors.values():
		selection_rect = selection_rect.expand(tribe.camera.unproject_position(actor.global_position + Vector3.UP))
	selection_rect = selection_rect.grow(12)
	await _world_drag(selection_rect.position, selection_rect.end)
	_expect(tribe.selected.size() == 3 and not tribe.panel._dragging, "Drag selection did not select and release the whole group.")
	tribe.select_member(identity)
	var before: Vector3 = player.global_position
	await _world_click(tribe.camera.unproject_position(before + Vector3(3, 0, 0)), MOUSE_BUTTON_RIGHT)
	_expect(tribe.member_record(identity)["order"] == "move", "Right-click did not issue the group move.")
	await _frames(65)
	_expect(player.global_position.distance_to(before) > 1.5 and player.is_on_floor(), "Original creature did not walk under group command.")
	_expect(tribe.village()["members"][1]["order"] == "wait", "Individual move commanded other residents.")
	await _click(tribe.panel._collapse)
	tribe.select_all()
	await _frames(3)
	await _click(tribe.panel._buttons["wood"])
	# Prepare the real pointer/scroll first, then observe cargo immediately
	# before press/release. Rendering or HUD layout can otherwise let a valid
	# delivery finish between the pickup observation and the Stop click.
	var before_stop: Dictionary = {}
	await _click(tribe.panel._buttons["wait"], func() -> void:
		await _until(func() -> bool: return _has_cargo(), 350)
		_expect(_has_cargo(), "Gatherers did not pick up material at a real deposit before Stop.")
		before_stop["stock"] = tribe.village()["stock"].duplicate(true)
		before_stop["cargo"] = _cargo_by_member()
		before_stop["delivered"] = int(tribe.village()["delivered"])
	)
	await _frames(10)
	_expect(tribe.village()["members"].all(func(member: Dictionary) -> bool: return member["order"] == "wait"), "Stop click did not stop all selected gatherers.")
	_expect(_has_cargo() and _cargo_by_member() == before_stop.get("cargo", {})
		and tribe.village()["stock"] == before_stop.get("stock", {})
		and int(tribe.village()["delivered"]) == before_stop.get("delivered", -1),
		"Stop discarded cargo or credited it without a delivery: " + JSON.stringify({"before": before_stop, "after": {"stock": tribe.village()["stock"], "cargo": _cargo_by_member(), "delivered": tribe.village()["delivered"]}}))
	# A stopped carrier still shows the real acquired material, without a
	# screenshot's frame_post_draw advancing the pre-click simulation.
	await _capture("03_transport")
	await _click(tribe.panel._buttons["wood"])
	var at_save: Dictionary = tribe.village().duplicate(true)
	_expect(saves.save_now() and saves.load_now(), "Could not reload a running delivery.")
	await _until(func() -> bool: return tribe.is_active(), 600)
	_expect(tribe.actors.size() == 3 and int(tribe.village()["deposits"]["wood"]["remaining"]) <= int(at_save["deposits"]["wood"]["remaining"]), "Reload duplicated residents or restored harvested wood.")
	await _until(func() -> bool: return int(tribe.village()["stock"]["wood"]) >= 15, 1900)
	_expect(int(tribe.village()["stock"]["wood"]) >= 15, "Workers failed to carry wood home: " + str(tribe.village()["members"]))
	tribe.select_all()
	await _click(tribe.panel._buttons["stone"])
	await _until(func() -> bool: return int(tribe.village()["stock"]["stone"]) >= 8, 1500)
	_expect(int(tribe.village()["stock"]["stone"]) >= 8, "Stone did not reach the stockpile.")
	await _click(tribe.panel._buttons["food"])
	await _until(func() -> bool: return int(tribe.village()["stock"]["food"]) >= 3, 700)
	_expect(int(tribe.village()["stock"]["food"]) >= 3, "Food did not reach the stockpile.")
	await _click(tribe.panel._buttons["tool"])
	await _until(func() -> bool: return int(tribe.village()["tools"]) == 1, 550)
	_expect(int(tribe.village()["tools"]) == 1, "Workers did not craft the actual tool.")
	await _capture("04_tool")
	await _click(tribe.panel._buttons["hut"])
	await _world_click(tribe.camera.unproject_position(Vector3(5, 100.06, 5)), MOUSE_BUTTON_RIGHT)
	var project_before: Dictionary = tribe.village().project.duplicate(true)
	_expect(not project_before.is_empty(), "Hut placement did not create a site to inspect.")
	if not project_before.is_empty():
		var site: Vector3 = GameplaySpace.resolve(tribe, project_before.position)
		var construction_point: Vector2 = tribe.camera.unproject_position(site + GameplaySpace.up(tribe, site) * 2.8)
		_expect(tribe.project_at(construction_point), "The visible construction site cannot be picked by its label.")
		await _world_click(construction_point, MOUSE_BUTTON_LEFT)
		_expect(tribe.panel._tabs.get_current_tab_control() == tribe.panel._build_page and not tribe.panel._collapsed
			and tribe.panel._construction.visible and "offen" in tribe.panel._construction._details.text,
			"Clicking the site did not reveal construction progress and materials.")
		_expect(tribe.village().project == project_before, "Inspecting a construction site changed the project state.")
		tribe.select_all()
	await _until(func() -> bool: return int(tribe.village()["huts"]) == 1, 1600)
	_expect(int(tribe.village()["huts"]) == 1, "Workers did not finish the first shelter.")
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	await _click(tribe.panel._buttons["feed"])
	await _until(func() -> bool: return int(tribe.village()["meals"]) >= 3, 350)
	_expect(int(tribe.village()["meals"]) >= 3, "Feeding did not consume village food.")
	await _click(tribe.panel._buttons["hut"])
	await _world_click(tribe.camera.unproject_position(Vector3(9, 100.06, 1)), MOUSE_BUTTON_RIGHT)
	await _until(func() -> bool: return int(tribe.village()["huts"]) == 2, 1600)
	_expect(int(tribe.village()["huts"]) == 2, "The village could not expand to four sleeping places.")
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 1200)
	await _capture("05_village")
	_expect(Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty(), "Village economy produced invalid state.")
	_expect(saves.save_now(), "Completed village did not save.")
	var final_state: Dictionary = tribe.village().duplicate(true)
	_key(KEY_SPACE)
	await _frames(15)
	_expect(paused and tribe.village() == final_state, "Village simulation continued while paused.")
	_key(KEY_SPACE)
	var committed: String = FileAccess.get_file_as_string(SAVE)
	# A future extension is never silently replaced by the older backup.
	var future: Dictionary = JSON.parse_string(committed)
	Registry.active(future.game_state)["tribe"]["schema"] = Model.SCHEMA + 1
	var output: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	output.store_string(JSON.stringify(future))
	output.close()
	_expect(not saves.load_now() and not saves.save_now(), "Newer tribe contract was downgraded or overwritten.")
	output = FileAccess.open(SAVE, FileAccess.WRITE)
	output.store_string(committed)
	output.close()
	_expect(saves.load_now(), "Compatible village could not be restored.")
	await _frames(8)
	_expect(int(tribe.village()["huts"]) == 2 and int(tribe.village()["tools"]) == 1 and int(tribe.village()["meals"]) == int(final_state["meals"]), "Completed work repeated on load.")
	state.start_world_with_seed(15838)
	await _frames(8)
	_expect(not state.get_current_body().has("tribe") and not tribe._active and not tribe.panel._hud.visible, "New campaign retained the previous tribe.")
	_expect(home.establish_home()["ok"], "New campaign cannot create its own nest.")
	await _frames(20)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active(), 600)
	if tribe.is_active():
		await _click(tribe.panel._residents.get_child(1))
		_expect(tribe.selected == [str(tribe.village()["members"][1]["id"])], "New campaign's resident buttons still select the former campaign's IDs.")
		_expect(tribe.panel._resident_detail.visible and tribe.panel._resident_name.text == tribe.village()["members"][1]["name"], "Resident detail retained the former campaign's identity.")
		var source: Dictionary = tribe.village().deposits.wood
		var location: Vector3 = GameplaySpace.resolve(tribe, source.position)
		var source_point: Vector2 = tribe.camera.unproject_position(location + GameplaySpace.up(tribe, location) * 2.3)
		_expect(tribe.resource_at(source_point).get("id", "") == source.id, "Visible wood source is not inspectable.")
		await _world_click(source_point, MOUSE_BUTTON_LEFT)
		_expect(tribe.panel._tabs.get_current_tab_control() == tribe.panel._work_page and tribe.panel._resource_area.visible
			and tribe.panel._resource_area.source_id == source.id
			and str(source.remaining) in tribe.panel._resource_area._amount.text,
			"World click did not reveal the canonical source amount in the work area.")
		var previous_size: Vector2i = root.size
		var display: Node = root.get_node("DisplaySettings")
		var previous_scale: float = display.ui_scale
		root.size = Vector2i(800, 600)
		display.ui_scale = 1.5
		await _frames(4)
		tribe.panel._scroll.ensure_control_visible(tribe.panel._resource_area._add)
		await _frames(3)
		_expect(_physical_rect(tribe.panel._hud).has_point(_physical_rect(tribe.panel._resource_area._add).get_center()),
			"Work-area assignment cannot be reached at 800×600 with large UI text.")
		root.size = previous_size
		display.ui_scale = previous_scale
		await _frames(4)
		await _click(tribe.panel._resource_area._add)
		_expect(tribe.resource_details(source.id).assigned == 1 and Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty(),
			"Adding a gatherer did not commit one valid work assignment.")
		await _click(tribe.panel._resource_area._remove)
		_expect(tribe.resource_details(source.id).assigned == 0, "Removing a gatherer left the work area assigned.")
	else:
		_expect(false, "Second campaign cannot enter its own tribe.")
	await _cleanup()
	_finish()

func _check_minimap() -> void:
	var map := get_first_node_in_group(&"minimap_hud")
	_expect(map != null, "Tribe has no shared minimap.")
	if map == null: return
	map._update_snapshot()
	_expect(map.visible and map.phase == 1 and map.range_m == 160.0, "Real confirmed transition did not widen the map.")
	_expect(map._map.group_view and map._map.markers.size() == 4, "Tribe map lost home or one of its three residents.")
	var atlas: CanvasLayer = map.atlas_window
	atlas.tracker.update_exploration()
	var fog: Dictionary = atlas.tracker.atlas.data.duplicate(true)
	var original_focus: Vector3 = tribe.map_focus()
	tribe._focus += Vector3(200, 0, 200)
	atlas.tracker.update_exploration()
	_expect(atlas.tracker.atlas.data == fog, "Panning the tribal camera revealed unvisited ground.")
	tribe._focus = original_focus
	_expect(atlas.open_map() and paused, "Active tribe cannot open the shared world map.")
	_key(KEY_SPACE)
	_expect(paused and atlas.is_open, "Tribal pause key released the atlas pause.")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Closing the tribal atlas restored the wrong controls.")

	var original_size: Vector2i = root.size
	var settings := root.get_node("DisplaySettings")
	var original_scale: float = settings.ui_scale
	var locale := root.get_node("LocaleManager")
	var original_language: String = locale.locale
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		for scale in [1.0, 1.25, 1.5]:
			for language in ["de", "en"]:
				root.size = dimensions
				settings.ui_scale = scale
				locale._apply(language)
				await _frames(5)
				map._layout()
				tribe.panel.refresh()
				await _frames(2)
				var map_rect := _physical_rect(map._panel)
				var commands := _physical_rect(tribe.panel._hud)
				var resources := _physical_rect(tribe.panel._top_bar)
				var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
				var context := "%s/%s/%s" % [dimensions, scale, language]
				_expect(screen.encloses(map_rect), "Tribal map escaped screen: " + context)
				_expect(screen.encloses(commands), "Tribal commands escaped screen: " + context + " " + str(commands))
				_expect(screen.encloses(resources) and not resources.intersects(commands) and not resources.intersects(map_rect),
					"Resource bar escaped or overlapped the village HUD: " + context + " " + str(resources))
				_expect(resources.has_point(_physical_rect(tribe.panel._speed_pause).get_center()), "Speed controls escaped resource bar: " + context)
				_expect(not map_rect.intersects(commands), "Tribal orders cover the minimap: " + context)
				tribe.panel._hud_scroll.ensure_control_visible(tribe.panel._buttons["wait"])
				await _frames(2)
				_expect(commands.has_point(_physical_rect(tribe.panel._buttons["wait"]).get_center()), "Last tribal order cannot be reached by scrolling: " + context)
				_expect(tribe.panel._stock_labels.wood.tooltip_text.contains("/"), "Resource detail lost at " + context)
	root.size = original_size
	settings.ui_scale = original_scale
	locale._apply(original_language)
	await _frames(5)
	var selected: Array = tribe.selected.duplicate()
	var orders: Array = tribe.village()["members"].duplicate(true)
	var point: Vector2 = map._map.get_global_transform_with_canvas() * (map._map.size * 0.5)
	await _world_click(point, MOUSE_BUTTON_LEFT)
	await _world_click(point, MOUSE_BUTTON_RIGHT)
	_expect(tribe.selected == selected, "Map click changed world selection.")
	for index in range(orders.size()):
		_expect(orders[index]["order"] == tribe.village()["members"][index]["order"], "Map click issued a world order.")

func _physical_rect(control: Control) -> Rect2:
	var canvas: Transform2D = control.get_global_transform_with_canvas()
	var factor: float = float(root.size.x) / root.get_visible_rect().size.x
	return Rect2(canvas.origin * factor, control.size * canvas.get_scale() * factor)

func _world_click(position: Vector2, button: int, shift: bool = false) -> void:
	# A world click follows an actual pointer move. Without the motion event,
	# Godot still reports the previously hovered HUD control and drops the click.
	_move_mouse(position)
	await process_frame
	for pressed_value in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = button
		event.pressed = pressed_value
		event.shift_pressed = shift
		root.push_input(event, true)
	await process_frame

func _move_mouse(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)

func _world_drag(start: Vector2, end: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = end
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	press.position = end
	press.pressed = false
	root.push_input(press, true)
	await process_frame

func _has_cargo() -> bool:
	for member: Dictionary in tribe.village().get("members", []):
		if member["cargo"] != "":
			return true
	return false

func _cargo_by_member() -> Dictionary:
	var carried: Dictionary = {}
	for member: Dictionary in tribe.village().get("members", []):
		carried[member["id"]] = {"resource": member["cargo"], "source_id": member.get("cargo_source_id", ""), "construction_id": member["construction_id"]}
	return carried

func _until(condition: Callable, frames: int) -> void:
	for frame in range(frames):
		if condition.call():
			return
		await physics_frame
		await process_frame

func _build_fixture() -> void:
	root.size = Vector2i(1280, 800)
	scene = Node3D.new()
	scene.name = "HomeGroupFixture"
	root.add_child(scene)
	current_scene = scene
	var manager := ReadyWorld.new()
	manager.name = "WorldManager"
	scene.add_child(manager)
	_box(Vector3(80, 1, 80), Vector3(0, 99.5, 0))
	player = load("res://creatures/player/player.tscn").instantiate()
	scene.add_child(player)
	player.position = Vector3(0, 100.05, 0)
	player.set_physics_process(false)
	player.set_process(false)
	var nest: Node3D = load("res://world/resources/nests/nest.tscn").instantiate()
	nest.snap_to_terrain = false
	scene.add_child(nest)
	nest.position = Vector3(0, 100.02, 0)
	home = nest.get_node("HomeGroup")
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	scene.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.19, 0.25, 0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.80, 0.88, 0.80)
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(8, 107, 14)
	camera.look_at(Vector3(0, 101, 0))
	camera.make_current()

func _box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.29, 0.39, 0.24)
	visual.material_override = material
	body.add_child(visual)
	scene.add_child(body)
	body.position = position
	return body

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _click(button: Button, before_press: Callable = Callable()) -> void:
	# World selection, help return and observed work can resize the HUD before
	# tab navigation. Scroll only after its containers have arranged the page.
	await _frames(3)
	# Construction now has its own detail tab. Navigate through the real tab
	# bar before locating an action, just as a player would.
	if tribe != null and button != null and tribe.panel._tabs.is_ancestor_of(button):
		var tabs: TabContainer = tribe.panel._tabs
		for index in range(tabs.get_tab_count()):
			if tabs.get_tab_control(index).is_ancestor_of(button) and tabs.current_tab != index:
				var bar: TabBar = tabs.get_tab_bar()
				await _show_in_scroll(tribe.panel._scroll, bar)
				bar.ensure_tab_visible(index)
				await _frames(2)
				var tab_point: Vector2 = bar.get_global_transform_with_canvas() * bar.get_tab_rect(index).get_center()
				_move_mouse(tab_point)
				await process_frame
				# Pointer delivery may change layout. Read the click point again
				# immediately before normal mouse press/release, as for buttons.
				tab_point = bar.get_global_transform_with_canvas() * bar.get_tab_rect(index).get_center()
				_move_mouse(tab_point)
				var physical: Vector2 = tab_point * float(root.size.x) / root.get_visible_rect().size.x
				var hovered: Control = root.gui_get_hovered_control()
				var in_view: bool = Rect2(Vector2.ZERO, Vector2(root.size)).has_point(physical) and _physical_rect(tribe.panel._scroll).has_point(physical)
				var exposed: bool = hovered == bar or (hovered != null and bar.is_ancestor_of(hovered))
				_expect(in_view, "Tab click is outside the visible viewport/scroll: " + str({"wanted": index, "point": physical, "scroll": _physical_rect(tribe.panel._scroll)}))
				_expect(exposed, "Tab click is covered by another control: " + str({"wanted": index, "hovered": hovered}))
				if not in_view or not exposed: return
				for down: bool in [true, false]:
					var press := InputEventMouseButton.new()
					press.position = tab_point
					press.button_index = MOUSE_BUTTON_LEFT
					press.pressed = down
					root.push_input(press, true)
				await process_frame
				await _frames(3)
				_expect(tabs.current_tab == index, "Cannot open the action's tab: " + str({"wanted": index, "actual": tabs.current_tab, "point": physical, "bar": _physical_rect(bar), "scroll": _physical_rect(tribe.panel._scroll), "hovered": hovered}))
				if tabs.current_tab != index: return
	if tribe != null and tribe.panel._scroll.is_ancestor_of(button):
		await _show_in_scroll(tribe.panel._scroll, button)
	_expect(button != null and button.is_visible_in_tree(), "Required button is absent: " + (str(button.name) if button != null else "null"))
	if button == null:
		return
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_move_mouse(event.position)
	await process_frame
	# Optional running-world preconditions are observed after every yielding
	# preparation step. No physics/render await separates them from the click.
	if before_press.is_valid():
		await before_press.call()
	# Re-read after pointer delivery; do not click a stale button rectangle.
	event.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_move_mouse(event.position)
	var physical: Vector2 = event.position * float(root.size.x) / root.get_visible_rect().size.x
	var in_view: bool = Rect2(Vector2.ZERO, Vector2(root.size)).has_point(physical)
	if tribe != null and tribe.panel._scroll.is_ancestor_of(button):
		in_view = in_view and _physical_rect(tribe.panel._scroll).has_point(physical)
	var hovered: Control = root.gui_get_hovered_control()
	var exposed: bool = hovered == button or (hovered != null and button.is_ancestor_of(hovered))
	_expect(in_view, "Action click is outside the visible viewport/scroll: " + str({"name": button.name, "point": physical}))
	_expect(exposed, "Action click is covered by another control: " + str({"name": button.name, "hovered": hovered}))
	if not button.is_visible_in_tree() or not in_view or not exposed: return
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _show_in_scroll(scroll: ScrollContainer, control: Control) -> void:
	if control is Button and _physical_rect(scroll).grow(1.0).encloses(_physical_rect(control)):
		return
	scroll.ensure_control_visible(control)
	await _frames(3)
	# ensure_control_visible can leave descendants of a TabContainer below the
	# viewport after a page or resident-detail layout change. Scroll the actual
	# clipped distance and verify that a mouse click can reach the whole control.
	var window: Rect2 = _physical_rect(scroll)
	var target: Rect2 = _physical_rect(control)
	var scale: float = window.size.y / maxf(scroll.size.y, 1.0)
	if target.position.y < window.position.y:
		scroll.scroll_vertical -= ceili((window.position.y - target.position.y + 4.0) / scale)
	elif target.end.y > window.end.y:
		scroll.scroll_vertical += ceili((target.end.y - window.end.y + 4.0) / scale)
	await _frames(3)
	var visible_rect: Rect2 = _physical_rect(scroll).grow(1.0)
	var control_rect: Rect2 = _physical_rect(control)
	# A wrapping prose label can be taller than the scroll viewport. Its text
	# is read in successive scroll positions; buttons must still fit completely.
	var readable_label: bool = control is Label and control_rect.size.y > visible_rect.size.y and visible_rect.intersects(control_rect)
	_expect(visible_rect.encloses(control_rect) or readable_label, "Action remains clipped in village HUD: " + control.name)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _capture(label: String) -> void:
	print("TRIBAL_STAGE: " + label)
	if capture_dir.is_empty():
		return
	if capture_on_demand: RenderingServer.render_loop_enabled = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(not image.is_empty(), "Empty viewport capture.")
	image.save_png(capture_dir.path_join(label + ".png"))
	if capture_on_demand: RenderingServer.render_loop_enabled = false

func _cleanup() -> void:
	scene.queue_free()
	await _frames(4)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("TRIBAL_CHECK_FAILED: " + message)

func _finish() -> void:
	RenderingServer.render_loop_enabled = true
	print(JSON.stringify({"test": "tribal_age", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _check_scrolled_actions() -> void:
	for button: Button in tribe.panel._buttons.values():
		tribe.panel._tabs.current_tab = button.get_parent().get_parent().get_index()
		var page: Control = tribe.panel._tabs.get_current_tab_control()
		_expect(tribe.panel._goal.visible == (page == tribe.panel._orders_page) and tribe.panel._supply.visible, "Tab context waits for a simulation tick and can shift a scrolled action")
		await _frames(3)
		# TabContainer applies page visibility in its deferred container pass.
		_expect(tribe.panel._supply.is_visible_in_tree() == (page == tribe.panel._work_page), "Supply details escaped their workplace page.")
		if not button.is_visible_in_tree():
			continue # Milk pickup appears only when a delivery exists.
		tribe.panel._scroll.ensure_control_visible(button)
		await _frames(3)
		var rect: Rect2 = button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
		var scroll_rect: Rect2 = tribe.panel._scroll.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, tribe.panel._scroll.size)
		# Integer scrolling and canvas scaling can round an edge by less than one viewport pixel.
		_expect(button.is_visible_in_tree() and root.get_visible_rect().encloses(rect) and scroll_rect.grow(1.0).encloses(rect), "Action outside viewport or clipped: %s rect=%s scroll=%s" % [button.name, rect, scroll_rect])

## Supplemental rendered acceptance. Keep the ordinary lifecycle test's
## existing budgets; run this full mouse matrix with --controls-only.
func _check_controls_matrix() -> void:
	var panel: CanvasLayer = tribe.panel
	var settings: Node = root.get_node("DisplaySettings")
	var locale: Node = root.get_node("LocaleManager")
	var rows: Array[Dictionary] = []
	var initial_village: Dictionary = tribe.village().duplicate(true)
	# Keep the game's configured canvas stretch, not an unscaled replacement.
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.25, 1.5]:
			for language: String in ["de", "en"]:
				if "--matrix-one" in OS.get_cmdline_user_args() and not rows.is_empty(): continue
				var first_failure: int = failures.size()
				# Each layout case starts from the same valid idle fixture. Do not let
				# a previous case's cancelled builder or resumed carrier bias picking.
				tribe.set_physics_process(false)
				tribe.replace_village(initial_village.duplicate(true))
				tribe.placement = ""
				tribe.building_preview.clear_preview()
				for member: Dictionary in tribe.village().members:
					tribe.actors[member.id].global_position = GameplaySpace.resolve(tribe, member.position)
					tribe.actors[member.id].velocity = Vector3.ZERO
				tribe.camera_rig.focus_home()
				tribe.select_all()
				# This is a static layout fixture. Build the real collision-tested
				# graph through its diagnostic adapter instead of rendering hundreds
				# of idle frames after the previous case's cancelled construction.
				# Production streaming/navigation remains in the ordinary age test.
				tribe.navigation.rebuild(home, tribe.anchor(), tribe.village(), tribe.navigation_extent())
				tribe.set_physics_process(true)
				_expect(tribe.navigation.is_ready(), "Prior build's navigation did not settle between layout cases.")
				root.size = dimensions
				settings.ui_scale = scale
				root.content_scale_factor = scale
				locale._apply(language)
				await _frames(6)
				var context: String = "%dx%d_%d_%s" % [dimensions.x, dimensions.y, roundi(scale * 100), language]
				for speed: int in [1, 2, 3, 1]:
					await _mouse_speed(speed - 1)
					_expect(is_equal_approx(Engine.time_scale, float(speed)), "Mouse speed failed: " + context + "/" + str(speed))
				await _click(panel._speed_pause)
				_expect(paused and panel._owns_pause and panel._speed_pause.text == preload("res://core/localization/ui_text.gd").text("TRIBE_RESUME_TIME"), "Mouse pause failed: " + context)
				var frozen: Dictionary = tribe.village().duplicate(true)
				await _frames(6)
				_expect(tribe.village() == frozen, "Mouse pause advanced village: " + context)
				await _capture("matrix_" + context + "_pause")
				await _click(panel._speed_pause)
				_expect(not paused and not panel._owns_pause, "Mouse resume failed: " + context)
				# Freeze resident physics only for repeatable layout/picking fixtures.
				# The actual pause check above runs with production physics enabled.
				tribe.set_physics_process(false)
				if not panel._collapsed: await _click(panel._collapse)
				var identity: String = str(tribe.village().members[0].id)
				var actor_point: Vector2 = tribe.camera.unproject_position(tribe.actors[identity].global_position + Vector3.UP)
				await _world_click(actor_point, MOUSE_BUTTON_LEFT)
				_expect(tribe.selected == [identity], "Resident world click failed: " + context)
				await _click(panel._collapse)
				await _show_in_scroll(panel._scroll, panel._resident_name)
				_expect(panel._resident_detail.is_visible_in_tree() and panel._resident_name.text == tribe.member_record(identity).name, "Resident detail failed: " + context)
				_expect(preload("res://core/localization/ui_text.gd").text("TRIBE_RESIDENT_DETAIL_CLOTHING") in panel._resident_equipment.text, "Personal equipment limitation disappeared: " + context)
				await _capture("matrix_" + context + "_resident")
				await _show_in_scroll(panel._scroll, panel._resident_equipment)
				await _capture("matrix_" + context + "_resident_needs")
				await _click(panel._collapse)
				var companion: String = str(tribe.village().members[1].id)
				await _world_click(tribe.camera.unproject_position(tribe.actors[companion].global_position + Vector3.UP), MOUSE_BUTTON_LEFT, true)
				_expect(tribe.selected.size() == 2 and not panel._resident_detail.visible, "Shift multi-selection failed: " + context)
				var source: Dictionary = tribe.village().deposits.wood
				var location: Vector3 = GameplaySpace.resolve(tribe, source.position)
				tribe._focus = location
				tribe.camera_rig.update_camera()
				await _frames(2)
				var source_point: Vector2 = _exposed_world_point(location, 2.3)
				await _world_click(source_point, MOUSE_BUTTON_LEFT)
				await _frames(6)
				_expect(panel._resource_area.source_id == source.id and panel._resource_area.is_visible_in_tree(), "Source world click failed: " + context)
				_expect(str(source.remaining) in panel._resource_area._amount.text, "Source amount does not match live state: " + context)
				_expect(_physical_rect(panel._scroll).grow(1.0).encloses(_physical_rect(panel._resource_area._title)), "Source heading not scrolled into view: " + context + " title=" + str(_physical_rect(panel._resource_area._title)) + " scroll=" + str(_physical_rect(panel._scroll)))
				await _capture("matrix_" + context + "_source_open")
				await _click(panel._resource_area._add)
				_expect(tribe.resource_details(source.id).assigned == 1, "Add gatherer failed: " + context)
				await _capture("matrix_" + context + "_source")
				print("CONTROLS_ACTION: remove " + context)
				await _click(panel._resource_area._remove)
				print("CONTROLS_ACTION: removed " + context)
				_expect(tribe.resource_details(source.id).assigned == 0, "Remove gatherer failed: " + context + " " + JSON.stringify({"navigation_ready": tribe.navigation.is_ready(), "status": tribe.status, "metrics": tribe.last_order_metrics}))
				# A pure HUD/scroll click must never become a world order or selection.
				var before_ui: Dictionary = tribe.village().duplicate(true)
				var selection: Array = tribe.selected.duplicate()
				var zoom: float = tribe._zoom
				await _show_in_scroll(panel._scroll, panel._resource_area._amount)
				var point: Vector2 = panel._resource_area._amount.get_global_transform_with_canvas() * (panel._resource_area._amount.size * 0.5)
				await _world_click(point, MOUSE_BUTTON_RIGHT)
				var before_scroll: int = panel._scroll.scroll_vertical
				await _world_click(point, MOUSE_BUTTON_WHEEL_DOWN)
				var after_scroll_down: int = panel._scroll.scroll_vertical
				await _world_click(point, MOUSE_BUTTON_WHEEL_UP)
				_expect(before_scroll != after_scroll_down or panel._scroll.scroll_vertical != after_scroll_down, "Mouse wheel did not move the detail scroll: " + context)
				print("CONTROLS_ACTION: HUD checked " + context)
				_expect(tribe.village() == before_ui and tribe.selected == selection and tribe._zoom == zoom, "HUD click/wheel leaked into world: " + context)
				# Supply the focused build fixture like the existing preview test.
				# These goods are setup, not claimed production or transport evidence.
				tribe.village().tools = 1
				tribe.village().deposits.wood.remaining = 0
				tribe.village().deposits.stone.remaining = 0
				tribe.village().stock.wood = 16
				tribe.village().stock.stone = 16
				_expect(Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty(), "Invalid focused build fixture: " + context)
				tribe.camera_rig.focus_home()
				await _click(panel._residents.get_child(0))
				print("CONTROLS_ACTION: builder selected " + context)
				await _click(panel._buttons.hut)
				print("CONTROLS_ACTION: placing " + context)
				_expect(panel._top_bar.visible == false and tribe.placement == "hut", "Placement did not release the resource bar: " + context)
				var site: Vector3 = Vector3(5, 100.06, 5)
				tribe._focus = site
				tribe.camera_rig.update_camera()
				await _frames(3)
				await _world_click(tribe.camera.unproject_position(site), MOUSE_BUTTON_RIGHT)
				var project: Dictionary = tribe.village().project.duplicate(true)
				_expect(not project.is_empty() and tribe.placement.is_empty() and panel._top_bar.visible, "Mouse placement failed: " + context)
				if not project.is_empty():
					var picked: Vector3 = GameplaySpace.resolve(tribe, project.position)
					if not panel._collapsed: await _click(panel._collapse)
					await _world_click(_exposed_world_point(picked, 2.8), MOUSE_BUTTON_LEFT)
					await _frames(6)
					_expect(panel._tabs.get_current_tab_control() == panel._build_page and panel._construction.is_visible_in_tree(), "Construction world click failed: " + context)
					_expect(_physical_rect(panel._scroll).grow(1.0).encloses(_physical_rect(panel._construction._title)), "Construction heading not scrolled into view: " + context)
					_expect(tribe.village().project == project, "Inspecting construction mutated project: " + context)
					await _show_in_scroll(panel._scroll, panel._construction._details)
					_expect("6" in panel._construction._details.text and "3" in panel._construction._details.text, "Construction material readout failed: " + context)
					await _capture("matrix_" + context + "_construction")
					await _click(panel._construction._cancel)
					await _click(panel._construction._keep)
					_expect(tribe.village().project == project, "Keeping construction cancelled it: " + context)
					await _click(panel._construction._cancel)
					await _click(panel._construction._cancel)
					_expect(tribe.village().project.is_empty(), "Unstarted construction did not cancel: " + context)
				await _click(panel._buttons.wait)
				var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
				_expect(screen.encloses(_physical_rect(panel._hud)) and screen.encloses(_physical_rect(panel._top_bar)), "HUD outside screen: " + context)
				rows.append({"case": context, "passed": failures.size() == first_failure})
				tribe.set_physics_process(true)
				tribe.camera_rig.focus_home()
	if not "--matrix-one" in OS.get_cmdline_user_args():
		await _check_resource_transport()
	if not capture_dir.is_empty():
		var report := FileAccess.open(capture_dir.path_join("controls-matrix.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"cases": rows, "passed": failures.is_empty(), "failures": failures}, "\t"))
	print("TRIBAL_CONTROLS_MATRIX: " + JSON.stringify(rows))

func _check_resource_transport() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	root.content_scale_factor = 1.0
	root.get_node("LocaleManager")._apply("en")
	Engine.time_scale = 3.0
	tribe.village().deposits.wood.remaining = 24
	tribe.village().stock.wood = 0
	tribe.select_all()
	await _frames(3)
	# The last layout case cancelled a construction and requested production
	# navigation rebuilding. A gather click must wait until that rebuild ends.
	await _until(func() -> bool: return tribe.navigation.is_ready(), 600)
	_expect(tribe.navigation.is_ready(), "Transport fixture navigation did not become ready.")
	if not tribe.navigation.is_ready(): return
	await _click(tribe.panel._buttons.wood)
	await _until(func() -> bool: return _has_cargo(), 350)
	_expect(_has_cargo(), "Resource UI fixture never picked up real transport cargo.")
	# Hold genuine in-flight cargo while clicking +/-. This makes the command
	# safety check deterministic without replacing pickup/delivery by fake cargo.
	tribe.set_physics_process(false)
	var carriers: Array[Dictionary] = []
	for member: Dictionary in tribe.village().members:
		if not member.cargo.is_empty(): carriers.append(member.duplicate(true))
	tribe.panel.open_resource_area(tribe.village().deposits.wood.id)
	await _frames(6)
	await _click(tribe.panel._resource_area._remove)
	await _click(tribe.panel._resource_area._add)
	for member: Dictionary in carriers:
		var after: Dictionary = tribe.member_record(member.id)
		_expect(after.cargo == member.cargo and after.order == member.order and after.stage == member.stage
			and after.get("workplace_id", "") == member.get("workplace_id", "") and after.construction_id == member.construction_id,
			"Work-area +/- interrupted a real freight carrier: " + member.id)
	await _capture("transport_resource_assignment")
	tribe.set_physics_process(true)
	await _click(tribe.panel._speed_pause)
	var snapshot: Dictionary = tribe.village().duplicate(true)
	await _frames(8)
	_expect(paused and tribe.village() == snapshot, "Pause advanced an actual running transport.")
	await _capture("transport_paused")
	await _click(tribe.panel._speed_pause)
	await _until(func() -> bool: return int(tribe.village().stock.wood) > 0, 700)
	_expect(int(tribe.village().stock.wood) > 0, "Paused transport did not resume its real delivery.")
	_expect(Model.validate(tribe.village(), tribe.body(), state.campaign.data).is_empty(), "Resource UI damaged transport accounting.")
	await _capture("transport_resumed")

func _mouse_speed(index: int) -> void:
	await _click(tribe.panel._speed_selector)
	var popup: PopupMenu = tribe.panel._speed_selector.get_popup()
	await _frames(2)
	_expect(popup.visible, "Speed popup did not open with the mouse.")
	if not popup.visible: return
	var box: StyleBox = popup.get_theme_stylebox("panel")
	var top: float = box.get_content_margin(SIDE_TOP)
	var bottom: float = box.get_content_margin(SIDE_BOTTOM)
	var item_height: float = (float(popup.size.y) - top - bottom) / popup.item_count
	var point := Vector2(float(popup.size.x) * 0.5, top + (index + 0.5) * item_height)
	# Embedded popups receive pointer routing from their owning viewport.
	# Pushing directly into the popup skips that routing and cannot hover rows.
	await _world_click(Vector2(popup.position) + point, MOUSE_BUTTON_LEFT)
	await _frames(2)
	_expect(not popup.visible, "Mouse choice left the speed popup open.")

func _exposed_world_point(location: Vector3, height: float) -> Vector2:
	var panel: CanvasLayer = tribe.panel
	var map: CanvasLayer = get_first_node_in_group(&"minimap_hud")
	for fraction: float in [1.0, 0.75, 0.5, 0.25, 0.0]:
		var point: Vector2 = tribe.camera.unproject_position(location + GameplaySpace.up(tribe, location) * height * fraction)
		var factor: float = float(root.size.x) / root.get_visible_rect().size.x
		var physical: Vector2 = point * factor
		if not _physical_rect(panel._hud).has_point(physical) and not _physical_rect(panel._top_bar).has_point(physical) and not _physical_rect(map._panel).has_point(physical):
			return point
	_expect(false, "Fixture object has no exposed screen point: " + str(location))
	return tribe.camera.unproject_position(location)
