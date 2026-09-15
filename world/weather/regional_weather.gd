extends RefCounted
## WEATHER-02A: continuous body-fixed fronts and benign regional precipitation.
## All current climates remain safe. This is derived presentation, never exposure damage.
const Model = preload("res://world/weather/weather_model.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Field = preload("res://world/space/scalar_noise.gd")
const SCHEMA: int = 1
const FRONT_SPACING_M: float = 3200.0

static func sample(body_id: String, seed_value: int, clock: float, address: Dictionary,
		radius: float, climate: Dictionary = {}) -> Dictionary:
	if not Cube.valid(address, body_id) or not is_finite(radius) or radius <= 0.0 \
			or not is_finite(clock) or seed_value < 1 or seed_value > 2147483647: return {}
	clock = maxf(clock, 0.0)
	# Sample sea-level directions: camera altitude must not move a weather front.
	var direction: Array = Cube.direction(int(address.face), float(address.u), float(address.v))
	var point: Array = [direction[0] * radius, direction[1] * radius, direction[2] * radius]
	var phase: float = float(posmod(seed_value, 360)) * PI / 180.0
	var flow := Vector3(cos(phase), 0.28, sin(phase)).normalized()
	var advected: Array = [point[0] - flow.x * clock * 2.5, point[1] - flow.y * clock * 2.5, point[2] - flow.z * clock * 2.5]
	var front: float = Field.sample(advected, FRONT_SPACING_M, seed_value + 7919)
	var local_clock: float = clock + front * 95.0 * smoothstep(180.0, 360.0, clock)
	var result: Dictionary = Model.sample(body_id, seed_value, local_clock)
	if result.is_empty(): return {}
	var moisture: float = _unit(climate.get("moisture", 0.5), 0.5)
	var temperature: float = _unit(climate.get("temperature", 0.6), 0.6)
	var cloud_band: float = 0.5 + 0.5 * Field.sample(advected, FRONT_SPACING_M * 0.6, seed_value + 31337)
	var wet_factor: float = smoothstep(0.08, 0.6, moisture) * lerpf(0.35, 1.0, cloud_band)
	var snow_fraction: float = 1.0 - smoothstep(0.10, 0.30, temperature)
	result.precipitation *= wet_factor
	result.wetness *= wet_factor * (1.0 - snow_fraction)
	result.cloud_cover = clampf(float(result.cloud_cover) * lerpf(0.30, 1.0, moisture) + cloud_band * 0.12, 0.05, 1.0)
	result.merge({"regional_schema": SCHEMA, "elapsed_seconds": clock, "regional_seconds": local_clock,
		"region_strength": cloud_band, "temperature_factor": temperature, "moisture_factor": moisture,
		"rain_intensity": float(result.precipitation) * (1.0 - snow_fraction),
		"snow_intensity": float(result.precipitation) * snow_fraction,
		"snow_fraction": snow_fraction, "atmosphere_present": str(climate.get("atmosphere", "temperate")) != "none"}, true)
	if result.precipitation > 0.01 and snow_fraction > 0.65: result.condition = "snow"
	elif result.precipitation > 0.01 and snow_fraction > 0.05: result.condition = "sleet"
	elif result.precipitation <= 0.01 and result.condition in ["rain", "drizzle"]:
		result.condition = "overcast" if result.cloud_cover > 0.6 else "breeze"
	# Project a body-fixed flow into the tangent plane. World wind is continuous
	# across cube seams and poles, including calm points where projection is zero.
	var up: Vector3 = Cube.vector(direction)
	var tangent: Vector3 = flow.slide(up)
	var gust: float = 0.5 + 0.5 * sin(clock / 7.0 + phase + front)
	var velocity: Vector3 = tangent * float(result.wind_mps) * lerpf(0.85, 1.12, gust)
	var frame: Basis = Cube.frame(up)
	var local_wind: Vector3 = frame.inverse() * velocity
	result.wind_mps = velocity.length()
	result.wind_bearing = atan2(local_wind.z, local_wind.x)
	result.wind_velocity = [velocity.x, velocity.y, velocity.z]
	result.gust_strength = gust
	# Analytic gust displacement; never clock * changing instantaneous speed.
	# Large absolute time can alter phase, but not amplify a frame-to-frame gust.
	var travel: float = clock * 2.5 - cos(clock / 7.0 + phase) * 1.4
	var offset: Vector3 = frame.inverse() * (tangent * travel)
	result.wind_offset = [offset.x, 0.0, offset.z]
	if not result.atmosphere_present:
		for key in ["cloud_cover", "precipitation", "wetness", "rain_intensity", "snow_intensity", "wind_mps", "gust_strength"]: result[key] = 0.0
		result.wind_velocity = [0.0, 0.0, 0.0]
		result.condition = "clear"
	return result

## Fixed, read-only forecast for this location. Never moves the campaign clock.
static func forecast(body_id: String, seed_value: int, clock: float, address: Dictionary,
		radius: float, climate: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for horizon in [60.0, 120.0, 180.0]:
		var next: Dictionary = sample(body_id, seed_value, clock + horizon, address, radius, climate)
		if next.is_empty(): return []
		result.append({"in_seconds": horizon, "condition": next.condition, "precipitation": next.precipitation,
			"rain_intensity": next.rain_intensity, "snow_intensity": next.snow_intensity, "wind_mps": next.wind_mps})
	return result

static func preview(snapshot: Dictionary, condition: String) -> Dictionary:
	if snapshot.is_empty(): return {}
	var preset: Dictionary = Model.preset(condition)
	if preset.is_empty(): return snapshot.duplicate(true)
	var result: Dictionary = snapshot.duplicate(true)
	# Even diagnostic snow/rain must respect the absence of an atmosphere.
	if not bool(result.get("atmosphere_present", true)): return result
	result.merge(preset, true)
	if result.has("wind_velocity"):
		var velocity: Vector3 = Cube.vector(result.wind_velocity)
		velocity = velocity.normalized() * float(result.wind_mps) if velocity.length_squared() > 0.000001 else Vector3.ZERO
		result.wind_velocity = [velocity.x, velocity.y, velocity.z]
		result.wind_mps = velocity.length()
	result.rain_intensity = 0.0 if condition == "snow" else result.precipitation
	result.snow_intensity = result.precipitation if condition == "snow" else 0.0
	result.snow_fraction = 1.0 if condition == "snow" else 0.0
	result.wetness = 0.0 if condition == "snow" else result.precipitation
	result.preview = true
	return result

static func _unit(value: Variant, fallback: float) -> float:
	return clampf(float(value), 0.0, 1.0) if (value is int or value is float) and is_finite(float(value)) else fallback
