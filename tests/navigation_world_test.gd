extends SceneTree
## Public spherical campaign, real map controls, transactional save, cold process
## and actual A-B-A body travel. Native captures use the same foreground UI.
const Navigation = preload("res://core/map/navigation_state.gd")
const Surface = preload("res://core/map/surface_map_projection.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const EXPECTED: String = "user://navigation-expected.json"
var failures: Array[String] = []
var checks: int = 0
var state: Node
var saves: Node
var flow: Node
var map: CanvasLayer
var capture_dir: String = ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	flow = root.get_node("SessionFlow")
	saves.autosave_enabled = false
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	root.position = Vector2i.ZERO
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	# Native UI review retains the actual campaign, sampler and physics while
	# suppressing its unrelated 3D backdrop on a software graphics host.
	if "--ui-only" in args and DisplayServer.get_name() != "headless": root.disable_3d = true
	if "--restart" in args:
		await _restart()
		await _finish()
		return
	var fixture: bool = "--ui-fixture" in args
	if fixture:
		_expect("--ui-only" in args, "A UI fixture cannot replace the full campaign/travel acceptance")
		if "--ui-only" not in args: await _finish(); return
		await _setup_ui_fixture()
	else:
		change_scene_to_file(flow.TITLE_SCENE)
		await scene_changed
		flow.new_game("Navigation exploration", 15838)
		print("NAVIGATION_STAGE public_load")
		await _until(func() -> bool: return not flow.loading, 150000)
		_expect(not flow.loading and current_scene.scene_file_path == flow.SPHERE_SCENE, "Public spherical campaign did not load")
		if flow.loading or current_scene.get("player") == null: await _finish(); return
	saves.autosave_enabled = false
	map = get_first_node_in_group(&"world_map")
	_expect(map != null, "Public campaign has no world map")
	if map == null: await _finish(); return
	map.tracker.update_exploration()
	var body: Dictionary = state.get_current_body_record()
	var origin_id: String = body.id
	var original_seed: int = state.get_world_seed()
	var original_system: int = state.system_seed
	var fog: Dictionary = map.tracker.atlas.data.duplicate(true)
	var progression: Dictionary = root.get_node("ProgressionService").export_state()
	await _key(KEY_M)
	_expect(map.is_open and paused, "World map did not own pause")
	if not map.is_open: await _finish(); return
	root.disable_3d = DisplayServer.get_name() != "headless"
	await _frames(5)
	await _until(func() -> bool: return not map._request_pending, 2000)
	await _mouse(_rect(map._canvas).get_center(), MOUSE_BUTTON_RIGHT)
	_expect(Navigation.view(body).get("waypoints", {}).size() == 1 and map._show_navigation, "Right-click did not create a saved waypoint on explored ground")
	if not body.has(Navigation.FIELD): await _finish(); return
	print("NAVIGATION_STAGE waypoint_created")
	fog = map.tracker.atlas.data.duplicate(true)
	var id: String = Navigation.view(body).waypoints.keys()[0]
	_expect(Navigation.view(body).target == {"kind": "waypoint", "id": id}, "New waypoint is not tracked")
	await _reveal_control(map._navigation._name)
	await _click(map._navigation._name)
	map._navigation._name.select_all()
	await _type("camp m")
	await _key(KEY_ENTER)
	_expect(Navigation.view(body).waypoints[id].name == "camp m" and map.is_open, "Typing M or submitting a waypoint name lost text or closed the map")
	map.select_waypoint(id)
	_expect(map._detail.text == "camp m" and map._info_detail.text == "camp m", "Waypoint details classified a personal pin as a species-owned place")
	_expect(not Input.is_physical_key_pressed(KEY_A), "Text input left a movement key held")
	var before_failed: Dictionary = Navigation.view(body).duplicate(true)
	var slot_before: String = FileAccess.get_file_as_string(saves.save_path)
	# The central writer's actual busy gate rejects a second write. The complete
	# pin transaction must roll back without touching either committed slot.
	await _reveal_control(map._navigation._name)
	await _click(map._navigation._name)
	saves._saving = true
	map._navigation._name.select_all()
	await _type("unsaved change")
	await _reveal_control(map._navigation._rename)
	# The live animal/map refresh is also a normal user pause before clicking.
	# Losing LineEdit focus must preserve the unsaved draft and its action.
	map._refresh_description()
	_expect(map._navigation._name.text == "unsaved change" and not map._navigation._rename.disabled, "Periodic map refresh discarded an unfocused waypoint draft")
	await _click(map._navigation._rename)
	saves._saving = false
	_expect(Navigation.view(body) == before_failed and FileAccess.get_file_as_string(saves.save_path) == slot_before, "Rejected save retained an uncommitted waypoint rename")
	_expect(map._navigation._message.visible and not map._navigation._message.text.begins_with("NAV_"), "Save rejection has no readable feedback")
	map._navigation._name.release_focus()
	# Selecting the saved pin acknowledges the write error before checking its
	# description in both locales; an error message is not a place classification.
	map.select_waypoint(id)
	await _layouts()
	print("NAVIGATION_STAGE layout_matrix_complete")
	root.get_node("LocaleManager")._apply("de")
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	map._show_navigation = false
	map.focus_player()
	map._layout()
	await _frames(5)
	# A chart pan is not an explorer and cannot manufacture a pin in the fog.
	var player_address: Dictionary = map.tracker.snapshot.explorers[0]
	var unknown: Dictionary
	if body.surface_mode == Cube.MODE:
		var direction: Array = Cube.direction(player_address.face, player_address.u, player_address.v)
		unknown = Cube.from_direction(body.id, [-direction[0], -direction[1], -direction[2]])
	else: unknown = Surface.plane_address(body.id, Vector3(1000000, 0, 1000000))
	map.projection.center = map.projection.project(unknown)
	map._request()
	await _frames(5)
	await _mouse(_rect(map._canvas).get_center(), MOUSE_BUTTON_RIGHT)
	_expect(Navigation.view(body).waypoints.size() == 1 and map._navigation_message == "NAV_UNKNOWN", "Unknown ground accepted a waypoint")
	_expect(map.tracker.atlas.data == fog and root.get_node("ProgressionService").export_state() == progression, "Waypoint UI revealed fog, catalog data or progress")
	map.focus_player()
	var own_nests: Array = map._places.filter(func(point: Dictionary) -> bool: return point.kind == "nest" and point.own)
	_expect(not own_nests.is_empty(), "Physical own nest is missing from the atlas")
	if own_nests.is_empty(): await _finish(); return
	var nest_id: String = own_nests[0].id
	map.select_place(nest_id)
	await _click(map._target_button)
	_expect(Navigation.view(body).target == {"kind": "place", "id": nest_id}, "Known nest cannot be selected as navigation target")
	map.select_waypoint(id)
	await _click(map._target_button)
	_expect(Navigation.view(body).target == {"kind": "waypoint", "id": id}, "Saved waypoint cannot replace known-place target")
	await _key(KEY_ESCAPE)
	await _frames(3)
	_expect(not paused and not map.is_open, "Closing map did not restore play")
	var hud: CanvasLayer = get_first_node_in_group(&"minimap_hud")
	hud._update_snapshot()
	_expect(hud._navigation_label.visible and hud._navigation_label.text.contains("camp m") and not hud._map.navigation.is_empty(), "Minimap lost active target name/direction")
	var small := Surface.new()
	small.configure(player_address, float(body.get("surface_context", {}).get("radius", 0.0)))
	var distant: Dictionary = small.address_at(Vector2(400, 0))
	map.tracker.atlas.reveal(distant)
	await _key(KEY_M)
	map.add_waypoint(distant)
	var distant_id: String = Navigation.view(body).target.id
	map.close_map()
	await _frames(3)
	hud._update_snapshot()
	var live_address: Dictionary = map.player.location() if body.surface_mode == Cube.MODE else Surface.plane_address(body.id, map.player.global_position)
	var expected_distance: float = _distance(live_address, distant, float(body.get("surface_context", {}).get("radius", 0.0)))
	var shown_distance: String = preload("res://ui/world_map/atlas_presentation.gd").distance_text(expected_distance)
	print("NAVIGATION_DISTANCE ", JSON.stringify({"expected_m": expected_distance, "shown": hud._navigation_label.text}))
	_expect(hud._navigation_label.visible and hud._navigation_label.text.contains(shown_distance) and not hud._map.navigation.arrived,
		"Geodesic guidance differs from the player's physical position: %s expected %s" % [hud._navigation_label.text, shown_distance])
	_expect(not hud._map.map_rect().has_point(hud._map.screen_point(hud._map.navigation.position)), "Offscreen destination did not exercise edge guidance")
	await _capture("navigation-target-minimap")
	# A group snapshot has a freely pannable camera address and independent
	# physical explorers. Prefer the selected resident even if another is at target.
	var guidance: Dictionary = preload("res://ui/world_map/world_map_source.gd").campaign_snapshot(map.player, self)
	guidance.group_view = true
	guidance.explorers = [distant, live_address]
	guidance.markers = [{"kind": "resident", "address": distant, "selected": false},
		{"kind": "resident", "address": live_address, "selected": true}]
	guidance.address = distant
	hud.snapshot_provider = func() -> Dictionary: return guidance
	hud._update_snapshot()
	_expect(hud._navigation_label.text.contains(shown_distance) and not hud._map.navigation.arrived,
		"Panning a group camera onto the target reported arrival for the distant selected resident")
	_expect(hud._map.navigation.origin.is_equal_approx(hud.projection.project(live_address)) and not hud._map.navigation.origin.is_equal_approx(hud._map.position_m),
		"Guidance line uses camera focus instead of the selected physical resident")
	await _capture("navigation-tribe-camera-pan")
	guidance.address = small.address_at(Vector2(-200, 100))
	hud._update_snapshot()
	_expect(hud._navigation_label.text.contains(shown_distance) and not hud._map.navigation.arrived,
		"Camera-only movement changed physical destination distance")
	guidance.markers = []
	guidance.explorers = [live_address]
	hud._update_snapshot()
	_expect(hud._navigation_label.text.contains(shown_distance), "Unselected group lost physical explorer guidance")
	guidance.explorers = []
	hud._update_snapshot()
	_expect(not hud._navigation_label.visible and hud._map.navigation.is_empty(), "Camera-only snapshot invented a physical explorer")
	hud.snapshot_provider = Callable()
	hud._update_snapshot()
	await _key(KEY_M)
	map.select_waypoint(distant_id)
	map._show_navigation = true
	map._layout()
	await _frames(3)
	await _reveal_control(map._navigation._remove)
	await _click(map._navigation._remove)
	_expect(not Navigation.view(body).waypoints.has(distant_id) and Navigation.view(body).target.is_empty(), "Deleting tracked waypoint left a target behind")
	map.select_waypoint(id)
	map.track_selected()
	map.close_map()
	await _frames(3)
	if "--ui-only" not in args: root.disable_3d = false
	_expect(saves.save_now(), "Navigation campaign save failed: " + saves.last_error)
	var expected := {"path": saves.save_path, "body_id": origin_id, "navigation": Navigation.view(body).duplicate(true)}
	print("NAVIGATION_STAGE saved_restart")
	_expect(Atomic.write(EXPECTED, expected, false) == OK, "Cannot record cold process expectation")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/navigation_world_test.gd", "--", "--restart"], output, true)
	print("NAVIGATION_COLD_PROCESS ", str(output))
	_expect(code == 0 and str(output).contains("NAVIGATION_RESTART_PASSED") and not str(output).contains("ERROR:"), "Fresh process did not restore navigation or protect future records")
	if "--ui-only" not in args:
		print("NAVIGATION_STAGE body_departure")
		flow.toggle_pause()
		var traveled: bool = await flow.travel_to_planet(23757, 0, original_system)
		await _until(func() -> bool: return not flow.loading, 150000)
		_expect(traveled and not flow.loading and state.active_body_id != origin_id, "Actual departure failed")
		if traveled and not flow.loading:
			var destination: Dictionary = state.get_current_body_record()
			_expect(not destination.has(Navigation.FIELD), "Another body inherited navigation pins")
			_expect(Navigation.view(state.campaign.body_record(origin_id)) == expected.navigation, "Departure changed source navigation")
			flow.toggle_pause()
			print("NAVIGATION_STAGE body_return")
			var returned: bool = await flow.travel_to_planet(original_seed, 0, original_system)
			await _until(func() -> bool: return not flow.loading, 150000)
			_expect(returned and not flow.loading and state.active_body_id == origin_id, "Actual return failed")
			_expect(Navigation.view(state.get_current_body_record()) == expected.navigation, "A-B-A travel lost waypoint identities, names or target")
			var returned_hud: CanvasLayer = get_first_node_in_group(&"minimap_hud")
			if returned_hud != null:
				returned_hud.atlas_window.tracker.update_exploration()
				returned_hud._update_snapshot()
				_expect(returned_hud._navigation_label.visible, "Returned campaign did not resume target guidance")
	await _finish()

func _setup_ui_fixture() -> void:
	print("NAVIGATION_STAGE production_ui_fixture")
	saves._loaded_once = true
	saves.save_path = "user://navigation-ui-fixture.json"
	state.start_world_with_seed(15838)
	state.set_process(false)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	player.fall_acceleration = 0
	scene.add_child(player)
	var nest := Node3D.new()
	scene.add_child(nest)
	nest.position = player.position
	nest.add_to_group(&"player_nest")
	await _frames(6)

func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	saves.save_path = expected.path
	saves._loaded_once = true
	_expect(saves.load_now(), "Cold navigation save cannot load: " + saves.last_error)
	_expect(state.active_body_id == expected.body_id and Navigation.view(state.get_current_body_record()) == expected.navigation, "Cold load changed navigation data")
	var bytes: String = FileAccess.get_file_as_string(saves.save_path)
	var future: Dictionary = Atomic.parse_dictionary(bytes)
	future.game_state.campaign.bodies[expected.body_id].map_navigation.schema = Navigation.SCHEMA + 1
	_expect(Atomic.write(saves.save_path, future, false) == OK, "Cannot create protected-version fixture")
	var future_bytes: String = FileAccess.get_file_as_string(saves.save_path)
	_expect(not saves.load_now() and not saves.save_now() and FileAccess.get_file_as_string(saves.save_path) == future_bytes, "Future navigation was replaced by a backup or downgraded")
	var restored := FileAccess.open(saves.save_path, FileAccess.WRITE)
	restored.store_string(bytes)
	restored.close()
	_expect(saves.load_now(), "Supported navigation cannot recover after future guard")
	if failures.is_empty(): print("NAVIGATION_RESTART_PASSED")

func _layouts() -> void:
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.5]:
			for locale: String in ["de", "en"]:
				root.size = size
				root.position = Vector2i.ZERO
				root.get_node("DisplaySettings").ui_scale = scale
				root.get_node("LocaleManager")._apply(locale)
				map._show_navigation = true
				map._show_info = false
				map._layout()
				await _frames(6)
				_expect(Rect2(Vector2.ZERO, Vector2(size)).encloses(_rect(map._panel)), "Navigation panel escaped screen: %s/%s/%s" % [size, scale, locale])
				_expect(not map._navigation._title.text.begins_with("NAV_") and Navigation.view(state.get_current_body_record()).waypoints.values()[0].name == "camp m", "Language change translated user waypoint or left a key")
				_expect(map._detail.text == "camp m" and map._info_detail.text == "camp m", "Waypoint details gained a species classification after locale/scale change")
				await _reveal_control(map._navigation._name)
				_expect(_rect(map._navigation_scroll).grow(2).encloses(_rect(map._navigation._name)), "Waypoint name cannot be reached at compact size")
				await _reveal_control(map._navigation._remove)
				_expect(_rect(map._navigation_scroll).grow(2).encloses(_rect(map._navigation._remove)), "Waypoint delete action cannot be reached at compact size")
				await _capture("navigation-%s-%dx%d-%d" % [locale, size.x, size.y, roundi(scale * 100)])

