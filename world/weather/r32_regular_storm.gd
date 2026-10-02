extends RefCounted
## A benign rain front, not WEATHER-03 extreme weather or exposure simulation.
## Pure body/seed/clock derivation; no timers, persisted events or global RNG.
const SCHEMA: int = 1
const WARNING_SECONDS: float = 180.0
const RISE_SECONDS: float = 45.0
const PEAK_SECONDS: float = 90.0
const FALL_SECONDS: float = 60.0
const CELL_M: float = 6400.0
const CORE_M: float = 1600.0
const EDGE_M: float = 2800.0
const WIND_BOOST_MPS: float = 4.0

static func schedule(body_id: String, seed_value: int) -> Dictionary:
	if body_id.is_empty() or seed_value < 1 or seed_value > 2147483647: return {}
	var token: int = (body_id + ":" + str(seed_value) + ":regular-rain-v1").sha256_text().left(7).hex_to_int()
	var calm: float = 1800.0 + float(token % 361)
	return {"calm": calm, "warning": WARNING_SECONDS, "rising": RISE_SECONDS,
		"peak": PEAK_SECONDS, "falling": FALL_SECONDS,
		"period": calm + WARNING_SECONDS + RISE_SECONDS + PEAK_SECONDS + FALL_SECONDS}

static func region(body_id: String, seed_value: int, point: Array) -> float:
	# Compact support in body-fixed metre cells. The envelope is zero before a
	# nearest-cell boundary, so poles, cube seams and rebases cannot make a jump.
	var token: int = (body_id + ":" + str(seed_value) + ":rain-region-v1").sha256_text().left(7).hex_to_int()
	var distance_squared: float = 0.0
	for axis in range(3):
		var shift: float = float((token >> (axis * 7)) % 127) / 127.0 * CELL_M
		var offset: float = fposmod(float(point[axis]) + shift + CELL_M * 0.5, CELL_M) - CELL_M * 0.5
		distance_squared += offset * offset
	return 1.0 - smoothstep(CORE_M, EDGE_M, sqrt(distance_squared))

static func apply(snapshot: Dictionary, point: Array, has_reference: bool) -> Dictionary:
	# A missing/legacy climate is not proof that this body is safe to opt in.
	if not has_reference or bool(snapshot.get("home_protected", true)) \
			or not bool(snapshot.get("atmosphere_present", false)) \
			or snapshot.get("climate_id") != "earth_temperate": return snapshot
	var clock: float = float(snapshot.get("elapsed_seconds", NAN))
	var cycle: Dictionary = schedule(str(snapshot.get("body_id", "")), int(snapshot.get("seed", 0)))
	if not is_finite(clock) or clock < 0.0 or cycle.is_empty(): return snapshot
	var strength: float = region(snapshot.body_id, snapshot.seed, point) \
		* smoothstep(0.45, 0.70, float(snapshot.moisture_factor)) \
		* smoothstep(0.35, 0.45, float(snapshot.temperature_factor))
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
	match phase:
		"rising": envelope = smoothstep(0.0, duration, phase_time)
		"peak": envelope = 1.0
		"falling": envelope = 1.0 - smoothstep(0.0, duration, phase_time)
	var intensity: float = envelope * strength
	var onset_in: float = float(cycle.calm) + WARNING_SECONDS - within
	var event_id: String = "%s:%d:regular-rain-v1:%d" % [snapshot.body_id, snapshot.seed, int(floor(clock / float(cycle.period)))]
	snapshot.merge({"normal_storm_schema": SCHEMA, "storm_event_id": event_id,
		"storm_kind": "rainstorm", "storm_phase": phase, "storm_intensity": intensity,
		"storm_region_strength": strength, "storm_phase_remaining": duration - phase_time,
		"storm_start_in_seconds": onset_in,
		"storm_warning": phase == "warning" and strength >= 0.25}, true)
	# Original cloud/rain values remain intact at both ends of the envelope.
	# The wet/cold gates exclude snow storms; ordinary showers are not renamed.
	snapshot.precipitation = lerpf(float(snapshot.precipitation), 0.90, intensity)
	snapshot.rain_intensity = snapshot.precipitation
	snapshot.snow_intensity = 0.0
	snapshot.snow_fraction = 0.0
	snapshot.wetness = lerpf(float(snapshot.wetness), 0.90, intensity)
	snapshot.cloud_cover = lerpf(float(snapshot.cloud_cover), 1.0, intensity)
	snapshot.visibility_m = lerpf(float(snapshot.visibility_m), 6000.0, intensity)
	if intensity >= 0.25: snapshot.condition = "rainstorm"
	var projection: float = float(snapshot.wind_projection_strength)
	var area: float = RISE_SECONDS * 0.5 + PEAK_SECONDS + FALL_SECONDS * 0.5
	var mean: float = area / float(cycle.period)
	var boost: float = WIND_BOOST_MPS * strength * (envelope - mean) * projection
	var velocity: Vector3 = Vector3(snapshot.wind_velocity[0], snapshot.wind_velocity[1], snapshot.wind_velocity[2])
	velocity += velocity.normalized() * boost
	snapshot.wind_velocity = [velocity.x, velocity.y, velocity.z]
	snapshot.wind_mps = velocity.length()
	# Integral of the envelope: multiplying a changing wind by total campaign
	# time would teleport clouds/particles on entry, decay and long-session load.
	var rise: float = clampf(within - float(cycle.calm) - WARNING_SECONDS, 0.0, RISE_SECONDS)
	var peak: float = clampf(within - float(cycle.calm) - WARNING_SECONDS - RISE_SECONDS, 0.0, PEAK_SECONDS)
	var fall: float = clampf(within - float(cycle.calm) - WARNING_SECONDS - RISE_SECONDS - PEAK_SECONDS, 0.0, FALL_SECONDS)
	# Remove the cycle mean: bounded periodic displacement even when walking
	# across a region edge after years of campaign time, without a wrap jump.
	var integrated: float = _integral(rise, RISE_SECONDS) + peak + fall \
		- _integral(fall, FALL_SECONDS) - within * mean
	var travel: float = WIND_BOOST_MPS * integrated * strength * projection
	snapshot.wind_offset[0] += cos(float(snapshot.wind_bearing)) * travel
	snapshot.wind_offset[2] += sin(float(snapshot.wind_bearing)) * travel
	return snapshot

static func _integral(seconds: float, duration: float) -> float:
	var x: float = seconds / duration
	return duration * (x * x * x - 0.5 * x * x * x * x)
