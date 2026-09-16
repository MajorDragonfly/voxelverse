extends RefCounted
## Diagnostic presentation only. Regular climates and all damage/exposure ports
## remain unchanged. Every phase and particle offset derives from campaign time.
const PROFILES: Dictionary = {
	"sandstorm": {"climate": "arid", "wind": 18.0, "visibility": 500.0, "color": Color("bfa16d")},
	"ashstorm": {"climate": "volcanic", "wind": 12.0, "visibility": 700.0, "color": Color("8c8582")},
}
const WARNING_SECONDS: float = 30.0
const RISE_SECONDS: float = 30.0
const FALL_SECONDS: float = 45.0

static func schedule(body_id: String, seed_value: int, kind: String) -> Dictionary:
	if body_id.is_empty() or seed_value < 1 or seed_value > 2147483647 or not PROFILES.has(kind): return {}
	var token: int = (body_id + ":" + str(seed_value) + ":storm-preview-v1:" + kind).sha256_text().left(7).hex_to_int()
	var calm: float = 75.0 + float(token % 31)
	var peak: float = 45.0 + float((token / 31) % 16)
	return {"calm": calm, "warning": WARNING_SECONDS, "rising": RISE_SECONDS,
		"peak": peak, "falling": FALL_SECONDS, "period": calm + WARNING_SECONDS + RISE_SECONDS + peak + FALL_SECONDS}

static func apply(snapshot: Dictionary, kind: String) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	if snapshot.is_empty() or not PROFILES.has(kind): return result
	var profile: Dictionary = PROFILES[kind]
	# Even an explicit preview cannot put extreme weather on a protected home,
	# into vacuum, or on a planet with an unrelated/unsupported climate.
	if bool(snapshot.get("home_protected", true)) or not bool(snapshot.get("atmosphere_present", false)) \
			or snapshot.get("climate_id") != profile.climate: return result
	var clock: float = float(snapshot.get("elapsed_seconds", NAN))
	var cycle: Dictionary = schedule(str(snapshot.get("body_id", "")), int(snapshot.get("seed", 0)), kind)
	if not is_finite(clock) or clock < 0.0 or cycle.is_empty(): return result
	var within: float = fposmod(clock, cycle.period)
	var phase: String = "calm"
	var phase_time: float = within
	var duration: float = cycle.calm
	var intensity: float = 0.0
	var start: float = cycle.calm
	for candidate: String in ["warning", "rising", "peak", "falling"]:
		if within >= start:
			phase = candidate
			phase_time = within - start
			duration = cycle[candidate]
		start += float(cycle[candidate])
	match phase:
		"rising": intensity = smoothstep(0.0, duration, phase_time)
		"peak": intensity = 1.0
		"falling": intensity = 1.0 - smoothstep(0.0, duration, phase_time)
	# Analytic integral of the smooth envelope: changing wind never multiplies
	# the absolute clock, so entering/leaving a storm cannot jump the particles.
	var area: float = RISE_SECONDS * 0.5 + float(cycle.peak) + FALL_SECONDS * 0.5
	var rising_time: float = clampf(within - float(cycle.calm) - WARNING_SECONDS, 0.0, RISE_SECONDS)
	var peak_time: float = clampf(within - float(cycle.calm) - WARNING_SECONDS - RISE_SECONDS, 0.0, cycle.peak)
	var falling_time: float = clampf(within - float(cycle.calm) - WARNING_SECONDS - RISE_SECONDS - float(cycle.peak), 0.0, FALL_SECONDS)
	var integrated: float = floor(clock / float(cycle.period)) * area + _smooth_integral(rising_time, RISE_SECONDS) \
		+ peak_time + falling_time - _smooth_integral(falling_time, FALL_SECONDS)
	var projection: float = clampf(float(snapshot.get("wind_projection_strength", 1.0)), 0.0, 1.0)
	var speed: float = lerpf(2.5, profile.wind, intensity) * projection
	var travel: float = (clock * 2.5 + (float(profile.wind) - 2.5) * integrated) * projection
	var bearing: float = float(snapshot.get("wind_bearing", 0.0))
	var old_wind: Array = snapshot.get("wind_velocity", [0.0, 0.0, 0.0])
	var velocity := Vector3(old_wind[0], old_wind[1], old_wind[2]).normalized() * speed
	result.merge({"preview": true, "storm_preview_schema": 1, "storm_kind": kind,
		"storm_phase": phase, "storm_phase_progress": phase_time / duration,
		"storm_phase_remaining": maxf(0.0, duration - phase_time), "storm_intensity": intensity,
		"storm_particle_color": profile.color, "storm_particle_intensity": intensity * 0.9,
		"storm_warning": phase == "warning", "storm_cycle": int(floor(clock / float(cycle.period))),
		"condition": kind if intensity > 0.0 else "breeze", "wind_mps": speed,
		"wind_velocity": [velocity.x, velocity.y, velocity.z],
		"wind_offset": [cos(bearing) * travel, 0.0, sin(bearing) * travel],
		"cloud_cover": lerpf(0.28, 0.94, intensity), "visibility_m": lerpf(16000.0, profile.visibility, intensity),
		"precipitation": 0.0, "rain_intensity": 0.0, "snow_intensity": 0.0, "snow_fraction": 0.0,
		"wetness": 0.0, "hazard_kind": "none", "hazard_intensity": 0.0}, true)
	return result

static func _smooth_integral(seconds: float, duration: float) -> float:
	var x: float = seconds / duration
	return duration * (x * x * x - 0.5 * x * x * x * x)
