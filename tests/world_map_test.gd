extends SceneTree
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Surface = preload("res://core/map/surface_map_projection.gd")
const Chart = preload("res://core/map/atlas_projection.gd")
const Source = preload("res://ui/world_map/world_map_source.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []
var scene: Node3D
var player: Node3D
var map: CanvasLayer
var state: Node
var saves: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://world_map_test.json"
	state.start_world_with_seed(15838)
	state.set_process(false)
	_test_model()
	_test_planet()
	await process_frame
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	player = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	player.fall_acceleration = 0
	scene.add_child(player)
	var nest := Node3D.new()
	scene.add_child(nest)
	nest.position = Vector3(2, 100, 5)
	nest.add_to_group(&"player_nest")
	await _frames(5)
	map = get_first_node_in_group(&"world_map")
	_expect(map != null, "Player minimap did not install a world map.")
	if map == null: await _finish(); return
	var tracker: Node = map.tracker
	tracker.update_exploration()
	_expect(tracker.atlas.known(Surface.plane_address(state.get_current_body().id, player.position)), "Standing ground was not revealed.")
	_expect(tracker.atlas.data.places.size() == 1, "Own physical nest was not remembered.")
	var progression := root.get_node("ProgressionService")
	var friend: Dictionary = _friend("1:0")
	_expect(progression._encounters.put(friend), "Valid ally fixture rejected.")
	var remote: Dictionary = _friend("500:500")
	_expect(progression._encounters.put(remote), "Remote ally fixture rejected.")
	tracker._places_dirty = true
	tracker.update_exploration()
	_expect(tracker.atlas.data.places.size() == 2, "Map exposed a friend's unvisited habitat or lost a known one.")
	var before: Dictionary = state.campaign.export_state()
	var before_progression: Dictionary = progression.export_state()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var original_mouse: int = Input.mouse_mode
	await _key(KEY_M)
	_expect(map.is_open and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "M did not open the paused atlas.")
	_expect(not player.find_child("MinimapHUD", true, false).visible, "Minimap covered the large map.")
	var skills: Node = player.find_child("PlayerProgression", true, false)
	_expect(not skills.open_panel(), "Another book opened over the map.")
	await _key(KEY_SPACE)
	_expect(paused and map.is_open, "Space released the map's pause.")
	var initial: float = map.range_m
	await _key(KEY_MINUS)
	_expect(map.range_m > initial, "Keyboard atlas zoom failed.")
	map._canvas.cancel_drag()
	map._pan_pixels(Vector2(1200, -1000))
	map.fit_explored()
	_expect(state.campaign.export_state() == before and progression.export_state() == before_progression, "Panning or zooming disclosed ground or awarded progress.")
	_expect(map._sample(Vector2(500000, 500000)) == preload("res://ui/frontend/menu_style.gd").INK, "Unknown ground leaked its real color.")
	await _layouts()
	map._show_friends = false
	map._refresh_places()
	_expect(map._canvas.places.size() == 1, "Friend filter hid own nest or retained the ally.")
	map._show_friends = true
	map._refresh_places()
	map.select_place(friend.object_id + ":habitat")
	_expect(map._selected == friend.object_id + ":habitat" and map._detail.text.contains("befreundeten"), "Known-place selection failed.")
	await _key(KEY_ESCAPE)
	await _frames(2)
	_expect(not map.is_open and not paused and Input.mouse_mode == original_mouse, "Escape did not restore the previous control mode: open=%s paused=%s mouse=%s previous=%s closing=%s" % [map.is_open, paused, Input.mouse_mode, map._previous_mouse, map._closing])
	# Movement reveals real visited ground; neither rendering nor a map pan does.
	player.position.x = 240
	tracker.update_exploration()
	_expect(tracker.atlas.known(Surface.plane_address(state.get_current_body().id, player.position)), "Moving to new ground did not explore it.")
	_expect(tracker.atlas.known(Surface.plane_address(state.get_current_body().id, Vector3.ZERO)), "Travel forgot previously explored ground.")
	var exported: Dictionary = tracker.atlas.data.duplicate(true)
	_expect(saves.save_now(), "Exploration did not save with the campaign.")
	state.campaign.data.bodies[str(state.get_world_seed())].erase("exploration_atlas")
	_expect(saves.load_now(), "Exploration save did not load.")
	await _frames(2)
	tracker.update_exploration()
	# Compare the JSON contract; Godot arrays distinguish int rows from decoded float rows.
	_expect(JSON.parse_string(JSON.stringify(tracker.atlas.data)) == JSON.parse_string(JSON.stringify(exported)), "Save/load changed the fog or places.")
	# Restart in a second engine, using the same actual save path.
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/support/world_map_restart.gd"], output, true)
	_expect(code == 0 and not str(output).contains("ERROR:"), "Fresh process did not restore the map: " + str(output).right(500))
	# Friendship remains authoritative, even after the creature unloads or dies.
	friend.dead = true
	friend.health_ratio = 0.0
	progression._encounters.put(friend)
	_expect(Source.visible_places(tracker.atlas.data, self).size() == 1, "Dead ally retained a friendly marker.")
	var saved_text: String = FileAccess.get_file_as_string(saves.save_path)
	var future: Dictionary = JSON.parse_string(saved_text)
	future.game_state.campaign.bodies[str(state.get_world_seed())].exploration_atlas.schema = 2
	var file := FileAccess.open(saves.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(future)); file.close()
	_expect(not saves.load_now() and not saves.save_now(), "Future map schema was silently downgraded.")
	file = FileAccess.open(saves.save_path, FileAccess.WRITE)
	file.store_string(saved_text); file.close()
	_expect(saves.load_now(), "Supported map could not be restored after future schema protection.")
	state.start_world_with_seed(63352)
	tracker.update_exploration()
	_expect(not tracker.atlas.data.places.has(friend.object_id + ":habitat"), "New world inherited another body's friend.")
	_expect(not tracker.atlas.known(Surface.plane_address(state.get_current_body().id, Vector3.ZERO)), "New world inherited the old body's fog.")
	await _finish()

func _test_model() -> void:
	var atlas := Atlas.new()
	_expect(atlas.bind(Atlas.create("test", "legacy_plane_v9")), "Atlas rejected a clean body record.")
	var a: Dictionary = Surface.plane_address("test", Vector3(-1, 0, -1))
	_expect(atlas.reveal(a) and atlas.known(a), "Negative tile boundary was not revealed.")
	var before: Dictionary = atlas.data.duplicate(true)
	_expect(not atlas.reveal(a) and atlas.data == before, "Repeated visit duplicated fog state.")
	_expect(not atlas.known(Surface.plane_address("other", Vector3.ZERO)), "Fog leaked between bodies.")
	_expect(not atlas.known(Surface.plane_address("test", Vector3(160, 0, 0))), "Remote ground was revealed.")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(atlas.data))
	_expect(Atlas.validate(decoded, "test").is_empty(), "JSON changed bit masks or identity.")
	decoded.tiles.values()[0][0] = -1
	_expect(not Atlas.validate(decoded, "test").is_empty(), "Corrupt fog bits were accepted.")
	var legacy: Dictionary = Atlas.create("test", "legacy_plane_v9")
	legacy.schema = 2
	_expect(Atlas.newer(legacy), "Future map schema was not detected.")

