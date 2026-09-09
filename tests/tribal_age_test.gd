extends SceneTree
const Model = preload("res://world/tribe/tribe_state.gd")
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

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args: PackedStringArray = OS.get_cmdline_user_args()
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
	await _frames(15)
	_expect(state.current_phase == 1 and tribe.is_active(), "Confirmation did not activate the playable tribe: " + saves.last_error)
	if not tribe.is_active():
		await _cleanup()
		_finish()
		return
	_expect(absf(float(tribe.village()["members"][0]["hunger"]) - 61.0) < 0.5, "Transition did not preserve the original creature hunger ratio.")
	_expect(not player.is_physics_processing() and tribe.camera.current and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Control did not switch from creature to group overview.")
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
	await _capture("02_group")
	# M6's expanded economy controls can cover the companions. Use its real
	# collapse button before clicking/dragging in the world, like the player.
	await _click(tribe.panel._collapse)
	await _frames(3)
	var identity: String = str(tribe.village()["members"][0]["id"])
	var screen_point: Vector2 = tribe.camera.unproject_position(player.global_position + Vector3.UP)
	await _world_click(screen_point, MOUSE_BUTTON_LEFT)
	_expect(tribe.selected.size() == 1 and tribe.selected[0] == identity, "World click did not select the original creature.")
	var companion_id: String = str(tribe.village()["members"][1]["id"])
	await _world_click(tribe.camera.unproject_position(tribe.actors[companion_id].global_position + Vector3.UP), MOUSE_BUTTON_LEFT, true)
	_expect(tribe.selected.size() == 2, "Shift-click did not add the companion to the group.")
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
	await _click(tribe.panel._collapse)
	await _frames(3)
	await _click(tribe.panel._buttons["wood"])
	await _until(func() -> bool: return _has_cargo(), 350)
	_expect(_has_cargo(), "Gatherers did not pick up material at a real deposit.")
	await _capture("03_transport")
	var stock_before_stop: Dictionary = tribe.village()["stock"].duplicate(true)
	await _click(tribe.panel._buttons["wait"])
	await _frames(10)
	_expect(_has_cargo() and tribe.village()["stock"] == stock_before_stop, "Stop discarded cargo or credited it without a delivery.")
	await _click(tribe.panel._buttons["wood"])
	var at_save: Dictionary = tribe.village().duplicate(true)
	_expect(saves.save_now() and saves.load_now(), "Could not reload a running delivery.")
	await _frames(8)
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
	await _until(func() -> bool: return int(tribe.village()["huts"]) == 1, 1600)
	_expect(int(tribe.village()["huts"]) == 1, "Workers did not finish the first shelter.")
	await _click(tribe.panel._buttons["feed"])
	await _until(func() -> bool: return int(tribe.village()["meals"]) >= 3, 350)
	_expect(int(tribe.village()["meals"]) >= 3, "Feeding did not consume village food.")
	await _click(tribe.panel._buttons["hut"])
	await _world_click(tribe.camera.unproject_position(Vector3(9, 100.06, 1)), MOUSE_BUTTON_RIGHT)
	await _until(func() -> bool: return int(tribe.village()["huts"]) == 2, 1600)
	_expect(int(tribe.village()["huts"]) == 2, "The village could not expand to four sleeping places.")
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
	future["game_state"]["campaign"]["bodies"][str(state.get_world_seed())]["tribe"]["schema"] = Model.SCHEMA + 1
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
	await _frames(15)
	if tribe.is_active():
		await _click(tribe.panel._residents.get_child(1))
		_expect(tribe.selected == [str(tribe.village()["members"][1]["id"])], "New campaign's resident buttons still select the former campaign's IDs.")
	else:
		_expect(false, "Second campaign cannot enter its own tribe.")
	await _cleanup()
	_finish()

func _world_click(position: Vector2, button: int, shift: bool = false) -> void:
	for pressed_value in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = button
		event.pressed = pressed_value
		event.shift_pressed = shift
		root.push_input(event, true)
	await process_frame

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

func _click(button: Button) -> void:
	if tribe != null and tribe.panel._scroll.is_ancestor_of(button):
		tribe.panel._scroll.ensure_control_visible(button)
		await _frames(3)
	_expect(button != null and button.is_visible_in_tree(), "Required button is absent: " + (str(button.name) if button != null else "null"))
	if button == null:
		return
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(not image.is_empty(), "Empty viewport capture.")
	image.save_png(capture_dir.path_join(label + ".png"))

func _cleanup() -> void:
	scene.queue_free()
	await _frames(4)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_age", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _check_scrolled_actions() -> void:
	for button: Button in tribe.panel._buttons.values():
		tribe.panel._tabs.current_tab = button.get_parent().get_parent().get_index()
		await _frames(3)
		if not button.is_visible_in_tree():
			continue # Milk pickup appears only when a delivery exists.
		tribe.panel._scroll.ensure_control_visible(button)
		await _frames(3)
		var rect: Rect2 = button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
		var scroll_rect: Rect2 = tribe.panel._scroll.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, tribe.panel._scroll.size)
		# Integer scrolling and canvas scaling can round an edge by less than one viewport pixel.
		_expect(button.is_visible_in_tree() and root.get_visible_rect().encloses(rect) and scroll_rect.grow(1.0).encloses(rect), "Action outside viewport or clipped: %s rect=%s scroll=%s" % [button.name, rect, scroll_rect])
