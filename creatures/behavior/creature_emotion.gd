extends RefCounted
## Transient presentation state. Relationships, needs and rewards stay with their
## existing owners. One local clock; no random draws, wall time or save writes.
# head pitch/roll, body drop/pitch, tail pitch/amplitude/rate, eye openness.
const PROFILES: Dictionary = {
	"calm": [0.0, 0.0, 0.0, 0.0, 0.0, 0.10, 2.0, 1.0],
	"curious": [0.03, 0.15, 0.0, 0.0, -0.12, 0.15, 2.5, 1.08],
	"affectionate": [-0.06, 0.07, 0.015, 0.0, -0.25, 0.42, 7.0, 0.72],
	"playful": [0.04, 0.13, 0.025, 0.03, -0.32, 0.55, 9.0, 0.90],
	"afraid": [-0.13, 0.0, 0.075, -0.04, 0.72, 0.025, 11.0, 1.20],
	"angry": [0.10, 0.0, 0.02, 0.055, -0.38, 0.045, 3.0, 0.50],
	"hurt": [-0.15, -0.08, 0.065, -0.045, 0.45, 0.03, 10.0, 0.25],
	"content": [0.07, 0.03, 0.025, 0.0, -0.10, 0.18, 2.5, 0.65],
	"tired": [0.14, 0.0, 0.05, 0.025, 0.25, 0.04, 1.2, 0.42],
	"feeding": [0.15, 0.0, 0.035, 0.025, 0.10, 0.09, 2.5, 0.80],
}
var state: String = "calm"
var clock: float = 0.0
var expressiveness: float = 1.0
var phase: float = 0.0
var blink_period: float = 4.0
var _weights: Dictionary = {"calm": 1.0}
var _reaction: String = ""
var _remaining: float = 0.0
var _look: float = 0.0


func configure(seed_value: int) -> void:
	expressiveness = 0.82 + float(posmod(seed_value, 19)) / 50.0
	phase = float(posmod(seed_value, 101)) / 101.0 * TAU
	blink_period = 3.2 + float(posmod(seed_value, 13)) * 0.19
	reset()


func reset() -> void:
	state = "calm"
	clock = 0.0
	_weights = {"calm": 1.0}
	_reaction = ""
	_remaining = 0.0
	_look = 0.0


func react(event: String) -> void:
	if event == "hurt":
		_reaction = "hurt"
		_remaining = 0.65
	elif _reaction != "hurt" or _remaining <= 0.0:
		match event:
			"friend", "help":
				_reaction = "affectionate"
				_remaining = 2.6
			"greet":
				_reaction = "playful"
				_remaining = 2.2


func advance(delta: float, context: Dictionary) -> Dictionary:
	if not is_finite(delta) or delta <= 0.0 or not bool(context.get("active", true)):
		return pose()
	if bool(context.get("dead", false)):
		reset()
		return {}
	clock += delta
	_remaining = maxf(0.0, _remaining - delta)
	var intent: String = str(context.get("intent", "rest"))
	var danger: bool = bool(context.get("threat", false)) or intent in ["flee", "alert", "chase"]
	# Danger cancels positive gestures; they must not resume after a threat.
	if danger and _reaction != "hurt":
		_remaining = 0.0
	if _remaining > 0.0 and _reaction == "hurt": state = "hurt"
	elif intent == "flee": state = "afraid"
	elif intent in ["alert", "chase"]: state = "angry"
	elif danger: state = "afraid"
	elif _remaining > 0.0: state = _reaction
	elif intent in ["eat", "drink"]: state = "feeding"
	elif bool(context.get("attention", false)) or intent in ["social", "search", "forage", "seek_water", "herd"]: state = "curious"
	elif float(context.get("health", 1.0)) < 0.35: state = "tired"
	elif bool(context.get("friendly_near", false)): state = "affectionate"
	elif bool(context.get("sated", false)) and intent == "rest": state = "content"
	else: state = "calm"
	var blend: float = 1.0 - exp(-(14.0 if danger or state == "hurt" else 5.0) * delta)
	for id: String in PROFILES:
		_weights[id] = lerpf(float(_weights.get(id, 0.0)), 1.0 if id == state else 0.0, blend)
	var target_look: float = float(context.get("look_yaw", 0.0))
	if not is_finite(target_look): target_look = 0.0
	_look = lerpf(_look, clampf(target_look, -0.30, 0.30), 1.0 - exp(-5.0 * delta))
	return pose()


func pose() -> Dictionary:
	var tail_yaw: float = 0.0
	var values: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for id: String in _weights:
		var profile: Array = PROFILES[id]
		tail_yaw += float(_weights[id]) * float(profile[5]) * sin(clock * float(profile[6]) + phase)
		for index in range(values.size()): values[index] += float(profile[index]) * float(_weights[id])
	var blink_time: float = fmod(clock + phase, blink_period)
	var blink: float = pow(sin(PI * blink_time / 0.18), 2.0) if blink_time < 0.18 else 0.0
	return {"state": state, "head_pitch": values[0] * expressiveness,
		"head_roll": values[1] * sin(clock * 1.7 + phase) * expressiveness,
		"body_drop": values[2] * expressiveness, "body_pitch": values[3],
		"tail_pitch": values[4] * expressiveness,
		"tail_yaw": tail_yaw * expressiveness,
		"eye_open": maxf(0.06, values[7] * (1.0 - blink)), "look_yaw": _look}
