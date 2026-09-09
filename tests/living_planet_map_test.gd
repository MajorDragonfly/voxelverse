extends SceneTree
## The existing atlas follows the living sphere's real actor and save owner.
const World = preload("res://world/planet_lab/living_planet.gd")
const Store = preload("res://world/surface/living_planet_store.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	world = World.new()
	world.store_path = "user://integration-living-map.json"
	root.add_child(world)
	current_scene = world
	await _frames(4)
	var map: CanvasLayer = world.minimap.atlas_window
	map.tracker.update_exploration()
	_expect(not map.tracker.snapshot.is_empty() and map.tracker.atlas.known(world.walker.location()), "Living sphere did not reveal its actual actor location")
	if "--map-restart" in OS.get_cmdline_user_args():
		_expect(world.map_atlases.size() == 2, "Restart lost body atlases")
		_expect(Store.valid(world.snapshot()), "Restart produced invalid shared living save")
		await _finish()
		return
	var body: String = world.body_id
	var before: Dictionary = world.map_atlases.duplicate(true)
	await _key(KEY_M)
	_expect(map.is_open and paused and world.body_id == body, "M did not open the map without changing planets")
	map.zoom(1)
	map.fit_explored()
	await _frames(3)
	_expect(world.map_atlases == before, "Map navigation revealed unvisited terrain")
	await _key(KEY_ESCAPE)
	await _frames(3)
	_expect(not paused and not map.is_open, "Map did not release its own pause")
	_expect(world.save_lab(), "Living sphere with map cannot save")
	_expect(_change_body(), "Cannot visit second body")
	await _frames(3)
	map.tracker.update_exploration()
	_expect(world.map_atlases.size() == 2 and world.map_atlases.has(body), "Body switch lost first atlas")
	_expect(world.save_lab(), "Second body atlas cannot save")
	var stored: Dictionary = Store.read(world.store_path).data
	_expect(stored.schema == 3, "Map-bearing saves do not protect against pre-map readers")
	var future: Dictionary = stored.duplicate(true)
	future.map_atlases[body].schema = 99
	Atomic.write("user://map-future.json", future, false)
	Atomic.write("user://map-future.json.bak", stored, false)
	_expect(Store.read("user://map-future.json").error != OK and Store.write(stored, "user://map-future.json") != OK, "Future atlas was downgraded through older backup")
	var legacy: Dictionary = stored.duplicate(true)
	legacy.erase("map_atlases")
	legacy.schema = 2
	_expect(Store.valid(legacy), "Existing living save without atlas is no longer readable")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/living_planet_map_test.gd", "--", "--map-restart"], output, true)
	_expect(code == 0 and str(output).contains("LIVING_MAP_PASS") and not str(output).contains("SCRIPT ERROR"), "Fresh process map restoration failed: " + str(output))
	await _finish()

func _change_body() -> bool:
	world.next_body()
	return world.body_id == World.System.REAL_LANDABLE[1]

func _key(code: int) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _finish() -> void:
	paused = false
	world.queue_free()
	await _frames(3)
	print("LIVING_MAP_PASS" if failures.is_empty() else "LIVING_MAP_FAIL " + str(failures))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
