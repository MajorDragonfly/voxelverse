extends RefCounted
## WEATHER-01. Pure presentation contract derived from the existing campaign clock.
## No wall clock, global RNG, simulation catch-up or gameplay damage.
const Climate = preload("res://world/weather/planet_climate.gd")
const StormPreview = preload("res://world/weather/storm_preview.gd")
const SCHEMA: int = 1
const TRANSITION_SECONDS: float = 35.0
const CONDITIONS: Dictionary = {
	"clear": {"cloud_cover": 0.16, "precipitation": 0.0, "wind_mps": 1.2, "visibility_m": 18000.0},
	"breeze": {"cloud_cover": 0.32, "precipitation": 0.0, "wind_mps": 4.0, "visibility_m": 16000.0},
	"overcast": {"cloud_cover": 0.86, "precipitation": 0.0, "wind_mps": 2.5, "visibility_m": 12000.0},
	"drizzle": {"cloud_cover": 0.88, "precipitation": 0.28, "wind_mps": 2.8, "visibility_m": 10000.0},
	"rain": {"cloud_cover": 0.96, "precipitation": 0.65, "wind_mps": 4.8, "visibility_m": 8000.0},
	"snow": {"cloud_cover": 0.88, "precipitation": 0.45, "wind_mps": 2.0, "visibility_m": 9000.0},
}
const CLIMATES: Dictionary = {
	"earth_temperate": {"implemented": true, "hazards": [], "conditions": ["clear", "breeze", "overcast", "drizzle", "rain", "snow"]},
	"arid_extreme": {"implemented": false, "hazards": ["sandstorm"], "conditions": []},
	"volcanic_extreme": {"implemented": false, "hazards": ["firestorm"], "conditions": []},
	"frozen_extreme": {"implemented": false, "hazards": ["blizzard"], "conditions": []},
}

static func climate_catalog() -> Dictionary:
	var result: Dictionary = CLIMATES.duplicate(true)
	for id in Climate.CATALOG:
		result[id] = {"implemented": true, "hazards": [], "revision": Climate.REVISION, "conditions": CONDITIONS.keys()}
	return result

static func supports_preview(condition: String) -> bool:
	return CONDITIONS.has(condition) or StormPreview.PROFILES.has(condition)

static func preview_storm(snapshot: Dictionary, kind: String) -> Dictionary:
	return StormPreview.apply(snapshot, kind)

static func sample(body_id: String, seed_value: int, elapsed_seconds: float,
		climate_id: String = "earth_temperate") -> Dictionary:
	# Reserved extreme profiles cannot silently become active without their gates.
	if body_id.is_empty() or seed_value < 1 or not is_finite(elapsed_seconds) \
			or seed_value > 2147483647 or not Climate.CATALOG.has(climate_id): return {}
	var clock: float = maxf(elapsed_seconds, 0.0)
	var duration: float = 210.0 + float(posmod(seed_value, 4)) * 30.0
	var slot: int = int(floor(clock / duration))
	var within: float = fposmod(clock, duration)
	var previous: String = _condition(seed_value, maxi(slot - 1, 0))
	var target: String = _condition(seed_value, slot)
	var blend: float = smoothstep(0.0, TRANSITION_SECONDS, within) if slot > 0 else 1.0
	var result: Dictionary = preset(target)
	for key: String in CONDITIONS[target]:
		result[key] = lerpf(float(CONDITIONS[previous][key]), float(CONDITIONS[target][key]), blend)
	# Moisture lingers through the dry front; it is derived, never a second save.
	result.wetness = lerpf(float(CONDITIONS[previous].precipitation), float(CONDITIONS[target].precipitation),
		smoothstep(0.0, 110.0, within)) if slot > 0 else 0.0
	result.merge({"body_id": body_id, "seed": seed_value, "elapsed_seconds": clock,
		"front_index": slot, "previous_condition": previous, "transition": blend,
		"seconds_to_next_front": duration - within,
		"wind_bearing": float(posmod(seed_value, 360)) * PI / 180.0,
		"preview": false}, true)
	_apply_climate(result, climate_id)
	return result

static func preset(condition: String, climate_id: String = "earth_temperate") -> Dictionary:
	if not CONDITIONS.has(condition) or not Climate.CATALOG.has(climate_id): return {}
	var result: Dictionary = CONDITIONS[condition].duplicate(true)
	result.merge({"schema": SCHEMA, "climate_id": "earth_temperate", "condition": condition,
		"wetness": float(result.precipitation), "hazard_kind": "none", "hazard_intensity": 0.0})
	_apply_climate(result, climate_id)
	return result

static func _apply_climate(result: Dictionary, id: String) -> void:
	var profile: Dictionary = Climate.CATALOG[id]
	result.climate_id = id
	result.climate_revision = Climate.REVISION
	result.cloud_cover *= float(profile.cloud_scale)
	result.precipitation *= float(profile.precipitation_scale)
	result.wetness *= float(profile.precipitation_scale)
	if profile.atmosphere == "none":
		result.wind_mps = 0.0
		result.condition = "clear"
		result.previous_condition = "clear"

static func _condition(seed_value: int, slot: int) -> String:
	# A peaceful opening followed by a visible first shower, independently of FPS.
	if slot == 0: return "clear"
	if slot == 1: return "overcast"
	if slot == 2: return "drizzle" if posmod(seed_value, 2) == 0 else "rain"
	var random := RandomNumberGenerator.new()
	random.seed = (seed_value * 48271 + slot * 69621) & 0x7fffffff
	var choices: Array[String] = ["clear", "clear", "breeze", "breeze", "overcast", "drizzle", "rain"]
	return choices[random.randi_range(0, choices.size() - 1)]
