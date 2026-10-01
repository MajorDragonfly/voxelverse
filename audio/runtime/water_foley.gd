extends RefCounted
## Presentation-only cadence. No queries, nodes, world RNG, physiology or saves.
const MIN_BUBBLE_GAP := 2.8
const MAX_BUBBLE_GAP := 5.2
# The existing dive/surface assets last 0.75/0.82 s. Leave a mixer buffer
# between opposite cues; fast crossings still update state without layering.
const TRANSITION_GAP := 0.85
var _rng := RandomNumberGenerator.new()
var _initialized := false
var _submerged := false
var _cue_submerged := false
var _bubble_clock := 0.0
var _transition_clock := 0.0


func _init() -> void:
	_rng.seed = 15092026
	reset()


func reset() -> void:
	_initialized = false
	_bubble_clock = _rng.randf_range(MIN_BUBBLE_GAP, MAX_BUBBLE_GAP)
	_transition_clock = 0.0


func advance(delta: float, submerged: bool, distance: float, enabled: bool, transition_available: bool = true) -> Dictionary:
	if not enabled or not is_finite(delta) or delta <= 0.0 or delta > 0.2 or not is_finite(distance):
		if _initialized:
			reset() # Restore silently after spawning, stalls or inactive views.
		return {}
	_transition_clock = maxf(0.0, _transition_clock - delta)
	if not _initialized:
		_initialized = true
		_submerged = submerged
		_cue_submerged = submerged
		return {}
	if submerged != _submerged:
		_submerged = submerged
		_bubble_clock = _rng.randf_range(MIN_BUBBLE_GAP, MAX_BUBBLE_GAP)
	# Keep only the latest observed crossing until the previous cue finishes.
	# Returning to the presented side cancels it; there is no event queue.
	if _submerged != _cue_submerged:
		if _transition_clock > 0.0 or not transition_available:
			return {}
		_cue_submerged = _submerged
		_transition_clock = TRANSITION_GAP
		return {"event": &"water_dive" if submerged else &"water_surface", "gain": -9.0, "pitch": 1.0}
	if submerged and distance > 0.002:
		_bubble_clock -= delta
		if _bubble_clock <= 0.0 and _transition_clock <= 0.0:
			_bubble_clock = _rng.randf_range(MIN_BUBBLE_GAP, MAX_BUBBLE_GAP)
			return {"event": &"underwater_bubbles", "gain": -19.0, "pitch": _rng.randf_range(0.93, 1.07)}
	return {}
