extends SceneTree
const Storm = preload("res://world/weather/r33_sandstorm.gd")
const Receipt = preload("res://world/weather/r33_exposure_state.gd")
const Runtime = preload("res://world/weather/r33_exposure_runtime.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const Climate = preload("res://world/weather/planet_climate.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Forecast = preload("res://world/weather/forecast_panel.gd")
const View = preload("res://world/weather/weather_view.gd")
var failures: Array[String] = []
var checks: int = 0
const RADIUS: float = 6371000.0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--cold-extreme" in OS.get_cmdline_user_args():
		_cold()
	else:
		_model()
		await _physical()
		_persistence()
		_work_hold()
	for failure: String in failures: push_error(failure)
	print("R33_07_EXTREME: ", checks, " checks; normal plan/forecast, physical protection, real health, cap/idempotence, work hold, saved receipt/cold/future: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

static func context(id: String) -> Dictionary:
	return {"moisture": 0.08, "temperature": 0.8, "biome": "desert", "biome_weights": {"desert": 0.8},
		"water": false, "blocked": false, Climate.FIELD: Climate.make_reference(id, "arid")}

static func site(id: String, seed_value: int) -> Dictionary:
	for face: int in range(6):
		for y: int in range(-15, 16):
			for x: int in range(-15, 16):
				var address: Dictionary = Cube.address(id, face, x / 16.0, y / 16.0)
				var d: Array = Cube.direction(address.face, address.u, address.v)
				if Storm.region(id, seed_value, [d[0] * RADIUS, d[1] * RADIUS, d[2] * RADIUS]) > 0.95: return address
	return {}

static func sample(id: String, seed_value: int, clock: float, address: Dictionary) -> Dictionary:
	return Regional.sample(id, seed_value, clock, address, RADIUS, context(id))

func _model() -> void:
	var id: String = "extreme-fixture"
	var address: Dictionary = site(id, 15838)
	check(not address.is_empty(), "Missing sand region fixture.")
	var cycle: Dictionary = Storm.schedule(id, 15838)
	var start: float = 0.0
	var identity: String = ""
	for phase: String in ["calm", "warning", "rising", "peak", "falling"]:
		var clock: float = start + float(cycle[phase]) * 0.5
		var value: Dictionary = sample(id, 15838, clock, address)
		check(value.get("storm_phase") == phase and not value.preview, "Not normal phase " + phase)
		check(value.storm_warning == (phase == "warning"), "Lead differs from actual plan.")
		check(identity.is_empty() or value.storm_event_id == identity, "Changing event identity.")
		identity = value.storm_event_id
		if phase in ["calm", "warning"]: check(value.hazard_intensity == 0.0, "Early hazard.")
		if phase == "peak": check(value.condition == "sandstorm" and value.hazard_intensity > 0.95 and value.visibility_m < 1500, "Missing native sand fields.")
		for entry: Dictionary in Regional.forecast(id, 15838, clock, address, RADIUS, context(id)):
			var actual: Dictionary = sample(id, 15838, clock + entry.in_seconds, address)
			for key: String in ["hazard_kind", "hazard_intensity", "storm_event_id", "storm_phase", "storm_intensity", "extreme_storm_schema"]:
				check(entry.get(key) == actual.get(key), "Forecast mismatch " + key)
		start += float(cycle[phase])
		for loops: int in [0, 2000, 200000]:
			var a: Dictionary = sample(id, 15838, start + cycle.period * loops - 0.001, address)
			var b: Dictionary = sample(id, 15838, start + cycle.period * loops + 0.001, address)
			for key: String in ["storm_intensity", "wind_mps", "visibility_m"]:
				check(absf(float(a[key]) - float(b[key])) < 0.05, "Boundary/wrap " + key)
			for axis: int in [0, 2]: check(absf(a.wind_offset[axis] - b.wind_offset[axis]) < 0.08, "Unbounded long-time drift.")
	var peak: float = cycle.calm + cycle.warning + cycle.rising + 30.0
	for guard: String in ["home", "missing", "future", "binding", "vacuum", "frozen", "volcanic", "wet", "water", "blocked", "forest", "cold"]:
		var terrain: Dictionary = context(id)
		match guard:
			"home": terrain[Climate.FIELD] = Climate.make_reference(id, "earth_temperate", true)
			"missing": terrain.erase(Climate.FIELD)
			"future": terrain[Climate.FIELD].revision = 999
			"binding": terrain[Climate.FIELD].body_id = "foreign"
			"vacuum": terrain.atmosphere = "none"
			"frozen", "volcanic": terrain[Climate.FIELD].profile_id = guard
			"wet": terrain.moisture = 0.7
			"water": terrain.water = true
			"blocked": terrain.blocked = true
			"forest": terrain.biome = "forest"; terrain.biome_weights = {"forest": 1.0}
			"cold": terrain.temperature = 0.1
		var value: Dictionary = Regional.sample(id, 15838, peak, address, RADIUS, terrain)
		check(not value.has("extreme_storm_schema") and float(value.get("hazard_intensity", 0.0)) == 0.0, "Guard " + guard)
	var normal: Dictionary = sample(id, 15838, peak, address)
	for name: String in ["sandstorm", "rain", "snow"]:
		var diagnostic: Dictionary = Regional.preview(normal, name)
		check(diagnostic.preview and not diagnostic.has("extreme_storm_schema") and not diagnostic.has("normal_storm_schema")
			and diagnostic.hazard_intensity == 0.0 and not Forecast._is_upcoming_storm(diagnostic), "Diagnostic leaked hazard.")
	var body := {"id": id, "seed": 15838}
	var record: Dictionary = Receipt.attach(body, "actor", peak)
	var a: Dictionary = record.duplicate(true)
	for i: int in range(1, 201): Receipt.consume(record, body, peak + i * 0.5, 1.0, false, 1.0)
	check(is_equal_approx(record.spent_ratio, Receipt.MAX_DAMAGE_RATIO), "No finite event cap.")
	check(Receipt.consume(record, body, peak + 100.0, 1.0, false, 1.0) == 0.0, "Same-clock double harm.")
	check(Receipt.consume(record, body, peak + 100.5, 1.0, false, 1.0) == 0.0, "Cap reset by repeat.")
	var spent: float = record.spent_ratio
	Receipt.attach(body, "actor", peak + 101.0)
	check(record.spent_ratio == spent, "Arrival/restart reset cap.")
	for factor: float in [0.0, 1.0, 2.0, 4.0]:
		var value: Dictionary = a.duplicate(true)
		var total: float = 0.0
		for i: int in range(1, 61): total += Receipt.consume(value, body, peak + factor * i / 60.0, 1.0, false, 1.0)
		check(is_equal_approx(total, Receipt.RATE_RATIO * factor), "Wrong campaign-speed exposure.")
	check(Receipt.consume(a, body, peak + 0.1, 1.0, false, 0.2) == 0.0, "Sand killed a low-health actor.")
	check(not Runtime.suspends_work(normal, {"protected": true}, "wood") and Runtime.suspends_work(normal, {"protected": false}, "wood")
		and not Runtime.suspends_work(normal, {"protected": false}, "move"), "Irreversible or invented work hold.")
	var outside: int = 0
	var d: Array = Cube.direction(address.face, address.u, address.v)
	for offset: int in range(0, 12800, 100):
		if Storm.region(id, 15838, [d[0] * RADIUS + offset, d[1] * RADIUS, d[2] * RADIUS]) == 0.0: outside += 1
	check(outside > 20, "No outside region.")
	for face: int in range(6):
		var one: Dictionary = Cube.address(id, face, 1.0 - 1e-10, 0.3)
		var two: Dictionary = Cube.address(id, face, 1.0 + 1e-10, 0.3)
		check(absf(sample(id, 15838, peak, one).get("hazard_intensity", 0.0) - sample(id, 15838, peak, two).get("hazard_intensity", 0.0)) < 0.0001, "Cube seam.")

func _physical() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	scene.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(0, 200, 0)
	player.defense_rating = 0.0
	player.recovery.reset()
	var normal: Dictionary = sample("extreme-fixture", 15838, Storm.schedule("extreme-fixture", 15838).calm + 240.0, site("extreme-fixture", 15838))
	normal.wind_velocity = [1.0, 0.0, 0.0]
	await physics_frame
	await physics_frame
	check(not Runtime.protection(player, normal).protected, "Open actor sheltered by its own collider.")
	var roof: StaticBody3D = _box(scene, Vector3(0, 202, 0), Vector3(6, 0.4, 6))
	await physics_frame
	await physics_frame
	check(not Runtime.protection(player, normal).protected, "Open-sided canopy blocks horizontal sand.")
	var wall: StaticBody3D = _box(scene, Vector3(-2, 200, 0), Vector3(0.4, 4, 6))
	await physics_frame
	await physics_frame
	check(Runtime.protection(player, normal).protected, "Real roof/windbreak not protecting actor.")
	wall.collision_layer = 0
	await physics_frame
	await physics_frame
	check(not Runtime.protection(player, normal).protected, "Disabled wall still gives protection.")
	wall.collision_layer = 1
	var body := {"id": "extreme-fixture", "seed": 15838}
	var campaign := {"elapsed_seconds": normal.elapsed_seconds, "player_object_id": "actor"}
	var runtime := Runtime.new()
	runtime.tick(scene, body, campaign, player, normal, false, false)
	var before: float = player.current_health
	campaign.elapsed_seconds += 0.5
	runtime.tick(scene, body, campaign, player, normal, false, false)
	check(player.current_health == before, "Physical shelter damaged real player.")
	wall.collision_layer = 0
	roof.collision_layer = 0
	await physics_frame
	await physics_frame
	campaign.elapsed_seconds += 0.5
	runtime.tick(scene, body, campaign, player, normal, false, false)
	check(player.current_health < before and runtime.last_result.damage > 0.0, "No real receive_damage consequence.")
	before = player.current_health
	runtime.tick(scene, body, campaign, player, normal, false, false)
	check(player.current_health == before, "Double damage in one clock.")
	for guard: String in ["preview", "tribe"]:
		campaign.elapsed_seconds += 0.5
		runtime.tick(scene, body, campaign, player, normal, guard == "preview", guard == "tribe")
		check(player.current_health == before, "Guard harmed player: " + guard)
	var view := View.new()
	scene.add_child(view)
	view.configure(15838)
	view.position_at(player.global_position, Vector3.UP)
	view._floors.fill(-5.0)
	view.present(normal, false, false)
	check(view._rain.multimesh.visible_instance_count > 300, "Normal dust absent.")
	var particle: Dictionary = view.particle_submission(0)
	check(particle.color == Color("bfa16d"), "Normal sand uses rain color.")
	check(view.get_child_count() == 2 and view._rain.multimesh.instance_count == 384, "Grew draw pool.")
	scene.queue_free()
	await process_frame
	current_scene = null

func _persistence() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	var path: String = saves.create_slot("Extreme receipt", 15838, Cube.MODE)
	check(not path.is_empty(), "Cannot create actual slot.")
	var body: Dictionary = state.get_current_body_record()
	state.campaign.data.elapsed_seconds = 3000.0
	var value: Dictionary = Receipt.attach(body, state.campaign.data.player_object_id, 2999.5)
	Receipt.consume(value, body, 3000.0, 1.0, false, 1.0)
	check(saves.save_now(), "Actual receipt save failed: " + saves.last_error)
	var expected: String = JSON.stringify(value, "", true)
	FileAccess.open("user://extreme_expected.json", FileAccess.WRITE).store_string(JSON.stringify({"path": path, "expected": expected}))
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--cold-extreme"], output, true)
	check(code == 0 and "ERROR:" not in str(output) and "SCRIPT ERROR" not in str(output), "Fresh process: " + str(output))
	var original: String = FileAccess.get_file_as_string(path)
	var future: Dictionary = JSON.parse_string(original)
	future.game_state.campaign.bodies[body.id][Receipt.FIELD].schema = 999
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(future))
	check(not saves.load_now(), "Future exposure fell back to backup.")
	check(not saves.save_now() and FileAccess.get_file_as_string(path) == JSON.stringify(future), "Future save overwritten.")
	FileAccess.open(path, FileAccess.WRITE).store_string(original)
	check(saves.load_now(), "Supported receipt cannot reload.")
	check(receipt_matches(state.get_current_body_record()[Receipt.FIELD], JSON.parse_string(expected)), "Load changed dose/event.")
	var restored: Dictionary = state.get_current_body_record()
	Receipt.attach(restored, state.campaign.data.player_object_id, 3000.0)
	check(Receipt.consume(restored[Receipt.FIELD], restored, 3000.0, 1.0, false, 1.0) == 0.0, "Restart duplicated exposure.")

func _work_hold() -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/support/r33_07_work_hold.gd"], output, true)
	check(code == 0 and "ERROR:" not in str(output) and "SCRIPT ERROR" not in str(output), "Actual work hold: " + str(output))

func _cold() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://extreme_expected.json"))
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	saves.session_active = true
	saves.save_path = fixture.path
	check(saves.load_now(), "Cold actual slot load failed.")
	var state: Node = root.get_node("GameState")
	var body: Dictionary = state.get_current_body_record()
	check(receipt_matches(body[Receipt.FIELD], JSON.parse_string(fixture.expected)), "Cold dose/event changed.")
	var spent: float = body[Receipt.FIELD].spent_ratio
	Receipt.attach(body, state.campaign.data.player_object_id, state.campaign.data.elapsed_seconds)
	check(body[Receipt.FIELD].spent_ratio == spent, "Cold arrival reset budget.")
	check(Receipt.consume(body[Receipt.FIELD], body, state.campaign.data.elapsed_seconds, 1.0, false, 1.0) == 0.0, "Cold load harmed actor.")

func _box(parent: Node3D, point: Vector3, size: Vector3) -> StaticBody3D:
	var item := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	item.add_child(collision)
	parent.add_child(item)
	item.position = point
	return item

static func receipt_matches(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.keys().size() != expected.keys().size(): return false
	for key: String in ["schema", "body_id", "actor_id", "event_id"]:
		if actual.get(key) != expected.get(key): return false
	for key: String in ["cursor", "spent_ratio"]:
		if absf(float(actual.get(key, -1.0)) - float(expected.get(key, -2.0))) > 1e-10: return false
	return true

func check(value: bool, message: String) -> void:
	checks += 1
	if not value and not failures.has(message): failures.append(message)
