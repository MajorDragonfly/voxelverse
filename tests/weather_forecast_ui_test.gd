extends SceneTree
const Forecast = preload("res://world/weather/forecast_panel.gd")
const Notice = preload("res://world/weather/storm_preview_notice.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
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
	for language: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(language)
		for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			await process_frame
			await process_frame
			_expect(panel._panel.visible, "Forecast missing in gameplay.")
			_expect(("Wetter" if language == "de" else "Weather") in panel._title.text,
				"Forecast title did not follow the selected language.")
			for index in range(3):
				_expect("WEATHER_" not in panel._rows[index].text and str(index + 1) in panel._rows[index].text,
					"Forecast row missing or untranslated.")
			var bounds: Rect2 = panel._panel.get_global_rect()
			_expect(root.get_visible_rect().encloses(bounds), "Forecast left the viewport.")
			for label: Label in panel._rows:
				_expect(label.get_line_count() == label.get_visible_line_count(), "Forecast text clipped.")
			if not captures.is_empty(): await _capture("forecast-%dx%d-%s.png" % [size.x, size.y, language])
		_expect(values == original, "Presentation changed the model's read-only forecast.")
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
	for failure in failures: push_error(failure)
	print("WEATHER_FORECAST_UI: three local windows, DE/EN, 800x600/1280x720/1920x1080, preview, pause and body isolation: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(captures.path_join(filename)) == OK, "Capture failed: " + filename)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
