extends SceneTree
const Model = preload("res://world/weather/weather_model.gd")
const Storm = preload("res://world/weather/storm_preview.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const Climate = preload("res://world/weather/planet_climate.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const View = preload("res://world/weather/weather_view.gd")
const Notice = preload("res://world/weather/storm_preview_notice.gd")
var failures: Array[String] = []

class PreviewPlayer extends Node:
	var inspection_mode_enabled: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--storm-cold" in OS.get_cmdline_user_args():
		var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("user://storm_restart.json"))
		for fixture: Dictionary in fixtures:
			_expect(var_to_bytes(_sample(fixture.kind, fixture.clock)).hex_encode() == fixture.expected, "Cold process changed storm/warning.")
	else:
		_model_contract()
		await _presentation_contract()
	for failure in failures: push_error(failure)
	print("WEATHER_STORM: deterministic phases, continuous drift, protected climates, cold resume, bounded dust, warning DE/EN and pause: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _base(kind: String, clock: float, body_id: String = "storm-fixture") -> Dictionary:
	return Regional.sample(body_id, 15838, clock, Cube.address(body_id, 2, 0.2, 0.3), 6371000.0,
		{Climate.FIELD: Climate.make_reference(body_id, Storm.PROFILES[kind].climate)})

func _sample(kind: String, clock: float, body_id: String = "storm-fixture") -> Dictionary:
	return Regional.preview(_base(kind, clock, body_id), kind)

func _model_contract() -> void:
	var fixtures: Array = []
	for kind: String in ["sandstorm", "ashstorm"]:
		_expect(Model.supports_preview(kind), "CLI rejected storm preview.")
		var schedule: Dictionary = Storm.schedule("storm-fixture", 15838, kind)
		var start: float = 0.0
		for phase: String in ["calm", "warning", "rising", "peak", "falling"]:
			var duration: float = schedule[phase]
			var snap: Dictionary = _sample(kind, start + duration * 0.5)
			_expect(snap.storm_phase == phase and is_equal_approx(snap.storm_phase_progress, 0.5), "Phase order/progress wrong: " + phase)
			_expect(snap.storm_warning == (phase == "warning"), "Warning did not precede storm.")
			if phase in ["calm", "warning"]: _expect(snap.storm_intensity == 0 and snap.storm_particle_intensity == 0, "Dust arrived before warning ended.")
			if phase == "peak": _expect(snap.storm_intensity == 1 and snap.visibility_m == Storm.PROFILES[kind].visibility, "Peak has no visibility reduction.")
			fixtures.append({"kind": kind, "clock": start + duration * 0.5, "expected": var_to_bytes(snap).hex_encode()})
			start += duration
			# Check each boundary after many cycles, including the cycle wrap.
			var before: Dictionary = _sample(kind, start + 2000.0 * schedule.period - 0.001)
			var after: Dictionary = _sample(kind, start + 2000.0 * schedule.period + 0.001)
			for key: String in ["storm_intensity", "wind_mps", "cloud_cover", "visibility_m"]:
				_expect(absf(float(before[key]) - float(after[key])) < 0.01, "Storm snapped at boundary: " + key)
			for axis: int in [0, 2]:
				_expect(absf(after.wind_offset[axis] - before.wind_offset[axis]) < 0.04, "Changing wind teleported dust after long play.")
		var phase_set: Dictionary = {}
		for clock: int in range(0, 3600, 7):
			var base: Dictionary = _base(kind, clock)
			var original: Dictionary = base.duplicate(true)
			var snap: Dictionary = Regional.preview(base, kind)
			phase_set[snap.storm_phase] = true
			_expect(base == original and not bool(base.get("preview", false)), "Preview mutated normal weather.")
			_expect(snap.hazard_kind == "none" and snap.hazard_intensity == 0 and snap.precipitation == 0 and snap.wetness == 0, "Diagnostic enabled damage/rain/wetness.")
			_expect(snap.storm_intensity >= 0 and snap.storm_intensity <= 1 and snap.wind_mps <= 18.0, "Storm escaped preview bounds.")
			_expect(snap == _sample(kind, clock), "Identical input rerolled storm.")
		_expect(phase_set.size() == 5, "Not all phases reachable.")
		var a: Dictionary = _sample(kind, 159.5)
		_sample(kind, 852.2, "other-body")
		_expect(a == _sample(kind, 159.5), "A-B-A mixed body weather.")
		for guard: String in ["home_protected", "atmosphere_present", "climate_id", "elapsed_seconds"]:
			var base: Dictionary = _base(kind, 159.5)
			match guard:
				"home_protected": base[guard] = true
				"atmosphere_present": base[guard] = false
				"climate_id": base[guard] = "earth_temperate"
				"elapsed_seconds": base[guard] = -1.0
			_expect(Regional.preview(base, kind) == base, "Preview bypassed guard: " + guard)
		var missing: Dictionary = _base(kind, 159.5)
		missing.erase("home_protected")
		_expect(Regional.preview(missing, kind) == missing, "Unknown protection accepted.")
		var home: Dictionary = Regional.sample("home", 1, 200.0, Cube.address("home", 0, 0, 0), 1000,
			{Climate.FIELD: Climate.make_reference("home", "earth_temperate", true)})
		_expect(Regional.preview(home, kind) == home, "Protected home got a storm.")
		_expect(Model.sample("x", 1, 200, Storm.PROFILES[kind].climate + "_extreme").is_empty(), "Reserved extreme climate activated.")
	var file := FileAccess.open("user://storm_restart.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(fixtures))
	file.close()
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/weather_storm_test.gd", "--", "--storm-cold"], output, true)
	_expect(code == 0, "Storm cold resume failed: " + str(output))

func _presentation_contract() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var view := View.new()
	scene.add_child(view)
	view.configure(15838)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	collision.shape = box
	floor_body.add_child(collision)
	scene.add_child(floor_body)
	floor_body.position.y = -4.0
	await physics_frame
	await physics_frame
	view.position_at(Vector3.ZERO, Vector3.UP)
	view.probe_cover([])
	for kind: String in ["sandstorm", "ashstorm"]:
		var cycle: Dictionary = Storm.schedule("storm-fixture", 15838, kind)
		var peak: Dictionary = _sample(kind, cycle.calm + cycle.warning + cycle.rising + 5.0)
		view.present(peak, false, false)
		_expect(view._rain.multimesh.visible_instance_count == 346, "Unexpected peak particle budget.")
		var drawn: int = 0
		for i: int in range(view._rain.multimesh.visible_instance_count):
			var item: Dictionary = view.particle_submission(i)
			var transform: Transform3D = item.transform
			if transform.basis.determinant() <= 0.0: continue
			drawn += 1
			_expect(transform.origin.y >= -3.35 and transform.origin.length_squared() >= 1.0, "Dust escaped ground/near-camera clipping.")
			_expect(transform.basis.get_scale().y < 0.07 and item.color == Storm.PROFILES[kind].color, "Dust reused a rain streak/color.")
		_expect(drawn > 0, "Storm drew no dust.")
		view.present(peak, true, false)
		_expect(not view._rain.visible and not view._clouds.visible, "Storm remained underwater.")
		view.present(peak, false, true)
		_expect(not view._rain.visible, "Storm remained beneath a roof.")
		view.present(_sample(kind, cycle.calm + 5.0), false, false)
		_expect(view._rain.multimesh.visible_instance_count == 0, "Warning phase drew particles.")
	_expect(view.get_child_count() == 2 and view._rain.multimesh.instance_count == 384 and view._clouds.multimesh.instance_count == 96, "Storm grew the render pools.")
	view.hide_weather()
	_expect(view.particle_submission(0).is_empty(), "Hidden view retained visible dust.")
	var player := PreviewPlayer.new()
	scene.add_child(player)
	var notice := Notice.new()
	scene.add_child(notice)
	var cycle: Dictionary = Storm.schedule("storm-fixture", 15838, "sandstorm")
	var warning: Dictionary = _sample("sandstorm", cycle.calm + 7.0)
	var locale: String = TranslationServer.get_locale()
	for language: String in ["de", "en"]:
		root.get_node("LocaleManager")._apply(language)
		for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720)]:
			root.size = size
			notice.present(warning, player)
			await process_frame
			await process_frame
			_expect(notice._panel.visible and "23" in notice._label.text and "WEATHER_STORM" not in notice._label.text, "Warning missing/untranslated.")
			_expect(("Sandsturm" if language == "de" else "Sandstorm") in notice._label.text, "Warning language did not change.")
			var bounds: Rect2 = notice._panel.get_global_rect()
			_expect(root.get_visible_rect().encloses(bounds), "Warning outside viewport.")
			_expect(notice._label.get_line_count() == notice._label.get_visible_line_count(), "Warning text clipped.")
	paused = true
	await process_frame
	await process_frame
	_expect(not notice._panel.visible, "Warning covered a paused modal.")
	paused = false
	player.inspection_mode_enabled = true
	await process_frame
	await process_frame
	_expect(not notice._panel.visible, "Warning covered inspection UI.")
	player.inspection_mode_enabled = false
	notice.present({}, player)
	_expect(not notice._panel.visible, "Body/menu change left a stale warning.")
	root.get_node("LocaleManager")._apply(locale)
	scene.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
