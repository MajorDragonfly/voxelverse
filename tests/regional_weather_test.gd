extends SceneTree
const Regional = preload("res://world/weather/regional_weather.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const RADIUS: float = 6371000.0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--regional-cold" in OS.get_cmdline_user_args():
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://regional_weather_restart.json"))
		var actual: Dictionary = Regional.sample("home", 15838, 875.25, fixture.address, RADIUS, fixture.climate)
		_expect(var_to_bytes(actual).hex_encode() == fixture.expected_bytes, "Regional weather changed in a fresh process.")
	else:
		await _contracts()
	for failure in failures: push_error(failure)
	print("REGIONAL_WEATHER: region diversity, cube edges, polar wind, dry/cold/vacuum climates, mild bounds, gusts, forecast and cold resume: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _contracts() -> void:
	var address: Dictionary = Cube.address("home", 0, 0.2, 0.3)
	var wet: Dictionary = {"moisture": 0.9, "temperature": 0.65}
	var samples: Array[float] = []
	for face in range(6):
		samples.append(Regional.sample("home", 15838, 875.25, Cube.address("home", face, 0.1, 0.3), RADIUS, wet).regional_seconds)
	_expect(samples.max() - samples.min() > 10.0, "Whole planet shares one identical front.")
	# Approach every cube edge from inside and outside; address() canonicalizes
	# the latter onto its neighbour. There must be no face-local weather seam.
	for face in range(6):
		for edge in [Vector2(1, 0.3), Vector2(-1, 0.3), Vector2(0.3, 1), Vector2(0.3, -1)]:
			var a: Dictionary = Cube.address("home", face, edge.x * (1.0 - 1e-9), edge.y * (1.0 - 1e-9))
			var b: Dictionary = Cube.address("home", face, edge.x * (1.0 + 1e-9), edge.y * (1.0 + 1e-9))
			var one: Dictionary = Regional.sample("home", 15838, 875.25, a, RADIUS, wet)
			var two: Dictionary = Regional.sample("home", 15838, 875.25, b, RADIUS, wet)
			for key in ["precipitation", "cloud_cover", "wind_mps", "wetness"]:
				_expect(absf(float(one[key]) - float(two[key])) < 0.0001, "Weather discontinuity at cube edge: " + key)
			_expect(Cube.vector(one.wind_velocity).distance_to(Cube.vector(two.wind_velocity)) < 0.0001, "Wind jumped at cube edge.")
	for face in [2, 3]:
		var pole: Dictionary = Regional.sample("home", 15838, 875.25, Cube.address("home", face, 0, 0), RADIUS, wet)
		_expect(Cube.vector(pole.wind_velocity).is_finite() and absf(Cube.vector(pole.wind_velocity).y) < 0.001, "Polar wind is not finite/tangent.")
	var rain_time: float = -1.0
	for clock in range(300, 1800, 30):
		if Regional.sample("home", 15838, float(clock), address, RADIUS, wet).precipitation > 0.05:
			rain_time = float(clock)
			break
	_expect(rain_time > 0.0, "No regional shower reachable.")
	var rain: Dictionary = Regional.sample("home", 15838, rain_time, address, RADIUS, wet)
	var snow: Dictionary = Regional.sample("home", 15838, rain_time, address, RADIUS, {"moisture": 0.9, "temperature": 0.05})
	var desert: Dictionary = Regional.sample("home", 15838, rain_time, address, RADIUS, {"moisture": 0.02, "temperature": 0.9})
	var vacuum: Dictionary = Regional.sample("home", 15838, rain_time, address, RADIUS, {"atmosphere": "none", "moisture": 1.0})
	_expect(rain.rain_intensity > 0.0 and rain.snow_intensity == 0.0, "Warm region failed to rain.")
	_expect(snow.snow_intensity > 0.0 and snow.rain_intensity == 0.0 and snow.wetness == 0.0, "Cold region failed to snow.")
	_expect(desert.precipitation == 0.0 and desert.cloud_cover < rain.cloud_cover, "Arid region got the wet-region shower.")
	_expect(vacuum.precipitation == 0.0 and vacuum.wind_mps == 0.0 and vacuum.cloud_cover == 0.0, "Weather present in a vacuum.")
	_expect(Regional.preview(vacuum, "snow").precipitation == 0.0, "Preview bypassed atmosphere absence.")
	for seed_value in [1, 2, 15838, 23757, 2147483647]:
		for clock in range(0, 36000, 137):
			var value: Dictionary = Regional.sample("home", seed_value, float(clock), address, RADIUS, wet)
			_expect(value.hazard_kind == "none" and value.hazard_intensity == 0.0 and value.wind_mps < 5.4 and value.precipitation <= 0.65, "Regional weather escaped peaceful bounds.")
			_expect(is_equal_approx(value.rain_intensity + value.snow_intensity, value.precipitation), "Precipitation split lost intensity.")
		_expect(Regional.sample("home", seed_value, 0.0, address, RADIUS, wet).precipitation == 0.0, "Regional weather spoiled the peaceful opening.")
	var old: Dictionary = Regional.sample("home", 15838, 360000.0, address, RADIUS, wet)
	var next: Dictionary = Regional.sample("home", 15838, 360000.016, address, RADIUS, wet)
	_expect(Cube.vector(old.wind_offset).distance_to(Cube.vector(next.wind_offset)) < 0.1, "Late-session gust teleported precipitation/clouds.")
	var forecast: Array[Dictionary] = Regional.forecast("home", 15838, 875.25, address, RADIUS, wet)
	_expect(forecast.size() == 3, "Forecast exceeded fixed budget.")
	for row in forecast:
		var future: Dictionary = Regional.sample("home", 15838, 875.25 + row.in_seconds, address, RADIUS, wet)
		_expect(future.condition == row.condition and future.precipitation == row.precipitation, "Forecast disagreed with future sample.")
	_expect(Regional.sample("other", 15838, 0, address, RADIUS).is_empty(), "Foreign-body location accepted.")
	_expect(Regional.sample("home", 15838, NAN, address, RADIUS).is_empty(), "Invalid clock accepted.")
	var invalid: Dictionary = Regional.sample("home", 15838, rain_time, address, RADIUS, {"moisture": NAN, "temperature": "bad"})
	_expect(is_finite(invalid.precipitation) and is_finite(invalid.snow_fraction), "Invalid optional climate escaped bounds.")
	var expected: Dictionary = Regional.sample("home", 15838, 875.25, address, RADIUS, wet)
	Regional.sample("away", 23757, 999.0, Cube.address("away", 3, 0.7, 0.4), RADIUS, wet)
	_expect(expected == Regional.sample("home", 15838, 875.25, address, RADIUS, wet), "Another body contaminated the home forecast.")
	var file := FileAccess.open("user://regional_weather_restart.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"address": address, "climate": wet, "expected_bytes": var_to_bytes(expected).hex_encode()}))
	file.close()
	var output: Array = []
	var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/regional_weather_test.gd", "--", "--regional-cold"], output, true)
	_expect(status == 0, "Regional cold resume failed: " + str(output))

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
