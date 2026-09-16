extends SceneTree
const Climate = preload("res://world/weather/planet_climate.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Registry = preload("res://core/campaign/body_registry.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const SAVE: String = "user://voxelverse_save.json"
var failures: Array[String] = []
var saves: Node
var state: Node

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	saves.session_managed = true
	saves.session_active = true
	saves.save_path = SAVE
	if "--climate-future-cold" in OS.get_cmdline_user_args():
		var original: String = FileAccess.get_file_as_string(SAVE)
		var backup: String = FileAccess.get_file_as_string(SAVE + ".bak")
		_expect(not saves.load_now() and not saves.save_now(), "Cold process bypassed future climate protection.")
		_expect(FileAccess.get_file_as_string(SAVE) == original and FileAccess.get_file_as_string(SAVE + ".bak") == backup, "Cold process changed protected source/backup.")
	elif "--climate-cold" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Cold process failed to load climate snapshot.")
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://climate_expected.json"))
		_expect(_fingerprint(state.campaign.data) == expected.campaign, "Cold process changed climate policy/profiles/clock.")
		var body: Dictionary = state.get_current_body_record()
		_expect(_fingerprint(_sample(body, 875.25)) == expected.weather, "Cold process changed weather from saved profile.")
	else:
		_model()
		_profiles()
		_persistence()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PLANET_CLIMATE_PASSED: origin, legacy protection, stable profiles, climate effects, save/copy/migration, failure and cold-process guards.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _model() -> void:
	for seed_value in [1, 2, 15838, 23757, 2147483647]:
		var campaign := Campaign.new()
		campaign.reset("origin-contract")
		var home: Dictionary = campaign.ensure_body(seed_value, seed_value)
		_expect(home.weather_climate.profile_id == "earth_temperate" and home.weather_climate.home_protected, "New home is not protected.")
		var away: Dictionary = campaign.ensure_body(seed_value, 17 if seed_value != 17 else 18)
		_expect(home.id != away.id and not away.weather_climate.home_protected, "Equal seeds in other systems inherited home identity.")
		_expect(campaign.data.weather_policy.origin_body_id == home.id, "Creation changed origin.")
		var saved: Dictionary = campaign.export_state()
		var restored := Campaign.new()
		_expect(restored.import_state(saved) and restored.export_state() == saved, "Import rerolled a profile.")
		for clock in range(0, 12000, 173):
			var weather: Dictionary = _sample(home, float(clock))
			_expect(weather.climate_id == "earth_temperate" and weather.hazard_kind == "none" and weather.wind_mps < 5.4, "Protected home left mild bounds.")
		var invalid: Dictionary = saved.duplicate(true)
		invalid.bodies[home.id].weather_climate.profile_id = "volcanic"
		_expect(not Registry.validate(invalid).is_empty(), "Hot climate accepted on protected home.")
		invalid = saved.duplicate(true)
		invalid.weather_policy.origin_body_id = away.id
		_expect(not Registry.validate(invalid).is_empty(), "Changed origin accepted without matching protection.")
	# Existing bodies keep their old weather; unknown origin is explicit, even
	# when current location or serialized order points at a different planet.
	var campaign := Campaign.new()
	campaign.reset("order-contract")
	var home: Dictionary = campaign.ensure_body(15838, 15838)
	var second: Dictionary = campaign.ensure_body(23757, 15838)
	var third: Dictionary = campaign.ensure_body(63352, 15838)
	var alternate := Campaign.new()
	alternate.reset("order-contract")
	alternate.ensure_body(15838, 15838)
	alternate.ensure_body(63352, 15838)
	_expect(alternate.ensure_body(23757, 15838).weather_climate == second.weather_climate, "Profile depends on visitation order.")
	var old: Dictionary = campaign.export_state()
	old.erase(Climate.POLICY)
	for body: Dictionary in old.bodies.values(): body.erase(Climate.FIELD)
	var original: String = _fingerprint(old)
	var upgraded: Dictionary = Registry.upgrade_campaign(old)
	_expect(upgraded.ok and _fingerprint(old) == original, "Migration changed source.")
	_expect(upgraded.data.weather_policy.origin_status == "legacy_unknown" and upgraded.data.weather_policy.origin_body_id == "", "Legacy migration guessed home.")
	for body: Dictionary in upgraded.data.bodies.values():
		_expect(body.weather_climate.home_protected and body.weather_climate.profile_id == "earth_temperate", "Previously visited planet lost protection.")
	_expect(Registry.upgrade_campaign(upgraded.data).data == upgraded.data, "Migration is not idempotent.")
	var broken: Dictionary = campaign.export_state()
	broken.bodies[second.id].weather_climate.body_id = third.id
	_expect(not Registry.validate(broken).is_empty(), "Foreign-body climate accepted.")
	broken = campaign.export_state()
	broken.bodies[home.id].erase(Climate.FIELD)
	_expect(not Registry.validate(broken).is_empty(), "Missing reference silently regenerated.")
	var catalog: Dictionary = Climate.catalog()
	catalog.airless.atmosphere = "temperate"
	_expect(Climate.catalog().airless.atmosphere == "none", "Catalog exposes mutable profiles.")

func _profiles() -> void:
	var body: Dictionary = {"id": "sample-body", "seed": 15838}
	for profile_id in Climate.CATALOG:
		body[Climate.FIELD] = Climate.make_reference(body.id, profile_id)
		var positive_precipitation: bool = false
		for clock in range(0, 1800, 31):
			var weather: Dictionary = _sample(body, float(clock))
			_expect(weather.climate_id == profile_id and weather.climate_revision == 1, "Weather lost profile reference.")
			_expect(weather.hazard_kind == "none" and weather.hazard_intensity == 0, "Base climate enabled an unfinished extreme storm.")
			positive_precipitation = positive_precipitation or weather.precipitation > 0.001
			if profile_id == "frozen": _expect(weather.rain_intensity == 0, "Frozen profile produced rain.")
			if profile_id == "volcanic": _expect(weather.precipitation == 0, "Volcanic profile produced water precipitation.")
			if profile_id == "airless":
				_expect(not weather.atmosphere_present and weather.cloud_cover == 0 and weather.precipitation == 0 and weather.wind_mps == 0 and weather.wind_offset == [0.0, 0.0, 0.0], "Airless body has atmospheric weather.")
				_expect(Regional.preview(weather, "rain").precipitation == 0, "Preview enabled vacuum rain.")
		if profile_id in ["earth_temperate", "frozen"]: _expect(positive_precipitation, "Wet/cold profile never precipitates.")
		var weather: Dictionary = _sample(body, 875.25)
		var context: Dictionary = {"temperature": 0.8, "moisture": 0.95, Climate.FIELD: body[Climate.FIELD]}
		var address: Dictionary = Surface.Cube.address(body.id, 0, 0.2, 0.3)
		for row in Regional.forecast(body.id, body.seed, 875.25, address, Surface.DEFAULT_RADIUS, context):
			_expect(row.precipitation == _sample(body, 875.25 + row.in_seconds).precipitation, "Forecast ignored saved climate.")
		_expect(Regional.preview(weather, "snow").climate_id == profile_id, "Diagnostic preview replaced profile.")
		# New profile modifiers are continuous on the same body-fixed field.
		for face in range(6):
			var a: Dictionary = Surface.Cube.address(body.id, face, 1.0 - 1e-9, 0.3)
			var b: Dictionary = Surface.Cube.address(body.id, face, 1.0 + 1e-9, 0.3)
			var one: Dictionary = Regional.sample(body.id, body.seed, 875.25, a, Surface.DEFAULT_RADIUS, context)
			var two: Dictionary = Regional.sample(body.id, body.seed, 875.25, b, Surface.DEFAULT_RADIUS, context)
			_expect(absf(one.precipitation - two.precipitation) < 0.0001 and absf(one.cloud_cover - two.cloud_cover) < 0.0001, "Climate introduced cube seam.")
	body[Climate.FIELD] = Climate.make_reference(body.id, "future-profile")
	_expect(_sample(body, 500).is_empty(), "Unknown profile silently fell back.")

func _persistence() -> void:
	state.start_world_with_seed(15838)
	var home: String = state.active_body_id
	var other: Dictionary = state.campaign.ensure_body(23757, 15838)
	state.campaign.body_record(other.id).weather_climate = Climate.make_reference(other.id, "frozen")
	_expect(state.activate_body(other.id, 15838, 1, false), "Could not activate away body.")
	state.campaign.data.elapsed_seconds = 875.25
	_expect(saves.save_now(), "Climate save failed: " + saves.last_error)
	var good: Dictionary = saves._read_save(SAVE)
	var legacy: Dictionary = good.duplicate(true)
	legacy.game_state.campaign.erase(Climate.POLICY)
	for body: Dictionary in legacy.game_state.campaign.bodies.values(): body.erase(Climate.FIELD)
	Atomic.write(SAVE, legacy, false)
	var legacy_bytes: String = FileAccess.get_file_as_string(SAVE)
	_expect(saves.load_now() and state.campaign.data.weather_policy.origin_body_id == "", "Legacy loader guessed active body as origin.")
	_expect(FileAccess.get_file_as_string(SAVE) == legacy_bytes, "Loading rewrote historical source.")
	_expect(saves.save_now(), "Migrated climate snapshot failed.")
	_expect(state.campaign.data.weather_policy.protected_body_ids.size() == 2, "Legacy A/B not both protected.")
	Atomic.write(SAVE, good, false)
	_expect(saves.load_now(), "Could not restore explicit origin save.")
	saves.session_active = false
	var duplicate: String = saves.duplicate_slot(SAVE, "Climate copy")
	saves.session_active = true
	_expect(not duplicate.is_empty(), "Slot copy failed: " + saves.last_error)
	if not duplicate.is_empty():
		var copied: Dictionary = saves._read_save(duplicate).game_state.campaign
		_expect(copied.weather_policy == good.game_state.campaign.weather_policy and copied.bodies == good.game_state.campaign.bodies, "Slot copy rerolled profiles or origin.")
	var migration: Dictionary = preload("res://core/campaign/spherical_migration.gd").plan(good, JSON.stringify(good), SAVE)
	_expect(migration.ok, "Planar-to-sphere migration rejected climate reference.")
	if migration.ok:
		_expect(migration.data.game_state.campaign.weather_policy == good.game_state.campaign.weather_policy, "Sphere migration changed origin.")
		for body: Dictionary in migration.data.game_state.campaign.bodies.values():
			_expect(body.weather_climate == good.game_state.campaign.bodies[body.id].weather_climate, "Sphere migration changed climate.")
	var path: String = saves.save_path
	saves.save_path = "user://missing-climate-parent/blocked.json"
	_expect(not saves.save_now() and saves._read_save(SAVE) == good, "Failed save replaced committed climate data.")
	saves.save_path = path
	Atomic.write("user://climate_expected.json", {"campaign": _fingerprint(state.campaign.data), "weather": _fingerprint(_sample(state.get_current_body_record(), 875.25))}, false)
	_cold("--climate-cold")
	for change in ["policy_schema", "policy_status", "body_schema", "revision", "profile"]:
		var future: Dictionary = good.duplicate(true)
		var body: Dictionary = future.game_state.campaign.bodies[other.id]
		match change:
			"policy_schema": future.game_state.campaign.weather_policy.schema = 999
			"policy_status": future.game_state.campaign.weather_policy.origin_status = "future"
			"body_schema": body.weather_climate.schema = 999
			"revision": body.weather_climate.revision = 999
			"profile": body.weather_climate.profile_id = "sandstorm-v2"
		Atomic.write(SAVE, future, false)
		Atomic.write(SAVE + ".bak", good, false)
		var original: String = FileAccess.get_file_as_string(SAVE)
		var backup: String = FileAccess.get_file_as_string(SAVE + ".bak")
		var before: String = _fingerprint(state.export_state())
		_expect(not saves.inspect_slot(SAVE).valid and not saves.load_now() and not saves.save_now(), "Future climate fell back or was overwritten: " + change)
		_expect(_fingerprint(state.export_state()) == before and FileAccess.get_file_as_string(SAVE) == original and FileAccess.get_file_as_string(SAVE + ".bak") == backup, "Future climate protection changed bytes/live state.")
		if change == "revision": _cold("--climate-future-cold")
		Atomic.write(SAVE, good, false)
		_expect(saves.load_now(), "Recovery failed after future climate guard.")
	_expect(state.activate_body(home, 15838, 0, false) and state.campaign.data.weather_policy.origin_body_id == home, "A-B-A lost origin.")

func _cold(flag: String) -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", flag], output, true)
	_expect(code == 0 and str(output).contains("PLANET_CLIMATE_PASSED") and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Cold-process failure: " + str(output))

func _sample(body: Dictionary, clock: float) -> Dictionary:
	return Regional.sample(body.id, int(body.seed), clock, Surface.Cube.address(body.id, 0, 0.2, 0.3), Surface.DEFAULT_RADIUS,
		{"temperature": 0.8, "moisture": 0.95, Climate.FIELD: body[Climate.FIELD]})

func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", true)

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
