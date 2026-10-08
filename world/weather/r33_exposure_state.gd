extends RefCounted
## A single bounded consequence receipt on the existing body save, not a clock
## or event scheduler. Absent on legacy saves until first live exposure.
const Storm = preload("res://world/weather/r33_sandstorm.gd")
const FIELD: String = "weather_exposure"
const SCHEMA: int = 1
const MAX_DAMAGE_RATIO: float = 0.15
const HEALTH_FLOOR_RATIO: float = 0.25
const RATE_RATIO: float = 0.0015

static func unsupported(body: Dictionary) -> bool:
	return body.has(FIELD) and (not body[FIELD] is Dictionary or body[FIELD].get("schema") != SCHEMA)

static func validate(body: Dictionary, campaign: Dictionary) -> String:
	if not body.has(FIELD): return ""
	if unsupported(body): return "Unsupported weather exposure; source remains protected."
	var value: Dictionary = body[FIELD]
	if value.size() != 6 or value.get("body_id") != body.get("id") \
		or value.get("actor_id") != campaign.get("player_object_id") \
		or not _number(value.get("cursor"), 0.0, float(campaign.get("elapsed_seconds", 0.0)) + 0.000001) \
		or not _number(value.get("spent_ratio"), 0.0, MAX_DAMAGE_RATIO): return "Invalid weather exposure receipt."
	if value.get("event_id") != Storm.event_id(str(body.id), int(body.seed), float(value.cursor)):
		return "Weather exposure receipt belongs to another event."
	return ""

static func attach(body: Dictionary, actor_id: String, clock: float) -> Dictionary:
	if unsupported(body): return {}
	var id: String = Storm.event_id(body.id, body.seed, clock)
	var value: Dictionary = body.get(FIELD, {})
	if value.is_empty():
		value = {"schema": SCHEMA, "body_id": body.id, "actor_id": actor_id,
			"cursor": clock, "event_id": id, "spent_ratio": 0.0}
		body[FIELD] = value
	if value.body_id != body.id or value.actor_id != actor_id: return {}
	# Arrival/restart owes no exposure for time outside this live scene.
	if value.event_id != id:
		value.event_id = id
		value.spent_ratio = 0.0
	value.cursor = clock
	return value

static func consume(value: Dictionary, body: Dictionary, clock: float, intensity: float,
		protected: bool, health_ratio: float) -> float:
	if value.is_empty() or not is_finite(clock): return 0.0
	var elapsed: float = clampf(clock - float(value.cursor), 0.0, 1.0)
	# Repeated calls at the same authoritative clock cannot duplicate damage.
	if clock <= float(value.cursor): return 0.0
	var id: String = Storm.event_id(body.id, body.seed, clock)
	if value.event_id != id:
		value.event_id = id
		value.spent_ratio = 0.0
		elapsed = 0.0 # never charge an old event to a new one
	value.cursor = clock
	if protected or intensity < 0.25: return 0.0
	var amount: float = minf(RATE_RATIO * elapsed * clampf(intensity, 0.0, 1.0),
		minf(MAX_DAMAGE_RATIO - float(value.spent_ratio), maxf(0.0, health_ratio - HEALTH_FLOOR_RATIO)))
	value.spent_ratio = minf(MAX_DAMAGE_RATIO, float(value.spent_ratio) + amount)
	return amount

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high