func _reveal_control(control: Control) -> void:
	map._navigation_scroll.ensure_control_visible(control)
	control.grab_focus()
	await _frames(4)

func _rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	var factor: float = float(root.size.x) / root.get_visible_rect().size.x
	return Rect2(transform.origin * factor, control.size * transform.get_scale() * factor)

func _click(control: Control) -> void:
	var received: Array[bool] = [false]
	var receipt: Callable = func() -> void: received[0] = true
	if control is Button:
		_expect(not control.disabled, "Requested UI action is disabled: " + str(control.name))
		control.pressed.connect(receipt, CONNECT_ONE_SHOT)
	await _mouse(_rect(control).get_center(), MOUSE_BUTTON_LEFT)
	if control is Button:
		_expect(received[0], "Actual mouse click did not activate " + str(control.name))
		if control.pressed.is_connected(receipt): control.pressed.disconnect(receipt)
	elif control is LineEdit:
		_expect(control.has_focus(), "Actual mouse click did not focus " + str(control.name))

func _mouse(point: Vector2, button: int) -> void:
	if DisplayServer.get_name() != "headless":
		_native(["focus", str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, root.get_window_id()))])
		_native(["move", str(roundi(point.x + root.position.x)), str(roundi(point.y + root.position.y))])
		await _frames(2)
		var native_button: int = 3 if button == MOUSE_BUTTON_RIGHT else 2 if button == MOUSE_BUTTON_MIDDLE else button
		for down in ["1", "0"]:
			_native(["button", str(native_button), down])
			await _frames(2)
	else:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point + Vector2(root.position)
		Input.parse_input_event(motion)
		await process_frame
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point + Vector2(root.position)
			event.button_index = button
			event.pressed = down
			event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if down else 0
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)

