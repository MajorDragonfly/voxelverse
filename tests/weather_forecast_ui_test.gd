extends SceneTree
const Forecast = preload("res://world/weather/forecast_panel.gd")
const Notice = preload("res://world/weather/storm_preview_notice.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")
var failures: Array[String] = []
var captures: String = ""

class PlayerStub extends Node:
	var inspection_mode_enabled: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args: captures = args[args.find("--capture") + 1]
	var language_before: String = TranslationServer.get_locale()
	var stage := Node.new()
	root.add_child(stage)
	if not captures.is_empty():
		var background := ColorRect.new()
		background.color = Color("19313b")
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(background)
	var player := PlayerStub.new()
	stage.add_child(player)
	var panel := Forecast.new()
	stage.add_child(panel)
	var notice := Notice.new()
	stage.add_child(notice)
	var weather: Dictionary = Regional.sample("forecast-a", 15838, 580.0,
		Cube.address("forecast-a", 2, 0.2, 0.3), 6371000.0)
	var values: Array[Dictionary] = Regional.forecast("forecast-a", 15838, 580.0,
		Cube.address("forecast-a", 2, 0.2, 0.3), 6371000.0)
	_expect(values.size() == 3, "Model did not return three local forecast windows.")
	var original: Array[Dictionary] = values.duplicate(true)
	panel.present(weather, values, player)
	await process_frame
	await process_frame
	_expect(panel._segments.size() == 4 and absf(panel._day_bar.value - Atmosphere.day_progress(580.0) * 100.0) < 0.05,
		"Day/weather timeline does not read the supplied campaign snapshot.")
	_expect(not panel._warning.visible, "Normal forecast displayed a storm warning.")
	for entry: Dictionary in values:
		_expect(not entry.get("preview", true) and entry.get("hazard_kind", "missing") == "none",
			"The normal forecast lost its source/benign hazard metadata.")
	var later: Dictionary = weather.duplicate(true)
	later.elapsed_seconds += 360.0
	panel.present(later, values, player)
	await process_frame
	_expect(absf(panel._day_bar.value - Atmosphere.day_progress(940.0) * 100.0) < 0.05,
		"Day marker did not advance with campaign time.")
	panel.present(weather, values, player)
	for language: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(language)
		for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			await process_frame
			await process_frame
			_expect(panel._panel.visible, "Forecast missing in gameplay.")
			_expect(("Wetter" if language == "de" else "Weather") in panel._title.text,
				"Forecast title did not follow the selected language.")
			_expect(("Tag" if language == "de" else "Day") in panel._day.text and ":" in panel._day.text,
				"Day clock is untranslated or lacks a time.")
			for index in range(3):
				_expect("WEATHER_" not in panel._rows[index].text and str(index + 1) in panel._rows[index].text,
					"Forecast row missing or untranslated.")
			var bounds: Rect2 = panel._panel.get_global_rect()
			_expect(root.get_visible_rect().encloses(bounds), "Forecast left the viewport.")
			for label: Label in panel._rows:
				_expect(label.get_line_count() == label.get_visible_line_count(), "Forecast text clipped.")
			if not captures.is_empty(): await _capture("forecast-%dx%d-%s.png" % [size.x, size.y, language])
		_expect(values == original, "Presentation changed the model's read-only forecast.")
		# This is only the future-source presentation port. Normal revision-1
		# climates do not schedule storms; the live source is checked separately.
		var coming: Array[Dictionary] = values.duplicate(true)
		coming[1].condition = "sandstorm"
		panel.present(weather, coming, player)
		_expect(panel._warning.visible and ("Sturm naht" if language == "de" else "Storm approaching") in panel._warning.text,
			"The future-source storm presentation port has no visible warning.")
		coming[1].preview = true
		panel.present(weather, coming, player)
		_expect(not panel._warning.visible, "A diagnostic forecast entry manufactured a normal storm warning.")
		coming[1].preview = false
		coming[1].storm_preview_schema = 1
		panel.present(weather, coming, player)
		_expect(not panel._warning.visible, "A tagged diagnostic storm manufactured a normal warning.")
		coming[1].erase("storm_preview_schema")
		coming[1].in_seconds = 0.0
		panel.present(weather, coming, player)
		_expect(not panel._warning.visible, "A current storm was presented as approaching.")
		coming[1].in_seconds = 120.0
		coming[1].condition = "clear"
		coming[1].hazard_kind = "toxic_air"
		panel.present(weather, coming, player)
		_expect(not panel._warning.visible, "A non-storm hazard manufactured a storm warning.")
		panel.present(weather, values, player)
		var preview := weather.duplicate(true)
		preview.merge({"preview": true, "storm_preview_schema": 1, "storm_kind": "sandstorm",
			"storm_phase": "warning", "storm_phase_remaining": 23.0}, true)
		panel.present(preview, values, player)
		notice.present(preview, player)
		for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720)]:
			root.size = size
			await process_frame
			await process_frame
			_expect(not panel._panel.visible and notice._panel.visible, "Diagnostic warning conflicted with ordinary forecast.")
			_expect(("Sandsturm" if language == "de" else "Sandstorm") in notice._label.text and "23" in notice._label.text,
				"Diagnostic warning is unreadable.")
			if not captures.is_empty(): await _capture("warning-%dx%d-%s.png" % [size.x, size.y, language])
		panel.present(weather, values, player)
		notice.present({}, null)
	paused = true
	for index in range(3): await process_frame
	_expect(not panel._panel.visible and not notice._panel.visible, "Pause left weather UI over a modal.")
	paused = false
	player.inspection_mode_enabled = true
	for index in range(3): await process_frame
	_expect(not panel._panel.visible, "Inspection left forecast on screen.")
	player.inspection_mode_enabled = false
	panel.present({}, [], null)
	await process_frame
	_expect(not panel._panel.visible, "Missing weather owner retained the previous planet's forecast.")
	var other: Dictionary = Regional.sample("forecast-b", 9, 1280.0,
		Cube.address("forecast-b", 2, 0.2, 0.3), 6371000.0)
	var other_values: Array[Dictionary] = Regional.forecast("forecast-b", 9, 1280.0,
		Cube.address("forecast-b", 2, 0.2, 0.3), 6371000.0)
	panel.present(other, other_values, player)
	_expect(panel._panel.visible and panel._forecast == other_values and panel._snapshot.body_id == "forecast-b",
		"Body/time change kept stale forecast rows.")
	root.get_node("LocaleManager")._apply(language_before)
	stage.queue_free()
	await process_frame
	if not captures.is_empty():
		var review := preload("res://world/weather/checks/weather_water_capture.gd").new()
		failures.append_array(await review.run(self, captures))
	for failure in failures: push_error(failure)
	print("WEATHER_FORECAST_UI: three local windows, DE/EN, 800x600/1280x720/1920x1080, preview, pause and body isolation: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(captures.path_join(filename)) == OK, "Capture failed: " + filename)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