func _test_planet() -> void:
	var atlas := Atlas.new()
	atlas.bind(Atlas.create("earth", Cube.MODE, 6371000))
	var seam: Dictionary = Cube.address("earth", 0, 0.999999, 0.2)
	var local := Surface.new()
	local.configure(seam, 6371000)
	atlas.reveal(seam)
	_expect(atlas.known(local.address_at(Vector2(12, 0))), "Fog has a cube-face seam.")
	var pole: Dictionary = Cube.address("earth", 2, 0, 0)
	atlas.reveal(pole)
	_expect(atlas.known(pole) and atlas.known(seam), "Pole visit lost earlier sphere exploration.")
	var chart := Chart.new()
	chart.configure(seam, 6371000)
	for address in [seam, pole, Cube.address("earth", 5, 0.999999, 0.2)]:
		var point: Vector2 = chart.project(address)
		var restored: Dictionary = chart.address_at(point)
		var tangent := Surface.new()
		tangent.configure(address, 6371000)
		_expect(tangent.project(restored).length() < 2.0, "Large planet atlas lost position precision.")

func _friend(cell: String) -> Dictionary:
	var body: Dictionary = state.get_current_body()
	var region_id: String = state.campaign.region_id(body.id, Vector2i.ZERO)
	var identity := {"object_id": state.campaign.object_id(region_id, "habitat:" + cell), "species_id": state.campaign.species_id(body.id, 729), "body_id": body.id, "region_id": region_id, "habitat_cell": cell, "species_seed": 729}
	var friend: Dictionary = root.get_node("ProgressionService").get_creature_encounter(identity, "grazer", 144)
	friend.relation = "ally"
	friend.trust = 100.0
	return friend

func _layouts() -> void:
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600), Vector2i(2560, 1080)]:
		for scale in [1.0, 1.5]:
			root.size = size
			root.get_node("DisplaySettings").ui_scale = scale
			map._layout()
			await _frames(4)
			map._layout()
			await _frames(2)
			var rect: Rect2 = _physical(map._panel)
			_expect(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "Atlas escaped screen: " + str(size) + " scale " + str(scale) + " " + str(rect))
			_expect(_physical(map._canvas).size.y >= 150 and _physical(map._canvas).size.x >= 180, "Map became unreadable.")
			if map._small:
				map._show_list = true
				map._layout()
				await _frames(2)
				_expect(map._sidebar.visible and not map._canvas.visible, "Small atlas did not switch to its place list.")
				map._show_list = false
				map._layout()
	root.size = Vector2i(1280, 720)
	root.get_node("DisplaySettings").ui_scale = 1.0
	map._layout()

func _physical(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	var factor: float = float(root.size.x) / root.get_visible_rect().size.x
	return Rect2(transform.origin * factor, control.size * transform.get_scale() * factor)

func _key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _frames(count: int) -> void:
	for index in range(count): await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	if is_instance_valid(scene): scene.queue_free()
	await _frames(3)
	_expect(not paused and get_nodes_in_group(&"world_map").is_empty(), "Map leaked pause or nodes after scene exit.")
	for failure in failures: push_error(failure)
	print("WORLD_MAP_OK" if failures.is_empty() else "WORLD_MAP_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
