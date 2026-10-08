extends RefCounted
## First normal extreme family. Requires real dry sandy terrain, not merely
## a climate name. Authoritative event identity uses the existing campaign clock.
const Rain = preload("res://world/weather/r32_regular_storm.gd")
const WARNING_SECONDS: float = 180.0
const RISE_SECONDS: float = 45.0
const PEAK_SECONDS: float = 90.0
const FALL_SECONDS: float = 60.0

static func schedule(body_id: String, seed_value: int) -> Dictionary:
	if body_id.is_empty() or seed_value < 1 or seed_value > 2147483647: return {}
	var token: int = (body_id + ":" + str(seed_value) + ":normal-sand-v1").sha256_text().left(7).hex_to_int()
	var calm: float = 1800.0 + float(token % 361)
	return {"calm": calm, "warning": WARNING_SECONDS, "rising": RISE_SECONDS,
		"peak": PEAK_SECONDS, "falling": FALL_SECONDS,
		"period": calm + WARNING_SECONDS + RISE_SECONDS + PEAK_SECONDS + FALL_SECONDS}

static func event_id(body_id: String, seed_value: int, clock: float) -> String:
	var cycle: Dictionary = schedule(body_id, seed_value)
	if cycle.is_empty() or not is_finite(clock) or clock < 0.0: return ""
	return "%s:%d:normal-sand-v1:%d" % [body_id, seed_value, floori(clock / float(cycle.period))]

static func region(body_id: String, seed_value: int, point: Array) -> float:
	return Rain.region(body_id + ":sand", seed_value, point)

static func apply(snapshot: Dictionary, point: Array, terrain: Dictionary) -> Dictionary:
	if not terrain.has("weather_climate") or bool(snapshot.get("home_protected", true)) \
		or not bool(snapshot.get("atmosphere_present", false)) or snapshot.get("climate_id") != "arid": return snapshot
	# Weather's arid moisture scale cannot manufacture a desert in a wet forest.
	# Gate against the actual unscaled terrain/material field and dry ground.
	for key: String in ["moisture", "temperature"]:
		var raw: Variant = terrain.get(key)
		if not (raw is float or raw is int) or not is_finite(float(raw)) or float(raw) < 0.0 or float(raw) > 1.0: return snapshot
	var weights: Variant = terrain.get("biome_weights", {})
	var sand: float = float(weights.get("desert", 0.0)) if weights is Dictionary else 0.0
	if not is_finite(sand) or sand < 0.0 or sand > 1.0: return snapshot
	if terrain.get("biome") == "desert": sand = 1.0
	if bool(terrain.get("water", true)) or bool(terrain.get("blocked", true)) \
		or sand < 0.10 or float(terrain.get("moisture", 1.0)) >= 0.25 \
		or float(terrain.get("temperature", 0.0)) <= 0.30: return snapshot
	var clock: float = float(snapshot.get("elapsed_seconds", NAN))
	var cycle: Dictionary = schedule(str(snapshot.get("body_id", "")), int(snapshot.get("seed", 0)))
	if not is_finite(clock) or clock < 0.0 or cycle.is_empty(): return snapshot
	var strength: float = region(snapshot.body_id, snapshot.seed, point) \
		* (1.0 - smoothstep(0.15, 0.25, float(terrain.moisture))) * smoothstep(0.10, 0.25, sand)
	if strength <= 0.0: return snapshot
	var within: float = fposmod(clock, cycle.period)
	var phase: String = "calm"
	var phase_time: float = within
	var duration: float = cycle.calm
	var start: float = cycle.calm
	for candidate: String in ["warning", "rising", "peak", "falling"]:
		if within >= start:
			phase = candidate
			phase_time = within - start
			duration = cycle[candidate]
		start += float(cycle[candidate])
	var envelope: float = 0.0
	if phase == "rising": envelope = smoothstep(0.0, duration, phase_time)
	elif phase == "peak": envelope = 1.0
	elif phase == "falling": envelope = 1.0 - smoothstep(0.0, duration, phase_time)
	var intensity: float = envelope * strength
	snapshot.merge({"normal_storm_schema": 1, "extreme_storm_schema": 1,
		"storm_event_id": event_id(snapshot.body_id, snapshot.seed, clock), "storm_kind": "sandstorm",
		"storm_phase": phase, "storm_phase_remaining": duration - phase_time,
		"storm_start_in_seconds": cycle.calm + WARNING_SECONDS - within,
		"storm_region_strength": strength, "storm_intensity": intensity,
		"storm_warning": phase == "warning" and strength >= 0.25,
		"storm_particle_color": Color("bfa16d"), "storm_particle_intensity": intensity * 0.9,
		"hazard_kind": "sandstorm", "hazard_intensity": intensity}, true)
	if intensity >= 0.25: snapshot.condition = "sandstorm"
	snapshot.visibility_m = lerpf(float(snapshot.visibility_m), 500.0, intensity)
	snapshot.cloud_cover = lerpf(float(snapshot.cloud_cover), 0.94, intensity)
	for key: String in ["precipitation", "rain_intensity", "snow_intensity", "snow_fraction", "wetness"]:
		snapshot[key] *= 1.0 - intensity
	var projection: float = float(snapshot.wind_projection_strength)
	var mean: float = (RISE_SECONDS * 0.5 + PEAK_SECONDS + FALL_SECONDS * 0.5) / float(cycle.period)
	var velocity := Vector3(snapshot.wind_velocity[0], snapshot.wind_velocity[1], snapshot.wind_velocity[2])
	var boost: float = 12.0 * strength * projection
	velocity += velocity.normalized() * boost * (envelope - mean)
	snapshot.wind_velocity = [velocity.x, velocity.y, velocity.z]
	snapshot.wind_mps = velocity.length()
	# Bounded periodic additional displacement. A region change years later
	# cannot amplify accumulated storm wind into a discontinuity.
	var rise: float = clampf(within - cycle.calm - WARNING_SECONDS, 0.0, RISE_SECONDS)
	var peak: float = clampf(within - cycle.calm - WARNING_SECONDS - RISE_SECONDS, 0.0, PEAK_SECONDS)
	var fall: float = clampf(within - cycle.calm - WARNING_SECONDS - RISE_SECONDS - PEAK_SECONDS, 0.0, FALL_SECONDS)
	var travel: float = boost * (Rain._integral(rise, RISE_SECONDS) + peak + fall - Rain._integral(fall, FALL_SECONDS) - within * mean)
	snapshot.wind_offset[0] += cos(float(snapshot.wind_bearing)) * travel
	snapshot.wind_offset[2] += sin(float(snapshot.wind_bearing)) * travel
	return snapshot
