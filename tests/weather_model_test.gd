extends SceneTree
const Weather = preload("res://world/weather/weather_model.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--weather-cold" in OS.get_cmdline_user_args():
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://weather_restart.json"))
		_expect(var_to_bytes(Weather.sample(fixture.body_id, int(fixture.seed), float(fixture.clock))).hex_encode() == fixture.expected_bytes, "Cold process changed derived weather.")
	else:
		for seed_value in [1, 2, 15838, 23757, 63352, 2147483647]:
			var first: Dictionary = Weather.sample("home", seed_value, 0.0)
			_expect(first.condition == "clear" and first.precipitation == 0.0, "New game did not start peacefully.")
			for clock in range(0, 36000, 17):
				var state: Dictionary = Weather.sample("home", seed_value, float(clock))
				_expect(state.hazard_kind == "none" and state.hazard_intensity == 0.0 and state.wind_mps <= 4.8 and state.precipitation <= 0.65, "Home weather became hazardous.")
				_expect(state == Weather.sample("home", seed_value, float(clock)), "Identical save time changed weather.")
			var duration: float = 210.0 + float(posmod(seed_value, 4)) * 30.0
			for boundary in range(1, 15):
				var before: Dictionary = Weather.sample("home", seed_value, duration * boundary - 0.001)
				var after: Dictionary = Weather.sample("home", seed_value, duration * boundary + 0.001)
				for key in ["precipitation", "wind_mps", "cloud_cover", "wetness"]:
					_expect(absf(float(before[key]) - float(after[key])) < 0.001, "Weather snapped at a front boundary: " + key)
			_expect(Weather.sample("home", seed_value, duration * 2 + 50).precipitation > 0.0, "First shower not reachable.")
		var a: Dictionary = Weather.sample("a", 15838, 795.25)
		Weather.sample("b", 23757, 1800.0)
		_expect(a == Weather.sample("a", 15838, 795.25), "A-B-A sampling retained another body state.")
		_expect(Weather.sample("", 1, 0).is_empty() and Weather.sample("a", 1, NAN).is_empty(), "Invalid context accepted.")
		for climate in ["arid_extreme", "volcanic_extreme", "frozen_extreme", "unknown"]:
			_expect(Weather.sample("home", 1, 9999, climate).is_empty(), "Unimplemented extreme climate activated.")
		var catalog: Dictionary = Weather.climate_catalog()
		catalog.earth_temperate.hazards.append("firestorm")
		_expect(Weather.climate_catalog().earth_temperate.hazards.is_empty(), "Consumer mutated climate catalog.")
		var file := FileAccess.open("user://weather_restart.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"body_id": "a", "seed": 15838, "clock": 795.25, "expected_bytes": var_to_bytes(a).hex_encode()}))
		file.close()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/weather_model_test.gd", "--", "--weather-cold"], output, true)
		_expect(status == 0, "Cold-process weather resume failed: " + str(output))
	for failure in failures: push_error(failure)
	print("WEATHER_MODEL: deterministic fronts, gentle home, continuous transitions, body isolation, cold resume and inactive extremes: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