func _type(value: String) -> void:
	for letter in value:
		if DisplayServer.get_name() != "headless": _native(["tap", "space" if letter == " " else letter])
		else:
			for down in [true, false]:
				var event := InputEventKey.new()
				event.keycode = letter.to_upper().unicode_at(0)
				event.physical_keycode = event.keycode
				event.unicode = letter.unicode_at(0) if down else 0
				event.pressed = down
				Input.parse_input_event(event)
				await process_frame
		await _frames(2)

func _distance(from: Dictionary, destination: Dictionary, radius: float) -> float:
	if radius <= 0.0:
		return Vector2(float(from.position[0]) - destination.position[0], float(from.position[2]) - destination.position[2]).length()
	# Independent double-scalar great-circle check, not the HUD projection.
	var a: Array = Cube.direction(from.face, from.u, from.v)
	var b: Array = Cube.direction(destination.face, destination.u, destination.v)
	var cross: Array = [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
	var sine: float = sqrt(cross[0] * cross[0] + cross[1] * cross[1] + cross[2] * cross[2])
	return atan2(sine, a[0] * b[0] + a[1] * b[1] + a[2] * b[2]) * radius

func _key(code: int) -> void:
	if DisplayServer.get_name() != "headless":
		_native(["focus", str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, root.get_window_id()))])
		_native(["tap", {KEY_M: "m", KEY_ENTER: "Return", KEY_ESCAPE: "Escape"}[code]])
	else:
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)

func _native(arguments: Array) -> void:
	var output: Array = []
	var code: int = OS.execute("python3", [ProjectSettings.globalize_path("res://docs/evidence/int30-11-world-map/native_input.py")] + arguments, output, true)
	_expect(code == 0, "Native input failed: " + str(output))

func _capture(title: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join(title + ".png")) == OK, "Cannot save actual navigation view")

func _frames(count: int) -> void:
	for index in range(count): await process_frame

func _until(predicate: Callable, timeout_ms: int) -> void:
	var end: int = Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < end: await process_frame

func _expect(okay: bool, message: String) -> void:
	checks += 1
	if not okay:
		failures.append(message)
		print("NAVIGATION_CHECK_FAILED ", message)

func _finish() -> void:
	for failure in failures: push_error(failure)
	print("NAVIGATION_WORLD_PASSED checks=%d" % checks if failures.is_empty() else "NAVIGATION_WORLD_FAILED checks=%d" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
