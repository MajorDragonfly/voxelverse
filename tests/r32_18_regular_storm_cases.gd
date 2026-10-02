extends SceneTree
const Regional = preload("res://world/weather/regional_weather.gd")
const Storm = preload("res://world/weather/r32_regular_storm.gd")
const Climate = preload("res://world/weather/planet_climate.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Forecast = preload("res://world/weather/forecast_panel.gd")
const Model = preload("res://world/weather/weather_model.gd")
const RADIUS: float = 6371000.0
const SAVE: String = "user://r32_storm_save.json"
var failures: Array[String] = []
var checks: int = 0

class PlayerStub extends Node:
	var inspection_mode_enabled: bool = false

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--r32-storm-cold" in OS.get_cmdline_user_args():
		_cold_restore()
	else:
		_model()
		await _ui()
		_persistence()
	for failure in failures: push_error(failure)
	print("R32_18_STORM: ", checks, " checks; normal warning/entry/decay, rain/diagnostic guards, bounded region/drift, pause, actual save and cold restart: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

static func site(body_id: String, seed_value: int) -> Dictionary:
	# Search an explicit fixture location; no production weather/clock override.
	for face in range(6):
		for y in range(-15, 16):
			for x in range(-15, 16):
				var address: Dictionary = Cube.address(body_id, face, x / 16.0, y / 16.0)
				var d: Array = Cube.direction(address.face, address.u, address.v)
				if Storm.region(body_id, seed_value, [d[0] * RADIUS, d[1] * RADIUS, d[2] * RADIUS]) > 0.95: return address
	return {}

static func context(body_id: String) -> Dictionary:
	return {"temperature": 0.8, "moisture": 0.95, Climate.FIELD: Climate.make_reference(body_id, "earth_temperate")}

static func sample(body_id: String, seed_value: int, clock: float, address: Dictionary) -> Dictionary:
	return Regional.sample(body_id, seed_value, clock, address, RADIUS, context(body_id))

func _model() -> void:
	var body: String = "r32-storm-fixture"
	var address: Dictionary = site(body, 15838)
	_expect(not address.is_empty(), "No finite storm region fixture.")
	if address.is_empty(): return
	var cycle: Dictionary = Storm.schedule(body, 15838)
	var start: float = 0.0
	var previous_event: String = ""
	for phase: String in ["calm", "warning", "rising", "peak", "falling"]:
		var clock: float = start + float(cycle[phase]) * 0.5
		var snapshot: Dictionary = sample(body, 15838, clock, address)
		_expect(snapshot.get("storm_phase") == phase, "Wrong regular phase " + phase)
		_expect(snapshot.get("storm_warning") == (phase == "warning"), "Warning not limited to true lead phase.")
		_expect(not snapshot.preview and snapshot.hazard_kind == "none" and snapshot.hazard_intensity == 0.0, "Regular rain front became diagnostic or dangerous.")
		_expect(previous_event.is_empty() or previous_event == snapshot.storm_event_id, "One storm produced multiple event identities.")
		previous_event = snapshot.storm_event_id
		if phase in ["calm", "warning"]: _expect(snapshot.storm_intensity == 0.0, "Storm entered before lead ended.")
		if phase == "peak": _expect(snapshot.condition == "rainstorm" and snapshot.precipitation > 0.85, "Actual rainstorm did not enter.")
		var before: Dictionary = snapshot.duplicate(true)
		var values: Array = Regional.forecast(body, 15838, clock, address, RADIUS, context(body))
		_expect(snapshot == before, "Forecast mutated current weather.")
		for entry: Dictionary in values:
			var actual: Dictionary = sample(body, 15838, clock + entry.in_seconds, address)
			for key: String in ["condition", "precipitation", "wind_mps", "storm_event_id", "storm_phase", "storm_intensity"]:
				_expect(entry.get(key) == actual.get(key), "Future differs from actual at " + phase + ":" + key)
		start += float(cycle[phase])
		for loop: int in [0, 2000, 200000]:
			var a: Dictionary = sample(body, 15838, start + cycle.period * loop - 0.001, address)
			var b: Dictionary = sample(body, 15838, start + cycle.period * loop + 0.001, address)
			for key: String in ["storm_intensity", "wind_mps", "cloud_cover", "precipitation", "visibility_m", "wetness"]:
				_expect(absf(float(a[key]) - float(b[key])) < 0.02, "Phase/wrap discontinuity: " + key)
			for axis: int in [0, 2]:
				_expect(absf(a.wind_offset[axis] - b.wind_offset[axis]) < 0.06, "Long clock particle jump.")
	var peak_time: float = cycle.calm + cycle.warning + cycle.rising + 30.0
	for guard: String in ["home", "missing", "missing_protection", "vacuum", "arid", "frozen", "volcanic", "airless", "dry", "cold", "future", "body_binding"]:
		var climate: Dictionary = context(body)
		match guard:
			"home": climate[Climate.FIELD].home_protected = true
			"missing": climate.erase(Climate.FIELD)
			"missing_protection": climate[Climate.FIELD].erase("home_protected")
			"vacuum": climate.atmosphere = "none"
			"arid", "frozen", "volcanic", "airless": climate[Climate.FIELD].profile_id = guard
			"dry": climate.moisture = 0.1
			"cold": climate.temperature = 0.2
			"future": climate[Climate.FIELD].revision = 999
			"body_binding": climate[Climate.FIELD].body_id = "other"
		var guarded: Dictionary = Regional.sample(body, 15838, peak_time, address, RADIUS, climate)
		_expect(not guarded.has("normal_storm_schema"), "Guard bypass: " + guard)
	for unsupported: String in ["arid_extreme", "volcanic_extreme", "frozen_extreme"]:
		_expect(Model.sample(body, 15838, peak_time, unsupported).is_empty(), "Unreleased extreme activated.")
	var normal: Dictionary = sample(body, 15838, peak_time, address)
	var rain_preview: Dictionary = Regional.preview(normal, "rain")
	_expect(rain_preview.preview and not rain_preview.has("normal_storm_schema") and not Forecast._is_upcoming_storm(rain_preview), "Diagnostic rain retained normal warning identity.")
	var other: Dictionary = site("other", 15838)
	var a: Dictionary = sample(body, 15838, peak_time, address)
	sample("other", 15838, peak_time, other)
	_expect(a == sample(body, 15838, peak_time, address), "A-B-A retained another planet.")
	_expect(Storm.schedule(body, 15838) != Storm.schedule("other", 15838), "Schedule ignored body ID.")
	# Region compactness and smooth nearest-cell boundary, independent of origin.
	var direction: Array = Cube.direction(address.face, address.u, address.v)
	var point: Array = [direction[0] * RADIUS, direction[1] * RADIUS, direction[2] * RADIUS]
	var zero_regions: int = 0
	var previous_strength: float = Storm.region(body, 15838, point)
	for distance: int in range(100, 12801, 100):
		var strength: float = Storm.region(body, 15838, [point[0] + distance, point[1], point[2]])
		if strength == 0.0: zero_regions += 1
		_expect(absf(strength - previous_strength) < 0.13, "Hard storm region/cell seam.")
		previous_strength = strength
	_expect(zero_regions > 20, "Regular storm support has no clear outside regions.")
	for face in range(6):
		var one: Dictionary = Cube.address(body, face, 1.0 - 1e-10, 0.3)
		var two: Dictionary = Cube.address(body, face, 1.0 + 1e-10, 0.3)
		var left: Dictionary = sample(body, 15838, peak_time, one)
		var right: Dictionary = sample(body, 15838, peak_time, two)
		_expect(absf(left.precipitation - right.precipitation) < 0.0001, "Storm cube seam.")
		one.height = 12000.0
		_expect(left == sample(body, 15838, peak_time, one), "Altitude moved the storm region.")
	for clock: int in range(0, int(cycle.period * 2.0), 13):
		var value: Dictionary = sample(body, 15838, clock, address)
		_expect(value.wind_mps >= 0.0 and value.wind_mps < 9.4 and value.precipitation <= 0.9 and value.storm_intensity <= 1.0, "Storm escaped finite bounds.")

func _ui() -> void:
	var body: String = "r32-storm-fixture"
	var address: Dictionary = site(body, 15838)
	var cycle: Dictionary = Storm.schedule(body, 15838)
	var player := PlayerStub.new()
	root.add_child(player)
	var panel := Forecast.new()
	root.add_child(panel)
	for locale: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(locale)
		var transitions: int = 0
		var previous: bool = false
		for clock: int in range(int(cycle.calm) - 4, int(cycle.period) + 4):
			var snapshot: Dictionary = sample(body, 15838, clock, address)
			panel.present(snapshot, Regional.forecast(body, 15838, clock, address, RADIUS, context(body)), player)
			if panel._warning.visible and not previous: transitions += 1
			previous = panel._warning.visible
			_expect(panel._warning.visible == bool(snapshot.storm_warning), "UI alert differs from exact normal lead.")
			if panel._warning.visible: _expect("in 0 " not in panel._warning.text, "Upcoming storm rounded to zero minutes.")
		_expect(transitions == 1, "Warning flashed or retriggered in one storm.")
	var clock: float = cycle.calm + 30.0
	var warning: Dictionary = sample(body, 15838, clock, address)
	panel.present(warning, Regional.forecast(body, 15838, clock, address, RADIUS, context(body)), player)
	paused = true
	for frame in range(3): await process_frame
	_expect(not panel._panel.visible and panel._snapshot == warning, "Paused UI advanced weather or covered the modal.")
	paused = false
	await process_frame
	_expect(panel._warning.visible, "Resume lost warning.")
	panel.present(Regional.preview(warning, "rain"), [], player)
	_expect(not panel._panel.visible, "Diagnostic rain manufactured normal warning.")
	panel.present({}, [], null)
	_expect(not panel._panel.visible, "Owner teardown retained warning.")
	player.queue_free()
	panel.queue_free()
	await process_frame

func _persistence() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	saves.session_active = true
	saves.save_path = SAVE
	var actor := PlayerStub.new()
	root.add_child(actor)
	actor.add_to_group(&"player")
	actor.set_physics_process(true)
	state.start_world_with_seed(15838)
	var home: String = state.active_body_id
	var body: Dictionary = state.campaign.ensure_body(23757, 15838)
	state.campaign.body_record(body.id).weather_climate = Climate.make_reference(body.id, "earth_temperate")
	_expect(state.activate_body(body.id, 15838, 1, false), "Could not activate unprotected climate fixture.")
	# Compare the exact JSON-saved address, not extra pre-save float digits.
	var address: Dictionary = JSON.parse_string(JSON.stringify(site(body.id, body.seed)))
	var cycle: Dictionary = Storm.schedule(body.id, body.seed)
	var times: Array = [cycle.calm + 30.0, cycle.calm + cycle.warning + cycle.rising + 30.0]
	for clock: float in times:
		state.campaign.data.elapsed_seconds = clock
		state.set_simulation_speed(0.0)
		var expected: Dictionary = sample(body.id, body.seed, clock, address)
		_expect(saves.save_now(), "Real storm checkpoint failed: " + saves.last_error)
		var saved_bytes: String = FileAccess.get_file_as_string(SAVE)
		_expect("storm_event_id" not in saved_bytes and "normal_storm_schema" not in saved_bytes, "Derived event became a second save state.")
		var file := FileAccess.open("user://r32_storm_expected.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"address": address, "expected": JSON.stringify(expected, "", true)}))
		file.close()
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--r32-storm-cold"], output, true)
		_expect(code == 0 and "ERROR:" not in str(output) and "SCRIPT ERROR" not in str(output), "Cold storm restore failed: " + str(output))
		state.campaign.data.elapsed_seconds += 999.0
		_expect(saves.load_now(), "Actual slot reload failed.")
		_expect(sample(body.id, body.seed, state.campaign.data.elapsed_seconds, address) == expected, "Save/load moved warning or event phase.")
		var before: float = state.campaign.data.elapsed_seconds
		state._process(1.0)
		_expect(state.campaign.data.elapsed_seconds == before, "Speed zero advanced campaign storm.")
		state.set_simulation_speed(1.0)
		state._process(1.0)
		_expect(state.campaign.data.elapsed_seconds == before + 1.0, "Normal source did not follow the active campaign clock.")
		state.set_simulation_speed(0.0)
	_expect(state.activate_body(home, 15838, 0, false), "Home return failed.")
	var protected: Dictionary = state.get_current_body_record()
	var protected_weather: Dictionary = Regional.sample(home, protected.seed, times[1], Cube.address(home, 0, 0, 0), RADIUS,
		{"temperature": 0.8, "moisture": 0.95, Climate.FIELD: protected.weather_climate})
	_expect(not protected_weather.has("normal_storm_schema"), "A-B-home retained away storm.")
	actor.free()

func _cold_restore() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	saves.session_active = true
	saves.save_path = SAVE
	_expect(saves.load_now(), "Fresh process failed to load actual slot.")
	var state: Node = root.get_node("GameState")
	var body: Dictionary = state.get_current_body_record()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://r32_storm_expected.json"))
	var actual: Dictionary = sample(body.id, body.seed, state.campaign.data.elapsed_seconds, fixture.address)
	if JSON.stringify(actual, "", true) != fixture.expected:
		var previous: Dictionary = JSON.parse_string(fixture.expected)
		for key in actual:
			if actual[key] != previous.get(key): print("COLD_DIFF ", key, ": ", actual[key], " vs ", previous.get(key))
	_expect(JSON.stringify(actual, "", true) == fixture.expected, "Fresh-process weather identity/phase differs.")

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value and not failures.has(message): failures.append(message)
